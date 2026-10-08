import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../widgets/camera/web_camera_dialog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/shift_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/notification_service.dart';
import '../../../services/parking_service.dart';
import '../../../services/shift_service.dart';
import '../../../services/monthly_pass_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/status_badge.dart';
import 'entry_success_screen.dart';

/// Validates and normalizes an Indian mobile number.
bool _isValidCustomerMobile(String? value) => AppFormatters.isValidCustomerMobile(value);

/// VehicleEntryScreen manages the complete real vehicle entry flow:
/// vehicle details, mandatory photo capture, optional advance payment,
/// capacity check, duplicate check, active shift check, and atomic Firestore + Storage creation.
class VehicleEntryScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final VoidCallback onViewActiveParking;

  const VehicleEntryScreen({
    super.key,
    required this.currentGuard,
    required this.onReturnDashboard,
    required this.onViewActiveParking,
  });

  @override
  State<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends State<VehicleEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _mobileController = TextEditingController();
  final _advanceController = TextEditingController();

  final _parkingService = ParkingService();
  final _shiftService = ShiftService();
  final _notificationService = NotificationService();
  final _imagePicker = ImagePicker();
  final _monthlyPassService = MonthlyPassService.instance;

  VehicleType _selectedType = VehicleType.fourWheeler;
  Uint8List? _photoBytes;
  bool _takeAdvance = false;
  String _advancePaymentMethod = 'cash'; // 'cash' or 'upi'

  bool _isLoading = false;
  int _availableCapacity = 100;
  bool _isCheckingCapacity = false;
  String? _errorMessage;

  Timer? _passCheckDebounce;
  VehiclePassCheckResult? _passCheckResult;
  bool _isCheckingPass = false;

  @override
  void initState() {
    super.initState();
    _checkCapacity();
    _vehicleNumberController.addListener(_onVehicleNumberChanged);
  }

  @override
  void dispose() {
    _passCheckDebounce?.cancel();
    _vehicleNumberController.removeListener(_onVehicleNumberChanged);
    _vehicleNumberController.dispose();
    _mobileController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  void _onVehicleNumberChanged() {
    _passCheckDebounce?.cancel();
    final text = _vehicleNumberController.text.trim();
    final normalized = AppFormatters.normalizeVehicleNumber(text);

    // Immediately clear pass result so stale pass state from previous vehicle is never shown
    if (_passCheckResult != null) {
      setState(() {
        _passCheckResult = null;
      });
    }

    if (normalized.length < 4) {
      return;
    }

    _passCheckDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isCheckingPass = true;
      });
      try {
        final result = await _monthlyPassService.checkVehiclePass(normalized);
        if (mounted) {
          final wasValid = _passCheckResult?.hasValidPass == true;
          setState(() {
            _passCheckResult = result;
            _isCheckingPass = false;
            if (result.hasValidPass) {
              _takeAdvance = false;
              _advanceController.clear();
              // Automatically select Vehicle Type from Monthly Pass
              _selectedType = result.validPass!.vehicleType;
            }
          });
          if (result.hasValidPass || wasValid) {
            _checkCapacity();
          }
        }
      } catch (e) {
        debugPrint('[VehicleEntry] Pass check error: $e');
        if (mounted) {
          setState(() {
            _isCheckingPass = false;
          });
        }
      }
    });
  }

  void _clearForm() {
    _passCheckDebounce?.cancel();
    _vehicleNumberController.clear();
    _mobileController.clear();
    _advanceController.clear();
    setState(() {
      _photoBytes = null;
      _takeAdvance = false;
      _passCheckResult = null;
      _isCheckingPass = false;
      _errorMessage = null;
    });
    _checkCapacity();
  }

  Future<void> _checkCapacity() async {
    setState(() {
      _isCheckingCapacity = true;
    });

    try {
      final available = await _parkingService.getAvailableCapacity(_selectedType);
      if (mounted) {
        setState(() {
          _availableCapacity = available;
        });
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingCapacity = false;
        });
      }
    }
  }

  Future<void> _startCameraCapture() async {
    if (kIsWeb) {
      final captured = await WebCameraDialog.show(context);
      if (captured != null && captured.isNotEmpty) {
        setState(() {
          _photoBytes = captured;
          _errorMessage = null;
        });
      }
    } else {
      await _pickPhoto(ImageSource.camera);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _photoBytes = bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final message = errStr.contains('permission') || errStr.contains('denied')
            ? AppStrings.cameraPermissionRequired
            : '${AppStrings.error}: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _submitEntry() async {
    // 1. Prevent double submission
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Mandatory Photo Validation
    if (_photoBytes == null || _photoBytes!.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.mandatoryPhotoRequired;
      });
      return;
    }

    // Capacity Check
    if (_availableCapacity <= 0) {
      final fullMsg = _selectedType == VehicleType.twoWheeler
          ? AppStrings.twoWheelerParkingFull
          : AppStrings.fourWheelerParkingFull;
      setState(() {
        _errorMessage = fullMsg;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final vehicleNumber = AppFormatters.normalizeVehicleNumber(_vehicleNumberController.text);
    final rawMobile = _mobileController.text.trim();
    if (!_isValidCustomerMobile(rawMobile)) {
      setState(() {
        _isLoading = false;
        _errorMessage = rawMobile.isEmpty
            ? AppStrings.mobileRequired
            : AppStrings.invalidMobile;
      });
      return;
    }
    final mobile = rawMobile;
    double advanceAmount = 0.0;
    if (_takeAdvance && _advanceController.text.trim().isNotEmpty) {
      advanceAmount = double.tryParse(_advanceController.text.trim()) ?? 0.0;
    }

    // Active Shift Check (CRITICAL: Guard must have an active assigned shift)
    final activeShift = await _shiftService.getGuardCurrentActiveShift(
      widget.currentGuard.uid,
      widget.currentGuard.email,
      widget.currentGuard.name,
    );
    if (activeShift == null) {
      await _notificationService.createNotification(
        recipientUserId: widget.currentGuard.uid,
        title: AppStrings.entryBlocked,
        message: AppStrings.noActiveShiftAssignedWarning,
        type: 'entry_blocked',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = AppStrings.noActiveShiftWarning;
      });
      return;
    }

    try {
      final shiftLabel = '${AppFormatters.formatTime(activeShift.startTime)} - ${AppFormatters.formatTime(activeShift.endTime)}';
      _passCheckDebounce?.cancel();
      VehiclePassCheckResult passCheck = _passCheckResult ?? const VehiclePassCheckResult();
      if (_passCheckResult == null && vehicleNumber.length >= 4) {
        try {
          passCheck = await _monthlyPassService.checkVehiclePass(vehicleNumber);
        } catch (_) {}
      }
      final hasValidPass = passCheck.hasValidPass;
      final isTypeMatch = hasValidPass && passCheck.validPass!.vehicleType == _selectedType;
      final isMonthlyPass = isTypeMatch;
      final monthlyPassId = isTypeMatch ? passCheck.validPass?.id : null;

      final record = await _parkingService.createVehicleEntry(
        vehicleNumber: vehicleNumber,
        vehicleType: _selectedType,
        vehiclePhotoBytes: _photoBytes!,
        customerMobile: mobile,
        guardUid: widget.currentGuard.uid,
        guardName: widget.currentGuard.name,
        guardShift: shiftLabel,
        advanceAmount: isMonthlyPass ? 0.0 : advanceAmount,
        advancePaymentMethod: _advancePaymentMethod,
        isMonthlyPass: isMonthlyPass,
        monthlyPassId: monthlyPassId,
      );

      _clearForm();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntrySuccessScreen(
              record: record,
              onReturnDashboard: () {
                Navigator.pop(context);
                widget.onReturnDashboard();
              },
              onViewActiveParking: () {
                Navigator.pop(context);
                widget.onViewActiveParking();
              },
              onNewEntry: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } on VehicleAlreadyParkedException {
      if (mounted) {
        setState(() {
          _errorMessage = AppStrings.vehicleAlreadyParked;
        });
      }
    } on CapacityFullException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.vehicleType == VehicleType.twoWheeler
              ? AppStrings.twoWheelerParkingFull
              : AppStrings.fourWheelerParkingFull;
        });
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? 'Operation timed out. Please verify network.';
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? e.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppStrings.error}: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCapacityFull = _availableCapacity <= 0;
    final typeLabel = _selectedType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Shift Status Check Banner
            StreamBuilder<ShiftModel?>(
              stream: _shiftService.watchGuardCurrentActiveShift(
                widget.currentGuard.uid,
                widget.currentGuard.email,
              ),
              builder: (context, snapshot) {
                // While connecting, do not show false error banner
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                if (snapshot.hasError) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_problem, color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.connectingShiftStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activeShift = snapshot.data;
                if (activeShift != null) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.noActiveShiftWarning,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dangerDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Capacity Status Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCapacityFull ? AppColors.dangerLight : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCapacityFull ? AppColors.danger : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCapacityFull ? Icons.block : Icons.info_outline,
                    color: isCapacityFull ? AppColors.danger : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isCapacityFull
                          ? (_selectedType == VehicleType.twoWheeler
                              ? AppStrings.twoWheelerParkingFull
                              : AppStrings.fourWheelerParkingFull)
                          : '$typeLabel ${AppStrings.available}: $_availableCapacity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCapacityFull ? AppColors.dangerDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isCheckingCapacity)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live System Entry Date/Time Indicator (Read-only for Guard)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${AppStrings.entryDateTime}: ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${AppStrings.autoCapturedOnConfirm} (${AppFormatters.formatDateTime(DateTime.now())})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Alert Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.dangerDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Section 1: Vehicle Category Selector
            Text(
              '1. ${AppStrings.selectVehicleCategory}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildVehicleTypeOption(
                    type: VehicleType.fourWheeler,
                    title: AppStrings.fourWheeler,
                    rateSubtitle: '₹${AppConstants.fourWheelerFirstHourRate.toInt()} ${AppStrings.firstHourRate}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildVehicleTypeOption(
                    type: VehicleType.twoWheeler,
                    title: AppStrings.twoWheeler,
                    rateSubtitle: '₹${AppConstants.twoWheelerFirstHourRate.toInt()} ${AppStrings.firstHourRate}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Vehicle Number & Mobile
            Text(
              '2. ${AppStrings.vehicleAndCustomerDetails}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _vehicleNumberController,
              labelText: '${AppStrings.vehicleNumber} *',
              hintText: 'e.g. MH 12 AB 1234',
              textCapitalization: TextCapitalization.characters,
              prefixIcon: Icons.pin_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                UpperCaseTextFormatter(),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.vehicleNumberRequired;
                }
                if (!AppFormatters.isValidVehicleNumber(v)) {
                  return AppStrings.invalidVehicleNumber;
                }
                return null;
              },
            ),
            if (_isCheckingPass) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(AppStrings.checkingMonthlyPass, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ] else if (_passCheckResult != null) ...[
              if (_passCheckResult!.hasValidPass) ...[
                Builder(
                  builder: (context) {
                    final validPass = _passCheckResult!.validPass!;
                    final isTypeMatch = validPass.vehicleType == _selectedType;
                    final passTypeLabel = validPass.vehicleType == VehicleType.twoWheeler
                        ? AppStrings.twoWheeler
                        : AppStrings.fourWheeler;
                    final selectedTypeLabel = _selectedType == VehicleType.twoWheeler
                        ? AppStrings.twoWheeler
                        : AppStrings.fourWheeler;

                    if (!isTypeMatch) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppColors.warningDark, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppStrings.monthlyPassVehicleTypeMismatch,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warningDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${AppStrings.passVehicleType}: $passTypeLabel',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${AppStrings.selectedVehicleType}: $selectedTypeLabel',
                                  style: const TextStyle(fontSize: 12, color: AppColors.dangerDark, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.monthlyPassMismatchWarning,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified, color: AppColors.successDark, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${AppStrings.monthlyPass} ✓',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.successDark),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  AppStrings.active.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.vehicleType}: $passTypeLabel',
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${AppStrings.validTill}: ${AppFormatters.formatDate(validPass.endDate)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.parkingFee}: ₹0',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.successDark),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.lock, size: 13, color: AppColors.successDark),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.lockedByMonthlyPass,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successDark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (_passCheckResult!.isExpired) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warningDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.monthlyPassExpiredNotice,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_passCheckResult!.isUpcoming) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.monthlyPassUpcomingNotice,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            AppTextField(
              controller: _mobileController,
              labelText: '${AppStrings.customerMobile} *',
              hintText: AppStrings.enter10DigitMobile,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.phone_outlined,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.mobileRequired;
                }
                if (!_isValidCustomerMobile(v)) {
                  return AppStrings.invalidMobile;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Section 3: Mandatory Vehicle Photo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '3. ${AppStrings.vehiclePhotoMandatory}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (_photoBytes != null)
                  StatusBadge(label: AppStrings.photoCaptured, type: BadgeType.active)
                else
                  StatusBadge(label: AppStrings.requiredField, type: BadgeType.danger),
              ],
            ),
            const SizedBox(height: 8),
            _buildPhotoPickerContainer(),
            const SizedBox(height: 20),

            // Section 4: Optional Advance Payment
            if (_passCheckResult?.hasValidPass == true && _passCheckResult!.validPass!.vehicleType == _selectedType) ...[
              Card(
                elevation: 0,
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.advancePayment,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.advanceNotRequiredForPass,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(label: '₹0', type: BadgeType.active),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: AppColors.cashColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.advancePayment,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Switch(
                            value: _takeAdvance,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _takeAdvance = val;
                                if (!val) {
                                  _advanceController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_takeAdvance) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: AppTextField(
                                controller: _advanceController,
                                labelText: '${AppStrings.advancePaid} (₹)',
                                hintText: '50',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.currency_rupee,
                                validator: (v) {
                                  if (_takeAdvance && (v == null || v.trim().isEmpty)) {
                                    return AppStrings.enterAmount;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildPaymentMethodChip(
                                      label: AppStrings.cash,
                                      value: 'cash',
                                      icon: Icons.money,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildPaymentMethodChip(
                                      label: AppStrings.upi,
                                      value: 'upi',
                                      icon: Icons.qr_code,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick Chips
                        Wrap(
                          spacing: 8,
                          children: [20, 50, 100].map((amt) {
                            return ActionChip(
                              label: Text(AppFormatters.formatCurrency(amt.toDouble())),
                              onPressed: () {
                                setState(() {
                                  _advanceController.text = amt.toString();
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Submit Button
            AppButton(
              label: isCapacityFull ? AppStrings.capacityFullBlocked : AppStrings.generateTicketAndConfirm,
              icon: Icons.check_circle,
              isLoading: _isLoading,
              onPressed: isCapacityFull ? null : _submitEntry,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeOption({
    required VehicleType type,
    required String title,
    required String rateSubtitle,
  }) {
    final isSelected = _selectedType == type;
    final isLocked = _passCheckResult?.hasValidPass == true;

    return Card(
      elevation: 0,
      color: isSelected
          ? AppColors.primarySurface
          : (isLocked ? AppColors.surfaceVariant.withValues(alpha: 0.4) : AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.vehicleTypeLockedByMonthlyPass),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : () {
                setState(() {
                  _selectedType = type;
                });
                _checkCapacity();
              },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.icon,
                    size: 28,
                    color: isSelected
                        ? AppColors.primary
                        : (isLocked ? AppColors.textMuted : AppColors.textSecondary),
                  ),
                  if (isSelected && isLocked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : (isLocked ? AppColors.textMuted : AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              if (isSelected && isLocked)
                Text(
                  AppStrings.lockedByMonthlyPass,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  rateSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPickerContainer() {
    if (_photoBytes != null) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _photoBytes!,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: ElevatedButton.icon(
                onPressed: _startCameraCapture,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(AppStrings.retakePhoto),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _startCameraCapture,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              AppStrings.tapToCapturePhoto,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.useCameraDevice,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _advancePaymentMethod == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) {
        setState(() {
          _advancePaymentMethod = value;
        });
      },
    );
  }
}
