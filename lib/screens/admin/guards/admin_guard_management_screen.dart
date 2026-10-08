import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/handover_model.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../models/responsibility_event_model.dart';
import '../../../models/shift_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/financial_responsibility_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/status_badge.dart';

/// Admin Guard Management Screen allowing Admin to view, search, activate/deactivate,
/// inspect guard-wise Cash & UPI financial responsibilities, control Shift Start/End,
/// and open detailed Guard Financial Reports with daily/monthly breakdowns.
class AdminGuardManagementScreen extends StatefulWidget {
  final VoidCallback? onNavigateToShift;

  const AdminGuardManagementScreen({super.key, this.onNavigateToShift});

  @override
  State<AdminGuardManagementScreen> createState() => _AdminGuardManagementScreenState();
}

/// Sort modes for Guard Management — always compare actual field values.
enum GuardSort {
  nameAZ,
  nameZA,
  newestCreated,
  oldestCreated,
  activeFirst,
  inactiveFirst,
  highestOutstanding,
  lowestOutstanding,
}

class _AdminGuardManagementScreenState extends State<AdminGuardManagementScreen> {
  final _adminService = AdminService();
  final _shiftService = ShiftService();
  final _paymentService = PaymentService();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _filterState = 'all'; // 'all', 'active', 'inactive'
  GuardSort _guardSort = GuardSort.nameAZ;

  // Collection Summary period state
  String _selectedPeriod = 'Today'; // 'Today', 'Last 7 Days', 'Last 15 Days', 'Last 30 Days', 'Custom Date Range'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime? _appliedCustomStartDate;
  DateTime? _appliedCustomEndDate;
  late Stream<PaymentReportData> _collectionSummaryStream;

  @override
  void initState() {
    super.initState();
    _initCustomDates();
    _updateCollectionStream();
    _shiftService.processAutomaticShiftTransitions();
  }

  void _initCustomDates() {
    final now = DateTime.now();
    _customStartDate = DateTime(now.year, now.month, now.day);
    _customEndDate = DateTime(now.year, now.month, now.day);
    _appliedCustomStartDate = _customStartDate;
    _appliedCustomEndDate = _customEndDate;
  }

