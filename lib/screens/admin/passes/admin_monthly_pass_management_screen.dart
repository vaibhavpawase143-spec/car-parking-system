import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/monthly_pass_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/monthly_pass_service.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/status_badge.dart';

/// Admin Monthly Pass Management Screen:
/// - Create Monthly Pass (strictly ₹600 fixed, full advance payment, Cash/UPI)
/// - Search by Vehicle Number / Pass Number / Customer Mobile
/// - Filter by Status: All / Active / Upcoming / Expired
/// - Filter by Vehicle Type: All / Two-Wheeler / Four-Wheeler
/// - Renew Pass (preserves historical passes)
/// - Receipt printing & WhatsApp text confirmation
class AdminMonthlyPassManagementScreen extends StatefulWidget {
  final GuardModel? currentAdmin;
  final MonthlyPassService? monthlyPassService;

  const AdminMonthlyPassManagementScreen({
    super.key,
    this.currentAdmin,
    this.monthlyPassService,
  });

  @override
  State<AdminMonthlyPassManagementScreen> createState() => _AdminMonthlyPassManagementScreenState();
}

class _AdminMonthlyPassManagementScreenState extends State<AdminMonthlyPassManagementScreen> {
  late final MonthlyPassService _monthlyPassService;
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, UPCOMING, EXPIRED
  String _vehicleTypeFilter = 'ALL'; // ALL, TWO_WHEELER, FOUR_WHEELER
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _monthlyPassService = widget.monthlyPassService ?? MonthlyPassService.instance;
  }

  void _retry() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreatePassDialog({MonthlyPassModel? renewingPass}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateMonthlyPassDialog(
        currentAdmin: widget.currentAdmin,
        renewingPass: renewingPass,
      ),
    );
  }

  void _openPassHistoryDialog(MonthlyPassModel pass) {
    showDialog(
      context: context,
      builder: (ctx) => _MonthlyPassParkingHistoryDialog(
        pass: pass,
        monthlyPassService: _monthlyPassService,
      ),
    );
  }

  Future<void> _printPassReceipt(MonthlyPassModel pass) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.printing),
          duration: const Duration(seconds: 1),
        ),
      );

      final success = await ReceiptPrintService.printMonthlyPassReceipt(pass);
      if (!mounted) return;

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppStrings.printSuccessNotice),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final errorMsg = ReceiptPlatformPrinter.lastErrorMessage ?? AppStrings.printFailedNotice;
        messenger.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MonthlyPass] Print error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.error}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _sharePassWhatsApp(MonthlyPassModel pass) {
    try {
      WhatsAppService.shareMonthlyPassConfirmation(pass);
    } catch (e) {
      debugPrint('[MonthlyPass] WhatsApp error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.error}: $e')),
      );
    }
  }

  List<MonthlyPassModel> _filterPasses(List<MonthlyPassModel> allPasses) {
    final query = _searchQuery.trim().toLowerCase();
    final normalizedQuery = AppFormatters.normalizeVehicleNumber(_searchQuery);

    return allPasses.where((pass) {
      // 1. Status Filter
      if (_statusFilter != 'ALL') {
        if (pass.dynamicStatus != _statusFilter) {
          return false;
        }
      }

      // 2. Vehicle Type Filter
      if (_vehicleTypeFilter != 'ALL') {
        if (_vehicleTypeFilter == 'TWO_WHEELER' && pass.vehicleType != VehicleType.twoWheeler) {
          return false;
        }
        if (_vehicleTypeFilter == 'FOUR_WHEELER' && pass.vehicleType != VehicleType.fourWheeler) {
          return false;
        }
      }

      // 3. Search Query
      if (query.isNotEmpty) {
        final matchesVehicle = pass.vehicleNumber.toLowerCase().contains(query) ||
            pass.normalizedVehicleNumber.contains(normalizedQuery);
        final matchesPass = pass.passNumber.toLowerCase().contains(query);
        final matchesMobile = pass.customerMobile.contains(query);
        final matchesCustomer = pass.customerName.toLowerCase().contains(query);

        if (!matchesVehicle && !matchesPass && !matchesMobile && !matchesCustomer) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: StreamBuilder<List<MonthlyPassModel>>(
            key: ValueKey(_refreshKey),
            stream: _monthlyPassService.watchAllPasses(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('[MonthlyPass] Stream error: ${snapshot.error}');
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBar(),
                      const SizedBox(height: 40),
                      _buildErrorState(snapshot.error),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allPasses = snapshot.data ?? [];
              final filtered = _filterPasses(allPasses);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Action Bar
                    _buildHeaderBar(),
                    const SizedBox(height: 20),

                    // Search & Filters Card
                    _buildFilterControls(),
                    const SizedBox(height: 20),

                    // Pass List
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final pass = filtered[index];
                          return _buildPassCard(pass);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              AppStrings.unableToLoadMonthlyPasses,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              key: const ValueKey('btn_retry_monthly_passes'),
              label: AppStrings.retry,
              icon: Icons.refresh,
              type: AppButtonType.primary,
              isFullWidth: false,
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.monthlyPassManagement,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.appName} • ${AppStrings.companyBrand}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final createButton = AppButton(
          key: const ValueKey('btn_create_monthly_pass'),
          label: AppStrings.createMonthlyPass,
          icon: Icons.add_circle_outline,
          type: AppButtonType.primary,
          isFullWidth: isCompact,
          onPressed: () => _openCreatePassDialog(),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 14),
              createButton,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 16),
            createButton,
          ],
        );
      },
    );
  }

  Widget _buildFilterControls() {
    return AppCard(
      child: Column(
        children: [
          // Search Field
          AppTextField(
            controller: _searchController,
            labelText: AppStrings.search,
            hintText: AppStrings.searchPassHint,
            prefixIcon: Icons.search,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 14),

          // Filters Row
          Row(
            children: [
              // Status Filter Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppStrings.status,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'ALL', child: Text(AppStrings.all, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'ACTIVE', child: Text(AppStrings.activePasses, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'UPCOMING', child: Text(AppStrings.upcomingPasses, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'EXPIRED', child: Text(AppStrings.expiredPasses, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _statusFilter = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),

              // Vehicle Type Filter Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _vehicleTypeFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppStrings.vehicleType,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'ALL', child: Text(AppStrings.all, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'TWO_WHEELER', child: Text(AppStrings.twoWheeler, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'FOUR_WHEELER', child: Text(AppStrings.fourWheeler, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _vehicleTypeFilter = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(Icons.badge_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              AppStrings.noPassesFound,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassCard(MonthlyPassModel pass) {
    final status = pass.dynamicStatus;
    BadgeType badgeType;
    if (status == 'ACTIVE') {
      badgeType = BadgeType.active;
    } else if (status == 'UPCOMING') {
      badgeType = BadgeType.info;
    } else {
      badgeType = BadgeType.danger;
    }

    final typeLabel = pass.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pass Header: Pass Number & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pass.passNumber,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${AppStrings.amount}: ₹${pass.amount.toInt()} • ${pass.paymentStatus} (${pass.paymentMethod.toUpperCase()})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pass.isExpiringSoon) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Text(
                        AppStrings.expiringSoon.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warningDark),
                      ),
                    ),
                  ],
                  StatusBadge(label: status, type: badgeType),
                ],
              ),
            ],
          ),
          const Divider(height: 20),

          // Details Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 550;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 4 : 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(AppStrings.vehicleNumber, pass.vehicleNumber, isBold: true),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.vehicleType, typeLabel),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.customerName, pass.customerName),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.mobile, pass.customerMobile),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: isWide ? 4 : 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(
                          AppStrings.validity,
                          '${AppFormatters.formatDate(pass.startDate)} → ${AppFormatters.formatDate(pass.endDate)}',
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.passAmount, '₹${pass.amount.toInt()} (FIXED)'),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.payment, '${AppStrings.paid} (${pass.paymentMethod.toUpperCase()})'),
                        const SizedBox(height: 6),
                        _buildField(AppStrings.outstanding, '₹0'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Actions Row
          LayoutBuilder(
            builder: (context, actionConstraints) {
              final isNarrow = actionConstraints.maxWidth < 500;

              final historyBtn = OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 16, color: AppColors.primaryNavy),
                label: Text(
                  AppStrings.viewParkingHistory,
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryNavy, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side: BorderSide(color: AppColors.primaryNavy.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () => _openPassHistoryDialog(pass),
              );

              final printBtn = OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 16, color: AppColors.secondaryNavy),
                label: Text(
                  AppStrings.print,
                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryNavy, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryNavy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () => _printPassReceipt(pass),
              );

              final hasMobile = pass.customerMobile.trim().isNotEmpty;
              final whatsAppBtn = hasMobile
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.chat, size: 16, color: AppColors.success),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () => _sharePassWhatsApp(pass),
                    )
                  : null;

              final renewBtn = ElevatedButton.icon(
                icon: const Icon(Icons.autorenew, size: 16, color: Colors.white),
                label: Text(
                  AppStrings.renewPass,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openCreatePassDialog(renewingPass: pass),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: historyBtn),
                        const SizedBox(width: 8),
                        Expanded(child: printBtn),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (whatsAppBtn != null) ...[
                          Expanded(child: whatsAppBtn),
                          const SizedBox(width: 8),
                          Expanded(child: renewBtn),
                        ] else ...[
                          Expanded(child: renewBtn),
                        ],
                      ],
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  historyBtn,
                  printBtn,
                  ?whatsAppBtn,
                  renewBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog for creating or renewing a Monthly Pass.