  void _updateCollectionStream() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case 'Last 7 Days':
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Last 15 Days':
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Last 30 Days':
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Custom Date Range':
        final s = _appliedCustomStartDate ?? DateTime(now.year, now.month, now.day);
        final e = _appliedCustomEndDate ?? DateTime(now.year, now.month, now.day);
        startDate = DateTime(s.year, s.month, s.day, 0, 0, 0);
        endDate = DateTime(e.year, e.month, e.day, 23, 59, 59, 999);
        break;
      case 'Today':
      default:
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
    }

    _collectionSummaryStream = _paymentService.watchPaymentReport(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddGuardDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    String selectedShift = 'Shift 1';
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(AppStrings.addGuard, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextField(
                          controller: nameController,
                          labelText: AppStrings.guardName,
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: emailController,
                          labelText: AppStrings.guardEmail,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return AppStrings.emailRequired;
                            if (!v.contains('@') || !v.contains('.')) return AppStrings.invalidEmail;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: passwordController,
                          labelText: AppStrings.passwordLabel,
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return AppStrings.passwordRequired;
                            if (v.trim().length < 6) return AppStrings.passwordTooShort;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: mobileController,
                          labelText: AppStrings.guardMobile,
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedShift,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppStrings.currentShift,
                            prefixIcon: const Icon(Icons.schedule, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: [
                            DropdownMenuItem(value: 'Shift 1', child: Text(AppStrings.shift1Morning)),
                            DropdownMenuItem(value: 'Shift 2', child: Text(AppStrings.shift2Evening)),
                            DropdownMenuItem(value: 'Shift 3', child: Text(AppStrings.shift3Night)),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedShift = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSubmitting = true);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final successText = AppStrings.guardCreatedSuccess;
                          try {
                            await _adminService.provisionGuardAccount(
                              name: nameController.text,
                              email: emailController.text,
                              password: passwordController.text,
                              mobile: mobileController.text,
                              currentShift: selectedShift,
                            );

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text(successText)),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('${AppStrings.error}: $e')),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditGuardDialog(GuardModel guard) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: guard.name);
    final mobileController = TextEditingController(text: guard.mobile);
    String selectedShift = guard.currentShift.isNotEmpty ? guard.currentShift : 'Shift 1';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(AppStrings.edit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTextField(
                          controller: nameController,
                          labelText: AppStrings.guardName,
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: mobileController,
                          labelText: AppStrings.guardMobile,
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedShift,
                          decoration: InputDecoration(
                            labelText: AppStrings.currentShift,
                            prefixIcon: const Icon(Icons.schedule, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: [
                            DropdownMenuItem(value: 'Shift 1', child: Text(AppStrings.shift1Morning)),
                            DropdownMenuItem(value: 'Shift 2', child: Text(AppStrings.shift2Evening)),
                            DropdownMenuItem(value: 'Shift 3', child: Text(AppStrings.shift3Night)),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedShift = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSubmitting = true);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _adminService.updateGuard(
                              uid: guard.uid,
                              name: nameController.text,
                              mobile: mobileController.text,
                              currentShift: selectedShift,
                            );

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppStrings.profileUpdatedSuccess)),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('${AppStrings.error}: $e')),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleToggleStatus(GuardModel guard, {List<ShiftModel>? guardShifts}) async {
    final willDeactivate = guard.isActive;
    final hasActiveShift = guardShifts?.any((s) => s.isActive && !s.isCancelled) ?? false;
    bool isSubmitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  willDeactivate ? Icons.block : Icons.check_circle_outline,
                  color: willDeactivate ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  willDeactivate ? AppStrings.deactivateGuardTitle : AppStrings.activateGuardTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  _buildDetailRow(AppStrings.guard, guard.name),
                  const SizedBox(height: 6),
                  Text(
                    willDeactivate ? AppStrings.confirmDeactivateGuardMsg : AppStrings.confirmActivateGuardMsg,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (willDeactivate && hasActiveShift) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.deactivateActiveShiftWarning,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(AppStrings.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: willDeactivate ? AppColors.danger : AppColors.success,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDlgState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });
                        final adminUid = ShiftService.safeCurrentAuthUid ?? 'admin';
                        try {
                          debugPrint('[GUARD_STATUS_DEBUG] Updating guards/${guard.uid} isActive=${!willDeactivate}, adminUid=$adminUid');
                          await _adminService.toggleGuardStatus(
                            guard.uid,
                            !willDeactivate,
                            adminUid: adminUid,
                          );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(willDeactivate ? AppStrings.deactivateSuccess : AppStrings.activateSuccess),
                                backgroundColor: willDeactivate ? AppColors.danger : AppColors.success,
                              ),
                            );
                          }
                        } on FirebaseException catch (e) {
                          debugPrint('[GUARD_STATUS_DEBUG] FirebaseException: code=${e.code}, message=${e.message}, path=guards/${guard.uid}');
                          setDlgState(() {
                            isSubmitting = false;
                            dialogError = willDeactivate ? AppStrings.deactivateError : AppStrings.activateError;
                          });
                        } catch (e) {
                          debugPrint('[GUARD_STATUS_DEBUG] Exception: $e, path=guards/${guard.uid}');
                          setDlgState(() {
                            isSubmitting = false;
                            dialogError = willDeactivate ? AppStrings.deactivateError : AppStrings.activateError;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        willDeactivate ? AppStrings.deactivateGuard : AppStrings.activateGuard,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Start Shift Confirmation & Execution (ADMIN ONLY)
  /// If [isManualOverride] is true, prompts confirmation before manually starting a non-next shift.
  Future<void> _confirmAndStartShift(
    GuardModel guard,
    ShiftModel shift, {
    bool isManualOverride = false,
  }) async {
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isManualOverride ? Icons.warning_amber_rounded : Icons.play_circle_fill,
                  color: isManualOverride ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  isManualOverride ? 'Start Shift (Manual Override)' : AppStrings.startShiftConfirmTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isManualOverride) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Are you sure you want to manually start this shift?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                _buildDetailRow(AppStrings.guard, guard.name),
                _buildDetailRow(AppStrings.date, AppFormatters.formatDate(shift.shiftDate)),
                _buildDetailRow('Scheduled Start', AppFormatters.formatTime(shift.startTime)),
                _buildDetailRow('Scheduled End', AppFormatters.formatTime(shift.endTime)),
                _buildDetailRow('Duration', '${shift.durationHours} Hours'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(AppStrings.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isManualOverride ? AppColors.warning : AppColors.success,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDlgState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        try {
                          await _shiftService.startShiftByAdmin(
                            shiftId: shift.shiftId,
                            adminUid: ShiftService.safeCurrentAuthUid ?? 'admin',
                            adminName: 'Admin',
                          );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.shiftStarted),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[SHIFT_DEBUG] startShiftByAdmin failed: $e');
                          setDlgState(() {
                            isSubmitting = false;
                            final isAlreadyActive = e.toString().contains('already has an active shift');
                            errorMessage = isAlreadyActive ? AppStrings.alreadyActive : AppStrings.startShiftError;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppStrings.startShift, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// End Shift Confirmation & Execution (ADMIN ONLY)
  /// Displays outstanding financial responsibility and warning if not zero.
  /// Financial responsibility remains attached to the guard.
  Future<void> _confirmAndEndShift(
    GuardModel guard,
    ShiftModel shift,
    GuardFinancialResponsibility resp,
  ) async {
    final hasOutstanding = resp.totalOutstanding > 0;
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.stop_circle, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(AppStrings.endShiftConfirmTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  _buildDetailRow(AppStrings.guard, guard.name),
                  _buildDetailRow('Shift ID', shift.shiftId, isMonospace: true),
                  _buildDetailRow(AppStrings.date, AppFormatters.formatDate(shift.shiftDate)),
                  _buildDetailRow('Start Time', AppFormatters.formatTime(shift.startTime)),
                  _buildDetailRow('Scheduled End Time', AppFormatters.formatTime(shift.endTime)),
                  _buildDetailRow(AppStrings.currentTime, AppFormatters.formatTime(DateTime.now())),
                  const Divider(height: 20),
                  Text(
                    AppStrings.financialResponsibility.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(AppStrings.cashOutstanding, AppFormatters.formatCurrency(resp.outstandingCash)),
                  _buildDetailRow(AppStrings.upiOutstanding, AppFormatters.formatCurrency(resp.outstandingUpi)),
                  _buildDetailRow(AppStrings.totalOutstanding, AppFormatters.formatCurrency(resp.totalOutstanding)),
                  if (hasOutstanding) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  AppStrings.outstandingWarning,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppStrings.cashLabel}: ${AppFormatters.formatCurrency(resp.outstandingCash)} | ${AppStrings.upiLabel}: ${AppFormatters.formatCurrency(resp.outstandingUpi)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(AppStrings.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDlgState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        try {
                          await _shiftService.endShiftByAdmin(
                            shiftId: shift.shiftId,
                            adminUid: ShiftService.safeCurrentAuthUid ?? 'admin',
                            adminName: 'Admin',
                          );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.shiftEnded),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[SHIFT_DEBUG] endShiftByAdmin failed: $e');
                          setDlgState(() {
                            isSubmitting = false;
                            errorMessage = AppStrings.endShiftError;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppStrings.endShift, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens the comprehensive Guard Financial Report modal with 5 date tabs and Cash/UPI sections.
  void _openGuardFinancialReportModal(GuardModel guard, GuardFinancialResponsibility resp) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return _GuardFinancialReportDialog(guard: guard, responsibility: resp);
      },
    );
  }

  void _showGuardDetailsModal(
    GuardModel guard,
    GuardFinancialResponsibility resp,
    List<ShiftModel> guardShifts, {
    ShiftModel? nextEligibleShift,
  }) {
    ShiftModel? activeShift;
    for (final s in guardShifts) {
      if (s.isCancelled) continue;
      if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
      if (s.isActive) {
        activeShift = s;
        break;
      }
    }

    ShiftModel? eligibleAssignedShift;
    if (activeShift == null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowEnd = todayStart.add(const Duration(days: 2));
      for (final s in guardShifts) {
        final sStatus = s.status.toUpperCase().trim();
        if ((sStatus == 'ASSIGNED' || s.effectiveStatus == ShiftStatus.assigned) &&
            s.actualStartTime == null &&
            sStatus != 'COMPLETED' &&
            sStatus != 'CANCELLED' &&
            !s.isCancelled &&
            s.isUpcoming) {
          if (s.startTime.isBefore(tomorrowEnd)) {
            eligibleAssignedShift = s;
            break;
          }
        }
      }
    }

    final isNextEligibleGuard = nextEligibleShift != null &&
        eligibleAssignedShift != null &&
        nextEligibleShift.shiftId == eligibleAssignedShift.shiftId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          guard.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(
                        label: guard.isActive ? AppStrings.activeState.toUpperCase() : AppStrings.inactiveGuards.toUpperCase(),
                        type: guard.isActive ? BadgeType.active : BadgeType.danger,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Current Shift Details
                  Text(AppStrings.currentShift.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  if (activeShift != null) ...[
                    _buildDetailRow(AppStrings.shiftDate, AppFormatters.formatDate(activeShift.shiftDate)),
                    _buildDetailRow(AppStrings.startTime, AppFormatters.formatTime(activeShift.startTime)),
                    _buildDetailRow(AppStrings.endTime, AppFormatters.formatTime(activeShift.endTime)),
                    _buildDetailRow(AppStrings.duration, '${activeShift.durationHours} ${AppStrings.hours}'),
                  ] else if (eligibleAssignedShift != null) ...[
                    _buildDetailRow(AppStrings.shiftDate, AppFormatters.formatDate(eligibleAssignedShift.shiftDate)),
                    _buildDetailRow(AppStrings.startTime, AppFormatters.formatTime(eligibleAssignedShift.startTime)),
                    _buildDetailRow(AppStrings.endTime, AppFormatters.formatTime(eligibleAssignedShift.endTime)),
                    _buildDetailRow(AppStrings.duration, '${eligibleAssignedShift.durationHours} ${AppStrings.hours}'),
                  ] else ...[
                    _buildDetailRow(AppStrings.currentShift, AppStrings.noShift),
                  ],
                  const SizedBox(height: 24),

                  // Primary Action Buttons
                  if (!guard.isActive) ...[
                    // Inactive Guard: [ Activate ] [ View Report ]
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('modal_activate_guard_btn'),
                            label: AppStrings.activateGuard,
                            type: AppButtonType.primary,
                            icon: Icons.check_circle,
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleToggleStatus(guard, guardShifts: guardShifts);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('modal_view_report_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openGuardFinancialReportModal(guard, resp);
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                            label: Text(AppStrings.viewReport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Second row: [ Edit ]
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('modal_edit_guard_btn'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openEditGuardDialog(guard);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(AppStrings.edit),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ] else if (activeShift != null) ...[
                    // Active shift: [ End Shift ] [ View Report ]
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('modal_end_shift_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmAndEndShift(guard, activeShift!, resp);
                            },
                            icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.white),
                            label: Text(AppStrings.endShift, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('modal_view_report_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openGuardFinancialReportModal(guard, resp);
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                            label: Text(AppStrings.viewReport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Second row: [ Edit ] [ Deactivate Guard ]
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('modal_edit_guard_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openEditGuardDialog(guard);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(AppStrings.edit),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('modal_deactivate_guard_btn'),
                            label: AppStrings.deactivateGuard,
                            type: AppButtonType.danger,
                            icon: Icons.block,
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleToggleStatus(guard, guardShifts: guardShifts);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else if (eligibleAssignedShift != null) ...[
                    // Eligible Assigned shift: [ Start Shift ] [ View Report ]
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('modal_start_shift_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmAndStartShift(
                                guard,
                                eligibleAssignedShift!,
                                isManualOverride: !isNextEligibleGuard,
                              );
                            },
                            icon: Icon(
                              isNextEligibleGuard ? Icons.play_circle_outline : Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              isNextEligibleGuard ? AppStrings.startShift : 'Start Shift (Manual Override)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isNextEligibleGuard ? AppColors.success : AppColors.warning,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('modal_view_report_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openGuardFinancialReportModal(guard, resp);
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                            label: Text(AppStrings.viewReport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Second row: [ Edit ] [ Deactivate Guard ]
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('modal_edit_guard_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openEditGuardDialog(guard);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(AppStrings.edit),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('modal_deactivate_guard_btn'),
                            label: AppStrings.deactivateGuard,
                            type: AppButtonType.danger,
                            icon: Icons.block,
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleToggleStatus(guard, guardShifts: guardShifts);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Completed, cancelled, or no eligible shift: [ View Report ]
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey('modal_view_report_btn'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openGuardFinancialReportModal(guard, resp);
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                        label: Text(AppStrings.viewReport, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Second row: [ Edit ] [ Deactivate Guard ]
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('modal_edit_guard_btn'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openEditGuardDialog(guard);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(AppStrings.edit),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('modal_deactivate_guard_btn'),
                            label: AppStrings.deactivateGuard,
                            type: AppButtonType.danger,
                            icon: Icons.block,
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleToggleStatus(guard, guardShifts: guardShifts);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_guard_fab'),
        onPressed: _openAddGuardDialog,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: Text(
          AppStrings.addGuard,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.secondaryNavy,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Top Collection Summary Card with Period Dropdown
          _buildCollectionSummaryWidget(),

          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: _shiftService.watchAllShifts(),
              builder: (context, shiftsSnap) {
                final allShifts = shiftsSnap.data ?? [];

                return StreamBuilder<List<GuardFinancialRecord>>(
                  stream: FinancialResponsibilityService.instance.watchAllGuardsFinancialRecords(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                              const SizedBox(height: 12),
                              Text(AppStrings.unableToLoadGuards, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                child: Text(AppStrings.retry),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allRecords = snapshot.data ?? [];

                    // Pipeline: Search → Filter → Sort
                    var filteredRecords = allRecords.where((record) {
                      final g = record.guard;
                      if (g.role.trim().toLowerCase() != 'guard') return false;
                      final matchesQuery = _searchQuery.isEmpty ||
                          g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          g.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          g.mobile.contains(_searchQuery) ||
                          g.uid.toLowerCase().contains(_searchQuery.toLowerCase());

                      if (!matchesQuery) return false;

                      if (_filterState == 'active') return g.isActive;
                      if (_filterState == 'inactive') return !g.isActive;
                      return true;
                    }).toList();

                    // Sort using raw field values — never formatted strings
                    switch (_guardSort) {
                      case GuardSort.nameAZ:
                        filteredRecords.sort((a, b) =>
                            a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase()));
                        break;
                      case GuardSort.nameZA:
                        filteredRecords.sort((a, b) =>
                            b.guard.name.toLowerCase().compareTo(a.guard.name.toLowerCase()));
                        break;
                      case GuardSort.newestCreated:
                        filteredRecords.sort((a, b) {
                          final ca = a.guard.createdAt;
                          final cb = b.guard.createdAt;
                          if (ca == null && cb == null) return 0;
                          if (ca == null) return 1;
                          if (cb == null) return -1;
                          return cb.compareTo(ca);
                        });
                        break;
                      case GuardSort.oldestCreated:
                        filteredRecords.sort((a, b) {
                          final ca = a.guard.createdAt;
                          final cb = b.guard.createdAt;
                          if (ca == null && cb == null) return 0;
                          if (ca == null) return 1;
                          if (cb == null) return -1;
                          return ca.compareTo(cb);
                        });
                        break;
                      case GuardSort.activeFirst:
                        filteredRecords.sort((a, b) {
                          if (a.guard.isActive == b.guard.isActive) {
                            return a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase());
                          }
                          return a.guard.isActive ? -1 : 1;
                        });
                        break;
                      case GuardSort.inactiveFirst:
                        filteredRecords.sort((a, b) {
                          if (a.guard.isActive == b.guard.isActive) {
                            return a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase());
                          }
                          return a.guard.isActive ? 1 : -1;
                        });
                        break;
                      case GuardSort.highestOutstanding:
                        filteredRecords.sort((a, b) =>
                            b.responsibility.totalOutstanding.compareTo(a.responsibility.totalOutstanding));
                        break;
                      case GuardSort.lowestOutstanding:
                        filteredRecords.sort((a, b) =>
                            a.responsibility.totalOutstanding.compareTo(b.responsibility.totalOutstanding));
                        break;
                    }

                    return Column(
                      children: [
                        // Search & Filter Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _searchController,
                          labelText: AppStrings.search,
                          hintText: AppStrings.searchGuardsHint,
                          prefixIcon: Icons.search,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('all', '${AppStrings.all} (${allRecords.length})'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip('active', '${AppStrings.activeState} (${allRecords.where((r) => r.guard.isActive).length})'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip('inactive', '${AppStrings.inactiveGuards} (${allRecords.where((r) => !r.guard.isActive).length})'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<GuardSort>(
                              initialValue: _guardSort,
                              tooltip: AppStrings.sortBy,
                              onSelected: (s) => setState(() => _guardSort = s),
                              itemBuilder: (ctx) => [
                                _sortMenuItem(GuardSort.nameAZ, AppStrings.nameAZ),
                                _sortMenuItem(GuardSort.nameZA, AppStrings.nameZA),
                                _sortMenuItem(GuardSort.newestCreated, AppStrings.newestCreated),
                                _sortMenuItem(GuardSort.oldestCreated, AppStrings.oldestCreated),
                                _sortMenuItem(GuardSort.activeFirst, AppStrings.activeFirst),
                                _sortMenuItem(GuardSort.inactiveFirst, AppStrings.inactiveFirst),
                                _sortMenuItem(GuardSort.highestOutstanding, 'Highest Outstanding'),
                                _sortMenuItem(GuardSort.lowestOutstanding, 'Lowest Outstanding'),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(AppStrings.sortBy,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Guards List
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? SingleChildScrollView(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.people_outline, size: 40, color: AppColors.textMuted),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppStrings.noGuardsFound,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final nextEligibleShift = ShiftService.findNextEligibleShift(
                                allShifts,
                                filteredRecords.map((r) => r.guard).toList(),
                              );

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredRecords.length,
                                itemBuilder: (context, index) {
                                  final record = filteredRecords[index];
                                  final guardShifts = allShifts
                                      .where((s) => ShiftService.matchesGuard(s, record.guard.uid, record.guard.email, record.guard.name))
                                      .toList();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: _buildGuardCard(
                                      record,
                                      guardShifts,
                                      nextEligibleShift: nextEligibleShift,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  ],
),
);
  }

  /// Top Collection Summary card featuring period dropdown and 3 authoritative collection metrics.
  Widget _buildCollectionSummaryWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Collection Summary" and "Period: [ Today ▼ ]"
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                'Collection Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text(
                    'Period: ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('collection_period_dropdown'),
                        value: _selectedPeriod,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        items: [
                          DropdownMenuItem(value: 'Today', child: Text(AppStrings.today)),
                          DropdownMenuItem(value: 'Last 7 Days', child: Text(AppStrings.last7Days)),
                          DropdownMenuItem(value: 'Last 15 Days', child: Text(AppStrings.last15Days)),
                          DropdownMenuItem(value: 'Last 30 Days', child: Text(AppStrings.last30Days)),
                          DropdownMenuItem(value: 'Custom Date Range', child: Text(AppStrings.customDateRange)),
                        ],
                        onChanged: (newVal) {
                          if (newVal == null || newVal == _selectedPeriod) return;
                          setState(() {
                            _selectedPeriod = newVal;
                            if (newVal != 'Custom Date Range') {
                              _updateCollectionStream();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Custom Date Range picker if selected
          if (_selectedPeriod == 'Custom Date Range') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  InkWell(
                    key: const ValueKey('custom_from_date_picker'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _customStartDate = picked);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'From: ${AppFormatters.formatDate(_customStartDate ?? DateTime.now())}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('custom_to_date_picker'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _customEndDate = picked);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'To: ${AppFormatters.formatDate(_customEndDate ?? DateTime.now())}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const ValueKey('custom_period_apply_btn'),
                    onPressed: () {
                      if (_customStartDate != null && _customEndDate != null && _customStartDate!.isAfter(_customEndDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.fromDateMustBeBeforeToDate)),
                        );
                        return;
                      }
                      setState(() {
                        _appliedCustomStartDate = _customStartDate;
                        _appliedCustomEndDate = _customEndDate;
                        _updateCollectionStream();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(AppStrings.apply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 3 Collection Values: Cash | UPI | Total
          StreamBuilder<PaymentReportData>(
            stream: _collectionSummaryStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.dangerDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Failed to load collection summary: ${snapshot.error}',
                          style: const TextStyle(fontSize: 11, color: AppColors.dangerDark),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _updateCollectionStream()),
                        child: Text(AppStrings.retry, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }

              final report = snapshot.data ?? PaymentReportData.zero;
              final cash = report.collectedCash;
              final upi = report.collectedUpi;
              final total = cash + upi;

              return Row(
                children: [
                  Expanded(
                    child: _buildCollectionMetricTile(
                      label: AppStrings.cashCollection,
                      value: AppFormatters.formatCurrency(cash),
                      color: AppColors.cashColor,
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCollectionMetricTile(
                      label: AppStrings.upiCollection,
                      value: AppFormatters.formatCurrency(upi),
                      color: AppColors.upiColor,
                      icon: Icons.qr_code,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCollectionMetricTile(
                      label: AppStrings.totalCollection,
                      value: AppFormatters.formatCurrency(total),
                      color: AppColors.primary,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  Widget _buildFilterChip(String state, String label) {
    final isSelected = _filterState == state;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterState = state),
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.3),
    );
  }

  PopupMenuItem<GuardSort> _sortMenuItem(GuardSort value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_guardSort == value)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGuardCard(
    GuardFinancialRecord record,
    List<ShiftModel> guardShifts, {
    ShiftModel? nextEligibleShift,
  }) {
    final guard = record.guard;
    final resp = record.responsibility;

    // Detect currently active shift
    ShiftModel? activeShift;
    for (final s in guardShifts) {
      if (s.isCancelled) continue;
      if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
      if (s.isActive) {
        activeShift = s;
        break;
      }
    }

    // Detect assigned shift eligible to start (if not already active)
    ShiftModel? eligibleAssignedShift;
    if (activeShift == null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowEnd = todayStart.add(const Duration(days: 2));
      for (final s in guardShifts) {
        final sStatus = s.status.toUpperCase().trim();
        if ((sStatus == 'ASSIGNED' || s.effectiveStatus == ShiftStatus.assigned) &&
            s.actualStartTime == null &&
            sStatus != 'COMPLETED' &&
            sStatus != 'CANCELLED' &&
            !s.isCancelled &&
            s.isUpcoming) {
          if (s.startTime.isBefore(tomorrowEnd)) {
            eligibleAssignedShift = s;
            break;
          }
        }
      }
    }

    // Determine if this guard holds the single next eligible scheduled shift
    final isNextEligibleGuard = nextEligibleShift != null &&
        eligibleAssignedShift != null &&
        nextEligibleShift.shiftId == eligibleAssignedShift.shiftId;

    return AppCard(
      onTap: () => _showGuardDetailsModal(guard, resp, guardShifts, nextEligibleShift: nextEligibleShift),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Badge, Email, More Actions Menu
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: guard.isActive ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                child: Text(
                  guard.name.isNotEmpty ? guard.name[0].toUpperCase() : 'G',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: guard.isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            guard.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: guard.isActive ? AppStrings.activeState : AppStrings.inactiveGuards,
                          type: guard.isActive ? BadgeType.active : BadgeType.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guard.email.isNotEmpty ? guard.email : (guard.mobile.isNotEmpty ? guard.mobile : 'ID: ${guard.uid}'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (action) {
                  if (action == 'details') {
                    _showGuardDetailsModal(guard, resp, guardShifts, nextEligibleShift: nextEligibleShift);
                  } else if (action == 'report') {
                    _openGuardFinancialReportModal(guard, resp);
                  } else if (action == 'edit') {
                    _openEditGuardDialog(guard);
                  } else if (action == 'toggle') {
                    _handleToggleStatus(guard, guardShifts: guardShifts);
                  } else if (action == 'shift') {
                    widget.onNavigateToShift?.call();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'details', child: Text(AppStrings.guardDetails)),
                  PopupMenuItem(value: 'report', child: Text(AppStrings.viewReport)),
                  PopupMenuItem(value: 'edit', child: Text(AppStrings.edit)),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(guard.isActive ? AppStrings.deactivateGuard : AppStrings.activateGuard),
                  ),
                  PopupMenuItem(value: 'shift', child: Text(AppStrings.assignShift)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Current Shift Status Line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: activeShift != null ? AppColors.success.withValues(alpha: 0.1) : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  activeShift != null ? Icons.play_circle_filled : Icons.schedule,
                  size: 14,
                  color: activeShift != null ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activeShift != null
                        ? '${AppStrings.currentShift}: ${activeShift.durationHours}-Hour (${AppFormatters.formatTime(activeShift.startTime)} - ${AppFormatters.formatTime(activeShift.endTime)})'
                        : (eligibleAssignedShift != null
                            ? 'Scheduled: ${eligibleAssignedShift.durationHours}-Hour (${AppFormatters.formatTime(eligibleAssignedShift.startTime)} - ${AppFormatters.formatTime(eligibleAssignedShift.endTime)})'
                            : AppStrings.noShift),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activeShift != null ? AppColors.success : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeShift != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(AppStrings.active, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Direct Per-Guard Shift & Status Actions Row
          Row(
            children: [
              if (!guard.isActive) ...[
                // Inactive guard -> [ Activate ]
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleToggleStatus(guard, guardShifts: guardShifts),
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    label: Text(
                      AppStrings.activateGuard,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (activeShift != null) ...[
                // Guard has ACTIVE shift -> [ End Shift ]
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndEndShift(guard, activeShift!, resp),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Colors.white),
                    label: Text(
                      AppStrings.endShift,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (eligibleAssignedShift != null && isNextEligibleGuard) ...[
                // Guard has ASSIGNED shift AND is the NEXT ELIGIBLE GUARD -> [ Start Shift ]
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndStartShift(guard, eligibleAssignedShift!),
                    icon: const Icon(Icons.play_circle_outline, size: 16, color: Colors.white),
                    label: Text(
                      AppStrings.startShift,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // [ View Report ] is ALWAYS available
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGuardFinancialReportModal(guard, resp),
                  icon: const Icon(Icons.analytics_outlined, size: 16, color: Colors.white),
                  label: Text(
                    AppStrings.viewReport,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Clean tap affordance footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tap to view details & actions',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simplified Guard Financial Report Dialog providing:
/// 1. Header (Guard name, email/mobile, close button)
/// 2. Period Selector (Single dropdown: Today, Last 7 Days, Last 30 Days, This Year, Custom Date Range)
/// 3. Collection Summary (Total Collection, Cash Collection, UPI Collection)
/// 4. Current Outstanding (Cash Outstanding, UPI Outstanding, Total Outstanding)
/// 5. Activity (Search, Type filter, Sort, real-world events, click to inspect details)
/// 6. Responsibility History (Date-wise Keep With Me and Handover records with filter)
/// 7. Date-wise Summary (Compact date-wise collection with expand/collapse)
/// Note: Withdrawal is strictly handled in Admin -> Payment Management.
class _GuardFinancialReportDialog extends StatefulWidget {
  final GuardModel guard;
  final GuardFinancialResponsibility responsibility;

  const _GuardFinancialReportDialog({
    required this.guard,
    required this.responsibility,
  });

  @override
  State<_GuardFinancialReportDialog> createState() => _GuardFinancialReportDialogState();
}

enum _ReportPeriodTab { today, last7Days, last30Days, thisYear, custom }

enum _ActivityItemType { payment, keepWithMe, handover }

class _ReportActivityItem {
  final String id;
  final _ActivityItemType type;
  final String title;
  final DateTime dateTime;
  final double amount;
  final String method; // 'CASH' or 'UPI'
  final bool isRefund;
  final String summary;
  final String subtext;
  final dynamic rawObject;

  _ReportActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.dateTime,
    required this.amount,
    required this.method,
    this.isRefund = false,
    required this.summary,
    required this.subtext,
    required this.rawObject,
  });
}

class _RespHistoryItem {
  final String id;
  final bool isKeepWithMe;
  final DateTime dateTime;
  final double amount;
  final String method; // 'CASH' or 'UPI'
  final String title;
  final String details;
  final String? status;
  final String? shiftId;

  _RespHistoryItem({
    required this.id,
    required this.isKeepWithMe,
    required this.dateTime,
    required this.amount,
    required this.method,
    required this.title,
    required this.details,
    this.status,
    this.shiftId,
  });
}

class _DayCollectionSummary {
  final DateTime date;
  final double cash;
  final double upi;
  final int count;

  double get total => cash + upi;

  _DayCollectionSummary({
    required this.date,
    required this.cash,
    required this.upi,
    required this.count,
  });
}

class _GuardFinancialReportDialogState extends State<_GuardFinancialReportDialog> {
  _ReportPeriodTab _selectedPeriod = _ReportPeriodTab.today;
  DateTime? _customFromDate;
  DateTime? _customToDate;
  DateTime? _appliedFromDate;
  DateTime? _appliedToDate;
  String _customDateError = '';

  final _activitySearchController = TextEditingController();
  String _activitySearchQuery = '';
  String _activityTypeFilter = 'all'; // 'all', 'payments', 'keep_with_me', 'handover'
  String _activitySort = 'newest'; // 'newest', 'oldest'

  String _respHistoryTypeFilter = 'all'; // 'all', 'keep_with_me', 'handover'
  String _respHistoryMethodFilter = 'all'; // 'all', 'CASH', 'UPI'

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _transactionsStream;
  late final Stream<List<ResponsibilityEventModel>> _keepWithMeStream;
  late final Stream<List<HandoverModel>> _handoversStream;

  @override
  void initState() {
    super.initState();
    // Targeted query scoped by guardUid to eliminate unbounded queries and protect performance
    _transactionsStream = FirebaseFirestore.instance
        .collection('payment_transactions')
        .where('guardUid', isEqualTo: widget.guard.uid)
        .snapshots();
    _keepWithMeStream = FinancialResponsibilityService.instance.watchGuardKeepWithMeEvents(widget.guard.uid);
    _handoversStream = FinancialResponsibilityService.instance.watchGuardHandovers(widget.guard.uid);
  }

  @override
  void dispose() {
    _activitySearchController.dispose();
    super.dispose();
  }

  (DateTime start, DateTime end) get _currentDateBounds {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case _ReportPeriodTab.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case _ReportPeriodTab.last7Days:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case _ReportPeriodTab.last30Days:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case _ReportPeriodTab.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case _ReportPeriodTab.custom:
        final s = _appliedFromDate ?? _customFromDate ?? DateTime(now.year, now.month, now.day);
        final e = _appliedToDate ?? _customToDate ?? DateTime(now.year, now.month, now.day);
        final start = DateTime(s.year, s.month, s.day);
        final end = DateTime(e.year, e.month, e.day, 23, 59, 59, 999);
        return (start, end);
    }
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customFromDate ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2025, 1, 1),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _customFromDate = picked;
        _validateCustomDates();
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customToDate ?? now,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _customToDate = picked;
        _validateCustomDates();
      });
    }
  }

  void _validateCustomDates() {
    if (_customFromDate != null && _customToDate != null) {
      if (_customFromDate!.isAfter(_customToDate!)) {
        _customDateError = AppStrings.fromDateAfterToDateError;
      } else {
        _customDateError = '';
      }
    } else {
      _customDateError = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _transactionsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load Guard report. Please try again.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final List<PaymentTransactionModel> allGuardTxns = [];

            for (final doc in allDocs) {
              try {
                final txn = PaymentTransactionModel.fromFirestore(doc);
                if (txn.guardUid == widget.guard.uid ||
                    (txn.guardName.isNotEmpty && txn.guardName.toLowerCase() == widget.guard.name.toLowerCase())) {
                  allGuardTxns.add(txn);
                }
              } catch (_) {}
            }

            return StreamBuilder<List<ResponsibilityEventModel>>(
              stream: _keepWithMeStream,
              initialData: const [],
              builder: (context, kwmSnap) {
                final allKeepWithMe = kwmSnap.data ?? const [];

                return StreamBuilder<List<HandoverModel>>(
                  stream: _handoversStream,
                  initialData: const [],
                  builder: (context, hSnap) {
                    final allHandovers = hSnap.data ?? const [];

                    // Filter transactions & events by selected date range
                    final (startDate, endDate) = _currentDateBounds;
                    final periodTxns = allGuardTxns.where((t) {
                      return (t.createdAt.isAfter(startDate) || t.createdAt.isAtSameMomentAs(startDate)) &&
                          (t.createdAt.isBefore(endDate) || t.createdAt.isAtSameMomentAs(endDate));
                    }).toList();

                    final periodKeepWithMe = allKeepWithMe.where((e) {
                      return (e.createdAt.isAfter(startDate) || e.createdAt.isAtSameMomentAs(startDate)) &&
                          (e.createdAt.isBefore(endDate) || e.createdAt.isAtSameMomentAs(endDate));
                    }).toList();

                    final periodHandovers = allHandovers.where((h) {
                      return (h.createdAt.isAfter(startDate) || h.createdAt.isAtSameMomentAs(startDate)) &&
                          (h.createdAt.isBefore(endDate) || h.createdAt.isAtSameMomentAs(endDate));
                    }).toList();

                    // Cash calculations for selected period
                    final cashTxns = periodTxns.where((t) => t.isCash).toList();
                    double cashAdvances = 0.0;
                    double cashFinal = 0.0;
                    double cashRefunds = 0.0;
                    for (final t in cashTxns) {
                      if (t.isAdvance) cashAdvances += t.amount;
                      if (t.isFinal) cashFinal += t.amount;
                      if (t.isRefund) cashRefunds += t.amount;
                    }
                    final totalCash = (cashAdvances + cashFinal - cashRefunds) < 0 ? 0.0 : (cashAdvances + cashFinal - cashRefunds);

                    // UPI calculations for selected period
                    final upiTxns = periodTxns.where((t) => t.isUpi).toList();
                    double upiAdvances = 0.0;
                    double upiFinal = 0.0;
                    double upiRefunds = 0.0;
                    for (final t in upiTxns) {
                      if (t.isAdvance) upiAdvances += t.amount;
                      if (t.isFinal) upiFinal += t.amount;
                      if (t.isRefund) upiRefunds += t.amount;
                    }
                    final totalUpi = (upiAdvances + upiFinal - upiRefunds) < 0 ? 0.0 : (upiAdvances + upiFinal - upiRefunds);

                    // Total Collection = Cash Collection + UPI Collection
                    final totalCollection = totalCash + totalUpi;

                    // Outstanding responsibility (Authoritative existing values)
                    final cashOutstanding = widget.responsibility.outstandingCash;
                    final upiOutstanding = widget.responsibility.outstandingUpi;
                    final totalOutstanding = widget.responsibility.totalOutstanding;

                    // 5. Activity List Assembly (NO Withdrawals!)
                    final List<_ReportActivityItem> activities = [];

                    for (final t in periodTxns) {
                      final isCash = t.isCash;
                      final method = isCash ? 'CASH' : 'UPI';
                      final title = t.isRefund ? 'Payment Refund' : 'Parking Collection';
                      final summary = t.vehicleNumber.isNotEmpty
                          ? t.vehicleNumber
                          : (t.ticketId.isNotEmpty ? 'Ticket #${t.ticketId}' : 'Parking Fee');
                      final subtext = '${AppFormatters.formatDate(t.createdAt)} • ${AppFormatters.formatTime(t.createdAt)}';

                      activities.add(_ReportActivityItem(
                        id: t.id,
                        type: _ActivityItemType.payment,
                        title: title,
                        dateTime: t.createdAt,
                        amount: t.amount,
                        method: method,
                        isRefund: t.isRefund,
                        summary: summary,
                        subtext: subtext,
                        rawObject: t,
                      ));
                    }

                    for (final k in periodKeepWithMe) {
                      final method = k.isCash ? 'CASH' : 'UPI';
                      final subtext = '${AppFormatters.formatDate(k.createdAt)} • ${AppFormatters.formatTime(k.createdAt)}';
                      activities.add(_ReportActivityItem(
                        id: k.id,
                        type: _ActivityItemType.keepWithMe,
                        title: 'Keep With Me',
                        dateTime: k.createdAt,
                        amount: k.amount,
                        method: method,
                        isRefund: false,
                        summary: '$method Keep With Me',
                        subtext: subtext,
                        rawObject: k,
                      ));
                    }

                    for (final h in periodHandovers) {
                      final method = h.type.toUpperCase();
                      final isOut = h.fromGuardId == widget.guard.uid;
                      final title = isOut ? 'Handover Out' : 'Handover In';
                      final summary = isOut ? 'To: ${h.toGuardName}' : 'From: ${h.fromGuardName}';
                      final subtext = '${AppFormatters.formatDate(h.createdAt)} • ${AppFormatters.formatTime(h.createdAt)} • Status: ${h.status}';

                      activities.add(_ReportActivityItem(
                        id: h.handoverId,
                        type: _ActivityItemType.handover,
                        title: title,
                        dateTime: h.createdAt,
                        amount: h.amount,
                        method: method,
                        isRefund: false,
                        summary: summary,
                        subtext: subtext,
                        rawObject: h,
                      ));
                    }

                    // Activity filtering & sorting
                    var filteredActivities = activities.where((act) {
                      if (_activityTypeFilter == 'payments' && act.type != _ActivityItemType.payment) return false;
                      if (_activityTypeFilter == 'keep_with_me' && act.type != _ActivityItemType.keepWithMe) return false;
                      if (_activityTypeFilter == 'handover' && act.type != _ActivityItemType.handover) return false;

                      if (_activitySearchQuery.isNotEmpty) {
                        final q = _activitySearchQuery.toLowerCase();
                        final match = act.title.toLowerCase().contains(q) ||
                            act.summary.toLowerCase().contains(q) ||
                            act.subtext.toLowerCase().contains(q) ||
                            act.method.toLowerCase().contains(q) ||
                            act.amount.toString().contains(q);
                        if (!match) return false;
                      }
                      return true;
                    }).toList();

                    if (_activitySort == 'newest') {
                      filteredActivities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
                    } else {
                      filteredActivities.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                    }

                    // 6. Responsibility History Assembly (Keep With Me + Handover, DATE-WISE)
                    final List<_RespHistoryItem> respItems = [];

                    for (final k in periodKeepWithMe) {
                      respItems.add(_RespHistoryItem(
                        id: k.id,
                        isKeepWithMe: true,
                        dateTime: k.createdAt,
                        amount: k.amount,
                        method: k.isCash ? 'CASH' : 'UPI',
                        title: 'Keep With Me',
                        details: 'Shift: ${k.shiftId.isNotEmpty ? k.shiftId : "N/A"}${k.notes != null && k.notes!.isNotEmpty ? " • Notes: ${k.notes}" : ""}',
                        status: k.status.isNotEmpty ? k.status : 'Carried Forward',
                        shiftId: k.shiftId,
                      ));
                    }

                    for (final h in periodHandovers) {
                      final isOut = h.fromGuardId == widget.guard.uid;
                      respItems.add(_RespHistoryItem(
                        id: h.handoverId,
                        isKeepWithMe: false,
                        dateTime: h.createdAt,
                        amount: h.amount,
                        method: h.type.toUpperCase(),
                        title: isOut ? 'Handover Out' : 'Handover In',
                        details: isOut ? 'To: ${h.toGuardName}' : 'From: ${h.fromGuardName}',
                        status: h.status,
                        shiftId: h.shiftId,
                      ));
                    }

                    var filteredResp = respItems.where((r) {
                      if (_respHistoryTypeFilter == 'keep_with_me' && !r.isKeepWithMe) return false;
                      if (_respHistoryTypeFilter == 'handover' && r.isKeepWithMe) return false;
                      if (_respHistoryMethodFilter == 'CASH' && r.method != 'CASH') return false;
                      if (_respHistoryMethodFilter == 'UPI' && r.method != 'UPI') return false;
                      return true;
                    }).toList();

                    filteredResp.sort((a, b) => b.dateTime.compareTo(a.dateTime));

                    // Group responsibility items date-wise
                    final Map<String, List<_RespHistoryItem>> respByDate = {};
                    for (final item in filteredResp) {
                      final dateKey = AppFormatters.formatDate(item.dateTime);
                      respByDate.putIfAbsent(dateKey, () => []).add(item);
                    }

                    // 7. Date-wise Summary Assembly
                    final Map<String, List<PaymentTransactionModel>> txnsByDate = {};
                    for (final t in periodTxns) {
                      final dateKey = AppFormatters.formatDate(t.createdAt);
                      txnsByDate.putIfAbsent(dateKey, () => []).add(t);
                    }

                    final List<_DayCollectionSummary> daySummaries = [];
                    txnsByDate.forEach((dateStr, dTxns) {
                      double dCash = 0.0;
                      double dUpi = 0.0;
                      for (final t in dTxns) {
                        if (t.isCash) {
                          if (t.isRefund) {
                            dCash -= t.amount;
                          } else {
                            dCash += t.amount;
                          }
                        } else if (t.isUpi) {
                          if (t.isRefund) {
                            dUpi -= t.amount;
                          } else {
                            dUpi += t.amount;
                          }
                        }
                      }
                      daySummaries.add(_DayCollectionSummary(
                        date: dTxns.first.createdAt,
                        cash: dCash < 0 ? 0.0 : dCash,
                        upi: dUpi < 0 ? 0.0 : dUpi,
                        count: dTxns.length,
                      ));
                    });
                    daySummaries.sort((a, b) => b.date.compareTo(a.date));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: HEADER
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.assessment, color: AppColors.primary, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppStrings.guardFinancialReport} — ${widget.guard.name}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.guard.email}${widget.guard.mobile.isNotEmpty ? " • ${widget.guard.mobile}" : ""}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: AppStrings.close,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // SECTION 2: PERIOD SELECTOR
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                            border: const Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${AppStrings.period}: ',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<_ReportPeriodTab>(
                                        value: _selectedPeriod,
                                        isDense: true,
                                        items: [
                                          DropdownMenuItem(value: _ReportPeriodTab.today, child: Text(AppStrings.today)),
                                          DropdownMenuItem(value: _ReportPeriodTab.last7Days, child: Text(AppStrings.last7Days)),
                                          DropdownMenuItem(value: _ReportPeriodTab.last30Days, child: Text(AppStrings.last30Days)),
                                          DropdownMenuItem(value: _ReportPeriodTab.thisYear, child: Text(AppStrings.thisYear)),
                                          DropdownMenuItem(value: _ReportPeriodTab.custom, child: Text(AppStrings.customDateRange)),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPeriod = val;
                                              if (val == _ReportPeriodTab.custom) {
                                                _customFromDate ??= DateTime.now().subtract(const Duration(days: 7));
                                                _customToDate ??= DateTime.now();
                                                _appliedFromDate = _customFromDate;
                                                _appliedToDate = _customToDate;
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedPeriod == _ReportPeriodTab.custom) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickFromDate,
                                        icon: const Icon(Icons.calendar_today, size: 14),
                                        label: Text(
                                          _customFromDate != null
                                              ? '${AppStrings.from}: ${AppFormatters.formatDate(_customFromDate!)}'
                                              : AppStrings.from,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickToDate,
                                        icon: const Icon(Icons.event, size: 14),
                                        label: Text(
                                          _customToDate != null
                                              ? '${AppStrings.to}: ${AppFormatters.formatDate(_customToDate!)}'
                                              : AppStrings.to,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        _validateCustomDates();
                                        if (_customDateError.isEmpty) {
                                          setState(() {
                                            _appliedFromDate = _customFromDate;
                                            _appliedToDate = _customToDate;
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondaryNavy,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      child: Text(AppStrings.apply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (_customDateError.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _customDateError,
                                    style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),

                        // SCROLLABLE BODY CONTAINING SECTIONS 3 - 7
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // SECTION 3: COLLECTION SUMMARY
                                _buildCollectionSummaryCard(
                                  totalCollection: totalCollection,
                                  cashCollection: totalCash,
                                  upiCollection: totalUpi,
                                ),
                                const SizedBox(height: 16),

                                // SECTION 4: CURRENT OUTSTANDING
                                _buildCurrentOutstandingCard(
                                  cashOutstanding: cashOutstanding,
                                  upiOutstanding: upiOutstanding,
                                  totalOutstanding: totalOutstanding,
                                ),
                                const SizedBox(height: 20),

                                // SECTION 5: ACTIVITY
                                _buildActivitySection(filteredActivities),
                                const SizedBox(height: 20),

                                // SECTION 6: RESPONSIBILITY HISTORY (DATE-WISE)
                                _buildResponsibilityHistorySection(respByDate),
                                const SizedBox(height: 20),

                                // SECTION 7: DATE-WISE SUMMARY
                                _buildDateWiseSummarySection(daySummaries),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// SECTION 3: COLLECTION SUMMARY
  Widget _buildCollectionSummaryCard({
    required double totalCollection,
    required double cashCollection,
    required double upiCollection,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.collectionSummary,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildSummaryItem(AppStrings.totalCollection, AppFormatters.formatCurrency(totalCollection), AppColors.primary, isHighlighted: true),
                    const SizedBox(height: 8),
                    _buildSummaryItem(AppStrings.cashCollection, AppFormatters.formatCurrency(cashCollection), AppColors.cashColor),
                    const SizedBox(height: 8),
                    _buildSummaryItem(AppStrings.upiCollection, AppFormatters.formatCurrency(upiCollection), AppColors.upiColor),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.totalCollection,
                      value: AppFormatters.formatCurrency(totalCollection),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.cashCollection,
                      value: AppFormatters.formatCurrency(cashCollection),
                      color: AppColors.cashColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.upiCollection,
                      value: AppFormatters.formatCurrency(upiCollection),
                      color: AppColors.upiColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// SECTION 4: CURRENT OUTSTANDING
  Widget _buildCurrentOutstandingCard({
    required double cashOutstanding,
    required double upiOutstanding,
    required double totalOutstanding,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions, size: 18, color: AppColors.warningDark),
              const SizedBox(width: 8),
              Text(
                AppStrings.currentOutstanding,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.outstandingExplanation,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildSummaryItem(AppStrings.outstandingCash, AppFormatters.formatCurrency(cashOutstanding), AppColors.cashColor),
                    const SizedBox(height: 8),
                    _buildSummaryItem(AppStrings.outstandingUpi, AppFormatters.formatCurrency(upiOutstanding), AppColors.upiColor),
                    const SizedBox(height: 8),
                    _buildSummaryItem(
                      AppStrings.currentOutstanding,
                      AppFormatters.formatCurrency(totalOutstanding),
                      totalOutstanding > 0 ? AppColors.danger : AppColors.success,
                      isHighlighted: true,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.outstandingCash,
                      value: AppFormatters.formatCurrency(cashOutstanding),
                      color: AppColors.cashColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.outstandingUpi,
                      value: AppFormatters.formatCurrency(upiOutstanding),
                      color: AppColors.upiColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryBox(
                      label: AppStrings.currentOutstanding,
                      value: AppFormatters.formatCurrency(totalOutstanding),
                      color: totalOutstanding > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// SECTION 5: ACTIVITY (Search, Filters, Sort, List, Click -> Detail Modal)
  Widget _buildActivitySection(List<_ReportActivityItem> activities) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.activity,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${activities.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search + Filter + Sort Controls
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  children: [
                    AppTextField(
                      controller: _activitySearchController,
                      labelText: AppStrings.search,
                      hintText: AppStrings.searchActivityHint,
                      prefixIcon: Icons.search,
                      onChanged: (val) => setState(() => _activitySearchQuery = val.trim()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildActivityTypeDropdown()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildActivitySortDropdown()),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: AppTextField(
                      controller: _activitySearchController,
                      labelText: AppStrings.search,
                      hintText: AppStrings.searchActivityHint,
                      prefixIcon: Icons.search,
                      onChanged: (val) => setState(() => _activitySearchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildActivityTypeDropdown(),
                  const SizedBox(width: 8),
                  _buildActivitySortDropdown(),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Activity Items List
          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                AppStrings.noActivityFound,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = activities[idx];
                final isRefund = item.isRefund;
                final isCash = item.method == 'CASH';
                final methodColor = isCash ? AppColors.cashColor : AppColors.upiColor;

                return InkWell(
                  onTap: () => _showActivityDetailDialog(context, item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isRefund
                              ? AppColors.danger.withValues(alpha: 0.15)
                              : methodColor.withValues(alpha: 0.15),
                          child: Icon(
                            item.type == _ActivityItemType.payment
                                ? (isRefund ? Icons.remove : Icons.payment)
                                : (item.type == _ActivityItemType.keepWithMe ? Icons.bookmark : Icons.swap_horiz),
                            size: 16,
                            color: isRefund ? AppColors.danger : methodColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: methodColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCash ? AppStrings.cash : AppStrings.upi,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: methodColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.summary} • ${item.subtext}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isRefund ? "-" : ""}${AppFormatters.formatCurrency(item.amount)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isRefund ? AppColors.danger : methodColor,
                              ),
                            ),
                            Text('${AppStrings.details} ›', style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activityTypeFilter,
          isDense: true,
          items: [
            DropdownMenuItem(value: 'all', child: Text(AppStrings.all, style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'payments', child: Text(AppStrings.transactions, style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'keep_with_me', child: Text(AppStrings.keepWithMe, style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'handover', child: Text(AppStrings.handover, style: const TextStyle(fontSize: 12))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _activityTypeFilter = val);
          },
        ),
      ),
    );
  }

  Widget _buildActivitySortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activitySort,
          isDense: true,
          items: [
            DropdownMenuItem(value: 'newest', child: Text(AppStrings.newestFirst, style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'oldest', child: Text(AppStrings.oldestFirst, style: const TextStyle(fontSize: 12))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _activitySort = val);
          },
        ),
      ),
    );
  }

  /// SECTION 6: RESPONSIBILITY HISTORY (Keep With Me + Handover, DATE-WISE)
  Widget _buildResponsibilityHistorySection(Map<String, List<_RespHistoryItem>> respByDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.responsibilityHistory,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.textPrimary),
              ),
              const Spacer(),
              // Type Filter: All / Keep With Me / Handover
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _respHistoryTypeFilter,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(AppStrings.all, style: const TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'keep_with_me', child: Text(AppStrings.keepWithMe, style: const TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'handover', child: Text(AppStrings.handover, style: const TextStyle(fontSize: 11))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _respHistoryTypeFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Method Filter: All Methods / Cash / UPI
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _respHistoryMethodFilter,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(AppStrings.allMethods, style: const TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'CASH', child: Text(AppStrings.cash, style: const TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'UPI', child: Text(AppStrings.upi, style: const TextStyle(fontSize: 11))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _respHistoryMethodFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (respByDate.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text(
                'No responsibility history for this period.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: respByDate.keys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final dateKey = respByDate.keys.elementAt(idx);
                final items = respByDate[dateKey]!;

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              dateKey,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      // Items for this date
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: items.map((item) {
                            final isCash = item.method == 'CASH';
                            final color = isCash ? AppColors.cashColor : AppColors.upiColor;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(
                                      item.isKeepWithMe ? Icons.bookmark : Icons.swap_horiz,
                                      size: 14,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                isCash ? AppStrings.cash : AppStrings.upi,
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                                              ),
                                            ),
                                            if (item.status != null && item.status!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: (item.status == 'ACCEPTED' ? AppColors.success : Colors.amber).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  AppStrings.formatStatus(item.status!),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: item.status == 'ACCEPTED' ? AppColors.success : Colors.amber.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.details} • ${AppFormatters.formatTime(item.dateTime)}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.formatCurrency(item.amount),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// SECTION 7: DATE-WISE SUMMARY (Compact list, Expand/Collapse)
  Widget _buildDateWiseSummarySection(List<_DayCollectionSummary> daySummaries) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.dateWiseSummary,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (daySummaries.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                AppStrings.noTransactionsFound,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: daySummaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final day = daySummaries[idx];

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      leading: const Icon(Icons.event_note, size: 18, color: AppColors.primary),
                      title: Text(
                        AppFormatters.formatDate(day.date),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${AppStrings.collection}  ${AppFormatters.formatCurrency(day.total)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more, size: 18),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppStrings.cashCollection, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.formatCurrency(day.cash),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cashColor),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppStrings.upiCollection, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.formatCurrency(day.upi),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.upiColor),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppStrings.transactions, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${day.count}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Small Transaction / Activity Detail View Dialog (Section 15)
  void _showActivityDetailDialog(BuildContext context, _ReportActivityItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(
                item.type == _ActivityItemType.payment
                    ? Icons.receipt_long
                    : (item.type == _ActivityItemType.keepWithMe ? Icons.bookmark : Icons.swap_horiz),
                color: item.isRefund ? AppColors.danger : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  AppStrings.amount,
                  '${item.isRefund ? "-" : ""}${AppFormatters.formatCurrency(item.amount)}',
                  isBold: true,
                  valueColor: item.isRefund
                      ? AppColors.danger
                      : (item.method == 'CASH' ? AppColors.cashColor : AppColors.upiColor),
                ),
                _buildDetailRow(AppStrings.paymentMethod, item.method == 'CASH' ? AppStrings.cash : AppStrings.upi),
                _buildDetailRow(AppStrings.date, AppFormatters.formatDate(item.dateTime)),
                _buildDetailRow(AppStrings.time, AppFormatters.formatTime(item.dateTime)),
                if (item.type == _ActivityItemType.payment && item.rawObject is PaymentTransactionModel) ...[
                  _buildDetailRow(
                    AppStrings.vehicleNumber,
                    (item.rawObject as PaymentTransactionModel).vehicleNumber.isNotEmpty
                        ? (item.rawObject as PaymentTransactionModel).vehicleNumber
                        : '—',
                  ),
                  _buildDetailRow(
                    AppStrings.ticketNumber,
                    (item.rawObject as PaymentTransactionModel).ticketId.isNotEmpty
                        ? (item.rawObject as PaymentTransactionModel).ticketId
                        : '—',
                  ),
                  _buildDetailRow(AppStrings.transactionType, (item.rawObject as PaymentTransactionModel).paymentType),
                  _buildDetailRow(
                    AppStrings.guardLabel,
                    (item.rawObject as PaymentTransactionModel).guardName.isNotEmpty
                        ? (item.rawObject as PaymentTransactionModel).guardName
                        : widget.guard.name,
                  ),
                  _buildDetailRow(
                    AppStrings.shift,
                    (item.rawObject as PaymentTransactionModel).shift.isNotEmpty
                        ? (item.rawObject as PaymentTransactionModel).shift
                        : '—',
                  ),
                ] else if (item.type == _ActivityItemType.keepWithMe && item.rawObject is ResponsibilityEventModel) ...[
                  _buildDetailRow(AppStrings.guardLabel, widget.guard.name),
                  _buildDetailRow(
                    AppStrings.shift,
                    (item.rawObject as ResponsibilityEventModel).shiftId.isNotEmpty
                        ? (item.rawObject as ResponsibilityEventModel).shiftId
                        : '—',
                  ),
                  if ((item.rawObject as ResponsibilityEventModel).notes != null &&
                      (item.rawObject as ResponsibilityEventModel).notes!.isNotEmpty)
                    _buildDetailRow(AppStrings.notes, (item.rawObject as ResponsibilityEventModel).notes!),
                ] else if (item.type == _ActivityItemType.handover && item.rawObject is HandoverModel) ...[
                  _buildDetailRow(AppStrings.fromGuard, (item.rawObject as HandoverModel).fromGuardName),
                  _buildDetailRow(AppStrings.toGuard, (item.rawObject as HandoverModel).toGuardName),
                  _buildDetailRow(AppStrings.status, AppStrings.formatStatus((item.rawObject as HandoverModel).status)),
                  _buildDetailRow(
                    AppStrings.shift,
                    (item.rawObject as HandoverModel).shiftId.isNotEmpty
                        ? (item.rawObject as HandoverModel).shiftId
                        : '—',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isHighlighted ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isHighlighted ? 0.3 : 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500, color: color)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