/// Amount is STRICTLY READ-ONLY ₹600.
/// Payment must be FULL ₹600 IN ADVANCE (Cash or UPI).
class _CreateMonthlyPassDialog extends StatefulWidget {
  final GuardModel? currentAdmin;
  final MonthlyPassModel? renewingPass;

  const _CreateMonthlyPassDialog({
    this.currentAdmin,
    this.renewingPass,
  });

  @override
  State<_CreateMonthlyPassDialog> createState() => _CreateMonthlyPassDialogState();
}

class _CreateMonthlyPassDialogState extends State<_CreateMonthlyPassDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vehicleController;
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;

  late VehicleType _vehicleType;
  late DateTime _startDate;
  late DateTime _endDate;
  String _paymentMethod = 'cash'; // 'cash' or 'upi'
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final renewing = widget.renewingPass;
    if (renewing != null) {
      _vehicleController = TextEditingController(text: renewing.vehicleNumber);
      _nameController = TextEditingController(text: renewing.customerName);
      _mobileController = TextEditingController(text: renewing.customerMobile);
      _vehicleType = renewing.vehicleType;
      // Start date starts after previous pass ends, or today if already expired
      final now = DateTime.now();
      final dayAfterPrevious = renewing.endDate.add(const Duration(days: 1));
      _startDate = dayAfterPrevious.isAfter(now) ? dayAfterPrevious : now;
    } else {
      _vehicleController = TextEditingController();
      _nameController = TextEditingController();
      _mobileController = TextEditingController();
      _vehicleType = VehicleType.twoWheeler;
      _startDate = DateTime.now();
    }
    _endDate = _calculateOneMonthEndDate(_startDate);
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  /// Calculates the end date for a 1-month pass
  /// (e.g. 01 Oct -> 31 Oct; 15 Oct -> 14 Nov)
  DateTime _calculateOneMonthEndDate(DateTime start) {
    final nextMonth = DateTime(start.year, start.month + 1, start.day);
    return nextMonth.subtract(const Duration(days: 1));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = _calculateOneMonthEndDate(picked);
      });
    }
  }

  Future<void> _submitPass() async {
    if (_isSaving) return; // Prevent double submission
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final admin = widget.currentAdmin;
      final pass = await MonthlyPassService.instance.createMonthlyPass(
        vehicleNumber: _vehicleController.text,
        vehicleType: _vehicleType,
        customerName: _nameController.text,
        customerMobile: _mobileController.text,
        startDate: _startDate,
        endDate: _endDate,
        paymentMethod: _paymentMethod,
        adminUid: admin?.uid ?? 'admin',
        adminName: admin?.name ?? 'Admin',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.monthlyPass} (${pass.passNumber}) ${AppStrings.success}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on MonthlyPassOverlapException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppStrings.monthlyPassPaymentFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        final isRenewing = widget.renewingPass != null;

        return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isRenewing ? AppStrings.renewPass : AppStrings.createMonthlyPass,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dangerDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Vehicle Number
                AppTextField(
                  controller: _vehicleController,
                  labelText: '${AppStrings.vehicleNumber} *',
                  hintText: 'e.g. MH 15 AB 1234',
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
                const SizedBox(height: 14),

                // 2. Vehicle Type
                Text(
                  AppStrings.vehicleType,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(AppStrings.twoWheeler),
                        selected: _vehicleType == VehicleType.twoWheeler,
                        onSelected: (val) {
                          if (val) setState(() => _vehicleType = VehicleType.twoWheeler);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(AppStrings.fourWheeler),
                        selected: _vehicleType == VehicleType.fourWheeler,
                        onSelected: (val) {
                          if (val) setState(() => _vehicleType = VehicleType.fourWheeler);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Customer Name & Mobile
                AppTextField(
                  controller: _nameController,
                  labelText: '${AppStrings.customerName} *',
                  hintText: 'e.g. Ramesh Patil',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppStrings.customerNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                    if (!AppFormatters.isValidCustomerMobile(v)) {
                      return AppStrings.invalidMobile;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 4. Date Range
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppStrings.startDate, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                AppFormatters.formatDate(_startDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month, size: 14),
                            label: const Text('Change'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                            onPressed: _pickStartDate,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppStrings.endDate, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            AppFormatters.formatDate(_endDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Monthly Pass Amount (STRICTLY READ-ONLY ₹600 FIXED)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.passAmount,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '₹600 FIXED',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppStrings.fullPaymentInAdvance,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Payment Method Selector (Cash or UPI, no split)
                Text(
                  AppStrings.paymentMethod,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.money, size: 16),
                        label: Text(AppStrings.cash),
                        selected: _paymentMethod == 'cash',
                        onSelected: (val) {
                          if (val) setState(() => _paymentMethod = 'cash');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.qr_code, size: 16),
                        label: Text(AppStrings.upi),
                        selected: _paymentMethod == 'upi',
                        onSelected: (val) {
                          if (val) setState(() => _paymentMethod = 'upi');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 7. Actions: Cancel / Pay ₹600 & Create Pass
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        key: const ValueKey('btn_pay_600_and_create_pass'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSaving ? null : _submitPass,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                AppStrings.pay600AndCreatePass,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}

/// Dialog for viewing real-time entry & exit parking history for a Monthly Pass vehicle.
class _MonthlyPassParkingHistoryDialog extends StatefulWidget {
  final MonthlyPassModel pass;
  final MonthlyPassService monthlyPassService;

  const _MonthlyPassParkingHistoryDialog({
    required this.pass,
    required this.monthlyPassService,
  });

  @override
  State<_MonthlyPassParkingHistoryDialog> createState() =>
      _MonthlyPassParkingHistoryDialogState();
}

class _MonthlyPassParkingHistoryDialogState
    extends State<_MonthlyPassParkingHistoryDialog> {
  final _searchController = TextEditingController();
  bool _newestFirst = true;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final pass = widget.pass;
    final typeLabel = pass.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.monthlyPassParkingHistory,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              pass.vehicleNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                typeLabel.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${pass.passNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.validity}: ${AppFormatters.formatDate(pass.startDate)} → ${AppFormatters.formatDate(pass.endDate)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Realtime Stream Body
              Expanded(
                child: StreamBuilder<List<ParkingRecord>>(
                  stream: widget.monthlyPassService.watchPassParkingHistory(
                    pass.vehicleNumber,
                    passId: pass.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allRecords = snapshot.data ?? [];
                    final filtered = allRecords.where((r) {
                      if (_searchQuery.isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      final ticket = r.ticketNumber.toLowerCase();
                      final date = AppFormatters.formatDate(r.entryTime).toLowerCase();
                      final guard = r.entryGuardName.toLowerCase();
                      return ticket.contains(q) || date.contains(q) || guard.contains(q);
                    }).toList();

                    filtered.sort((a, b) => _newestFirst
                        ? b.entryTime.compareTo(a.entryTime)
                        : a.entryTime.compareTo(b.entryTime));

                    final totalVisits = allRecords.length;
                    final completed = allRecords
                        .where((r) => r.status.toUpperCase() == 'COMPLETED' || r.exitTime != null)
                        .length;
                    final currentlyParked = allRecords
                        .where((r) => r.status.toUpperCase() != 'COMPLETED' && r.exitTime == null)
                        .length;

                    return Column(
                      children: [
                        // Summary Stats Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                label: AppStrings.totalVisits,
                                value: totalVisits.toString(),
                                color: AppColors.textPrimary,
                              ),
                              _buildStatItem(
                                label: AppStrings.completed,
                                value: completed.toString(),
                                color: AppColors.successDark,
                              ),
                              _buildStatItem(
                                label: AppStrings.currentlyParked,
                                value: currentlyParked.toString(),
                                color: currentlyParked > 0 ? AppColors.warningDark : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Search and Sort Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: AppStrings.searchTicketOrDate,
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: Icon(
                                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 16,
                              ),
                              label: Text(_newestFirst ? AppStrings.newestFirst : AppStrings.oldestFirst),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onPressed: () => setState(() => _newestFirst = !_newestFirst),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // List of Visits
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.history, size: 40, color: AppColors.textMuted),
                                        const SizedBox(height: 10),
                                        Text(
                                          AppStrings.noParkingVisitsRecorded,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final record = filtered[index];
                                    final isParked = record.status.toUpperCase() != 'COMPLETED' && record.exitTime == null;
                                    final duration = isParked
                                        ? DateTime.now().difference(record.entryTime)
                                        : record.exitTime!.difference(record.entryTime);

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isParked ? AppColors.warningLight.withValues(alpha: 0.3) : AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isParked ? AppColors.warning : AppColors.border,
                                          width: isParked ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Date & Ticket Header
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    AppFormatters.formatDate(record.entryTime),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isParked ? AppColors.warning : AppColors.success,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  isParked ? AppStrings.currentlyParked : AppStrings.completed,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 16),

                                          // Entry / Exit Grid
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Entry Info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${AppStrings.entry}: ${AppFormatters.formatTime(record.entryTime)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      '${AppStrings.entryGuard}: ${record.entryGuardName}',
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Ticket #${record.ticketNumber}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Exit Info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isParked
                                                          ? '${AppStrings.exit}: ${AppStrings.currentlyParked}'
                                                          : '${AppStrings.exit}: ${AppFormatters.formatTime(record.exitTime!)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: isParked ? AppColors.warningDark : AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    if (!isParked && record.exitGuardName != null) ...[
                                                      Text(
                                                        '${AppStrings.exitGuard}: ${record.exitGuardName}',
                                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                      ),
                                                      const SizedBox(height: 3),
                                                    ],
                                                    Text(
                                                      '${AppStrings.duration}: ${_formatDuration(duration)}',
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Parking Fee
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${AppStrings.parkingFee}: ₹0',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.successDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    AppStrings.monthlyPass,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textMuted,
                                                    ),
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
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
