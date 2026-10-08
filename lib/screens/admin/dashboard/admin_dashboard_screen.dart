import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/monthly_pass_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/status_badge.dart';
import '../passes/admin_monthly_pass_management_screen.dart';

/// Admin Dashboard Screen focused strictly on core operational scope:
/// A. Header / Admin Profile
/// B. Guard Statistics
/// C. Parking Capacity & Occupancy (with Admin Edit Capacity)
/// D. Today's Operations
/// E. Monthly Passes
class AdminDashboardScreen extends StatefulWidget {
  final GuardModel currentAdmin;
  final Function(int tabIndex)? onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    required this.currentAdmin,
    this.onNavigateTab,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _dashboardService = DashboardService();
  final _monthlyPassService = MonthlyPassService.instance;

  final ScrollController _scrollController = ScrollController();

  late Stream<AdminGuardStats> _guardStatsStream;
  late Stream<CapacityData> _capacityStream;
  late Stream<DashboardMetrics> _todayMetricsStream;
  late Stream<MonthlyPassDashboardStats> _passStatsStream;

  @override
  void initState() {
    super.initState();
    debugPrint('[ADMIN_DASHBOARD_DEBUG] initState()');
    debugPrint('[ADMIN_DASHBOARD_DEBUG] currentAdmin: uid=${widget.currentAdmin.uid}, name=${widget.currentAdmin.name}, role=${widget.currentAdmin.role}');
    _initStreams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('[ADMIN_DASHBOARD_DEBUG] didChangeDependencies()');
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('[ADMIN_DASHBOARD_DEBUG] didUpdateWidget()');
    if (oldWidget.currentAdmin.uid != widget.currentAdmin.uid) {
      _initStreams();
    }
  }

  @override
  void dispose() {
    debugPrint('[ADMIN_DASHBOARD_DEBUG] dispose()');
    _scrollController.dispose();
    super.dispose();
  }

  void _initStreams() {
    debugPrint('[STREAM] Initializing active dashboard streams: GuardStats, Capacity, TodayMetrics, MonthlyPassStats');
    _guardStatsStream = _adminService.watchGuardStats().asBroadcastStream();
    _capacityStream = _dashboardService.watchCapacity().asBroadcastStream();
    _todayMetricsStream = _dashboardService.watchTodayMetrics().asBroadcastStream();
    _passStatsStream = _monthlyPassService.watchDashboardStats().asBroadcastStream();
    debugPrint('[STREAM] Dashboard streams created successfully');
  }

  void _refresh() {
    setState(() {
      _initStreams();
    });
  }

  // ---------------------------------------------------------------------------
  // EDIT CAPACITY DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _openEditCapacityDialog(CapacityData currentData) async {
    debugPrint('[CAPACITY-DEBUG] Edit Capacity button pressed');
    debugPrint('[CAPACITY-DEBUG] Opening capacity dialog');
    debugPrint('[CAPACITY-DEBUG] Current capacity: 4W=${currentData.carTotal} (occ: ${currentData.carOccupied}), 2W=${currentData.twoWheelerTotal} (occ: ${currentData.twoWheelerOccupied})');

    final fourWheelerController = TextEditingController(text: '${currentData.carTotal}');
    final twoWheelerController = TextEditingController(text: '${currentData.twoWheelerTotal}');
    int calculatedTotal = currentData.carTotal + currentData.twoWheelerTotal;
    String? dialogError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void updateTotal() {
            final car = int.tryParse(fourWheelerController.text.trim()) ?? 0;
            final bike = int.tryParse(twoWheelerController.text.trim()) ?? 0;
            setDlgState(() {
              calculatedTotal = car + bike;
              dialogError = null;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.local_parking, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(AppStrings.editCapacity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
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
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Four-Wheeler Input
                  Text(AppStrings.fourWheelerCapacity, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const ValueKey('dialog_four_wheeler_capacity_input'),
                    controller: fourWheelerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 100',
                      helperText: 'Currently Occupied: ${currentData.carOccupied}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => updateTotal(),
                  ),
                  const SizedBox(height: 14),

                  // Two-Wheeler Input
                  Text(AppStrings.twoWheelerCapacity, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const ValueKey('dialog_two_wheeler_capacity_input'),
                    controller: twoWheelerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 150',
                      helperText: 'Currently Occupied: ${currentData.twoWheelerOccupied}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => updateTotal(),
                  ),
                  const SizedBox(height: 16),

                  // Auto-calculated Total Capacity Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.totalCapacity,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Text(
                              '(Auto-calculated)',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        Text(
                          '$calculatedTotal',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
              TextButton(
                key: const ValueKey('dialog_cancel_capacity_button'),
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.cancel),
              ),
              ElevatedButton(
                key: const ValueKey('dialog_save_capacity_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        debugPrint('[CAPACITY-DEBUG] Save button pressed');
                        final car = int.tryParse(fourWheelerController.text.trim()) ?? 0;
                        final bike = int.tryParse(twoWheelerController.text.trim()) ?? 0;

                        if (car <= 0 || bike <= 0) {
                          setDlgState(() => dialogError = 'Capacity must be greater than zero.');
                          return;
                        }

                        // Strict validation: capacity >= current occupancy
                        if (car < currentData.carOccupied) {
                          setDlgState(() => dialogError = AppStrings.fourWheelerCapacityError(currentData.carOccupied));
                          return;
                        }
                        if (bike < currentData.twoWheelerOccupied) {
                          setDlgState(() => dialogError = AppStrings.twoWheelerCapacityError(currentData.twoWheelerOccupied));
                          return;
                        }

                        debugPrint('[CAPACITY-DEBUG] Validation passed: 4W=$car, 2W=$bike');
                        setDlgState(() => isSaving = true);

                        try {
                          final authUid = FirebaseAuth.instance.currentUser?.uid;
                          final adminUid = widget.currentAdmin.uid.isNotEmpty
                              ? widget.currentAdmin.uid
                              : (authUid ?? '');
                          final adminName = widget.currentAdmin.name.isNotEmpty
                              ? widget.currentAdmin.name
                              : 'Master Admin';

                          debugPrint('[CAPACITY_PERMISSION_DEBUG]');
                          debugPrint('path = settings/system_config');
                          debugPrint('authUid = $authUid');
                          debugPrint('currentAdmin.uid = ${widget.currentAdmin.uid}');
                          debugPrint('currentAdmin.role = ${widget.currentAdmin.role}');
                          debugPrint('currentAdmin.isActive = ${widget.currentAdmin.isActive}');
                          debugPrint('operation = update');

                          await SettingsService.instance.updateCapacity(
                            fourWheelerCapacity: car,
                            twoWheelerCapacity: bike,
                            adminUid: adminUid,
                            adminName: adminName,
                            currentFourWheelerOccupied: currentData.carOccupied,
                            currentTwoWheelerOccupied: currentData.twoWheelerOccupied,
                          );

                          debugPrint('[CAPACITY-DEBUG] Firestore update completed');
                          debugPrint('[CAPACITY-DEBUG] Dashboard capacity updated');

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.capacityUpdatedSuccess)),
                            );
                          }
                        } catch (e) {
                          debugPrint('[CAPACITY-DEBUG] Error updating capacity: $e');
                          setDlgState(() {
                            dialogError = 'Unable to update parking capacity: $e';
                            isSaving = false;
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(AppStrings.saveChanges),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ADMIN_DASHBOARD_DEBUG] build() START');
    final widgetTree = Scaffold(
      backgroundColor: AppColors.background,
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A. Header / Admin Profile
                Builder(builder: (ctx) {
                  debugPrint('[SECTION] Header/Profile START');
                  final w = _buildHeader();
                  debugPrint('[SECTION] Header/Profile DONE');
                  return w;
                }),
                const SizedBox(height: 20),

                // B. Guard Statistics
                _buildSectionHeader(
                  title: AppStrings.guardStatistics,
                  icon: Icons.people_outline,
                  onViewAll: () => widget.onNavigateTab?.call(1),
                ),
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  debugPrint('[SECTION] Guard Statistics START');
                  final w = _buildGuardStatsGrid();
                  debugPrint('[SECTION] Guard Statistics DONE');
                  return w;
                }),
                const SizedBox(height: 24),

                // C. Parking Capacity & Occupancy (Admin Edit Control)
                _buildSectionHeader(
                  title: AppStrings.parkingCapacity,
                  icon: Icons.local_parking_outlined,
                ),
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  debugPrint('[SECTION] Parking Capacity START');
                  final w = _buildParkingCapacitySection();
                  debugPrint('[SECTION] Parking Capacity DONE');
                  return w;
                }),
                const SizedBox(height: 24),

                // D. Today's Operations
                _buildSectionHeader(
                  title: AppStrings.todaysOperations,
                  icon: Icons.point_of_sale,
                  onViewAll: () => widget.onNavigateTab?.call(3),
                ),
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  debugPrint('[SECTION] Today\'s Operations START');
                  final w = _buildTodayOperationsGrid();
                  debugPrint('[SECTION] Today\'s Operations DONE');
                  return w;
                }),
                const SizedBox(height: 24),

                // E. Monthly Passes
                _buildSectionHeader(
                  title: AppStrings.monthlyPasses,
                  icon: Icons.credit_card,
                  onViewAll: _navigateToPasses,
                ),
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  debugPrint('[SECTION] Monthly Passes START');
                  final w = _buildMonthlyPassSection();
                  debugPrint('[SECTION] Monthly Passes DONE');
                  return w;
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
    debugPrint('[ADMIN_DASHBOARD_DEBUG] build() COMPLETED');
    return widgetTree;
  }

  void _navigateToPasses() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(5);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminMonthlyPassManagementScreen(currentAdmin: widget.currentAdmin),
        ),
      );
    }
  }

  Widget _buildMonthlyPassSection() {
    return StreamBuilder<MonthlyPassDashboardStats>(
      stream: _passStatsStream,
      initialData: MonthlyPassDashboardStats.zero,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? MonthlyPassDashboardStats.zero;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  final count = isWide ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: count,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 1.6 : 1.35,
                    children: [
                      _buildPassMetricTile(
                        title: AppStrings.activePasses,
                        value: '${stats.activePasses}',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                      _buildPassMetricTile(
                        title: AppStrings.expiringSoon,
                        value: '${stats.expiringSoonPasses}',
                        icon: Icons.warning_amber_outlined,
                        color: AppColors.warning,
                      ),
                      _buildPassMetricTile(
                        title: AppStrings.expiredPasses,
                        value: '${stats.expiredPasses}',
                        icon: Icons.history,
                        color: AppColors.textSecondary,
                      ),
                      _buildPassMetricTile(
                        title: AppStrings.passCollection,
                        value: AppFormatters.formatCurrency(stats.passCollection),
                        icon: Icons.currency_rupee,
                        color: AppColors.primary,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('btn_view_all_passes'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(AppStrings.viewAllPasses),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: _navigateToPasses,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // A. HEADER / ADMIN PROFILE
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.darkOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.profile}: ${widget.currentAdmin.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.adminPortalTitle} • ${AppFormatters.formatDate(now)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  AppLanguageController.instance.isMarathi ? 'मराठी' : 'English',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: () {
              debugPrint('[DASHBOARD] Manual refresh requested');
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    VoidCallback? onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              AppStrings.all,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // B. GUARD STATISTICS
  // ---------------------------------------------------------------------------
  Widget _buildGuardStatsGrid() {
    return StreamBuilder<AdminGuardStats>(
      stream: _guardStatsStream,
      initialData: AdminGuardStats.zero,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error);
        }

        final stats = snapshot.data ?? AdminGuardStats.zero;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;
            final isMedium = constraints.maxWidth >= 600;
            final count = isWide ? 6 : (isMedium ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 94,
              ),
              itemCount: 6,
              itemBuilder: (ctx, idx) {
                switch (idx) {
                  case 0:
                    return _buildClickableStatCard(
                      title: AppStrings.totalGuards,
                      value: '${stats.totalGuards}',
                      icon: Icons.people,
                      color: AppColors.primary,
                      onTap: () => widget.onNavigateTab?.call(1),
                    );
                  case 1:
                    return _buildClickableStatCard(
                      title: AppStrings.activeGuards,
                      value: '${stats.activeGuards}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      onTap: () => widget.onNavigateTab?.call(1),
                    );
                  case 2:
                    return _buildClickableStatCard(
                      title: AppStrings.inactiveGuards,
                      value: '${stats.inactiveGuards}',
                      icon: Icons.cancel_outlined,
                      color: AppColors.textSecondary,
                      onTap: () => widget.onNavigateTab?.call(1),
                    );
                  case 3:
                    return _buildClickableStatCard(
                      title: AppStrings.currentlyOnShift,
                      value: '${stats.currentlyOnShift}',
                      icon: Icons.schedule,
                      color: AppColors.primaryLight,
                      onTap: () => widget.onNavigateTab?.call(2),
                    );
                  case 4:
                    return _buildClickableStatCard(
                      title: AppStrings.upcoming,
                      value: '${stats.upcomingShiftGuards}',
                      icon: Icons.event_available,
                      color: AppColors.warning,
                      onTap: () => widget.onNavigateTab?.call(2),
                    );
                  case 5:
                  default:
                    return _buildClickableStatCard(
                      title: AppStrings.guardsWithNoShift,
                      value: '${stats.guardsWithNoShift}',
                      icon: Icons.warning_amber_outlined,
                      color: stats.guardsWithNoShift > 0 ? AppColors.danger : AppColors.textSecondary,
                      onTap: () => widget.onNavigateTab?.call(1),
                    );
                }
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // C. PARKING CAPACITY & OCCUPANCY (Admin Edit Control)
  // ---------------------------------------------------------------------------
  Widget _buildParkingCapacitySection() {
    return StreamBuilder<CapacityData>(
      stream: _capacityStream,
      initialData: const CapacityData(
        carTotal: 100,
        carOccupied: 0,
        twoWheelerTotal: 150,
        twoWheelerOccupied: 0,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error);
        }

        final data = snapshot.data ??
            const CapacityData(
              carTotal: 100,
              carOccupied: 0,
              twoWheelerTotal: 150,
              twoWheelerOccupied: 0,
            );

        final totalCapacity = data.carTotal + data.twoWheelerTotal;
        final totalOccupied = data.carOccupied + data.twoWheelerOccupied;
        final totalAvailable = data.carAvailable + data.twoWheelerAvailable;

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;

                final fourWheelerCard = _buildAdminCapacityCard(
                  vehicleLabel: AppStrings.fourWheeler,
                  icon: Icons.directions_car,
                  total: data.carTotal,
                  occupied: data.carOccupied,
                  available: data.carAvailable,
                  color: AppColors.primary,
                  onEdit: () => _openEditCapacityDialog(data),
                );

                final twoWheelerCard = _buildAdminCapacityCard(
                  vehicleLabel: AppStrings.twoWheeler,
                  icon: Icons.two_wheeler,
                  total: data.twoWheelerTotal,
                  occupied: data.twoWheelerOccupied,
                  available: data.twoWheelerAvailable,
                  color: AppColors.primaryLight,
                  onEdit: () => _openEditCapacityDialog(data),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: fourWheelerCard),
                      const SizedBox(width: 14),
                      Expanded(child: twoWheelerCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    fourWheelerCard,
                    const SizedBox(height: 12),
                    twoWheelerCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),

            // Summary row with Total Capacity & Edit Capacity Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: LayoutBuilder(
                builder: (context, summaryConstraints) {
                  final isWideSummary = summaryConstraints.maxWidth >= 540;

                  final editButton = ElevatedButton.icon(
                    key: const ValueKey('admin_edit_capacity_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text(
                      AppStrings.editCapacity,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _openEditCapacityDialog(data),
                  );

                  if (isWideSummary) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _buildInlineMetric(AppStrings.totalCapacity, '$totalCapacity', AppColors.primary),
                            const SizedBox(width: 24),
                            _buildInlineMetric(AppStrings.totalOccupied, '$totalOccupied', AppColors.warning),
                            const SizedBox(width: 24),
                            _buildInlineMetric(AppStrings.totalAvailable, '$totalAvailable', AppColors.success),
                          ],
                        ),
                        editButton,
                      ],
                    );
                  }

                  // Mobile responsive layout:
                  // Total Capacity     Total Occupied     Total Available
                  // [ Edit Capacity ]
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildInlineMetric(AppStrings.totalCapacity, '$totalCapacity', AppColors.primary)),
                          Expanded(child: _buildInlineMetric(AppStrings.totalOccupied, '$totalOccupied', AppColors.warning)),
                          Expanded(child: _buildInlineMetric(AppStrings.totalAvailable, '$totalAvailable', AppColors.success)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      editButton,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminCapacityCard({
    required String vehicleLabel,
    required IconData icon,
    required int total,
    required int occupied,
    required int available,
    required Color color,
    required VoidCallback onEdit,
  }) {
    final percent = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;
    final percentInt = (percent * 100).toInt();
    final isFull = available <= 0;

    return AppCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicleLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                onPressed: onEdit,
              ),
              StatusBadge(
                label: isFull ? AppStrings.full : '$available ${AppStrings.available}',
                type: isFull ? BadgeType.danger : BadgeType.active,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFull ? AppColors.danger : color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSlotItem(AppStrings.occupiedSlots, '$occupied', AppColors.warning),
              _buildSlotItem(AppStrings.availableSlots, '$available', AppColors.success),
              _buildSlotItem(AppStrings.totalSlots, '$total', AppColors.textPrimary),
              _buildSlotItem('%', '$percentInt%', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSlotItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // D. TODAY'S OPERATIONS
  // ---------------------------------------------------------------------------
  Widget _buildTodayOperationsGrid() {
    return StreamBuilder<DashboardMetrics>(
      stream: _todayMetricsStream,
      initialData: DashboardMetrics.zero,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error);
        }

        final metrics = snapshot.data ?? DashboardMetrics.zero;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;
            final isMedium = constraints.maxWidth >= 600;
            final count = isWide ? 5 : (isMedium ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 94,
              ),
              itemCount: 5,
              itemBuilder: (ctx, idx) {
                switch (idx) {
                  case 0:
                    return _buildStatCard(
                      title: AppStrings.todayTotalCollection,
                      value: AppFormatters.formatCurrency(metrics.todayCollection),
                      icon: Icons.account_balance_wallet,
                      color: AppColors.primary,
                      onTap: () => widget.onNavigateTab?.call(3),
                    );
                  case 1:
                    return _buildStatCard(
                      title: AppStrings.cashCollection,
                      value: AppFormatters.formatCurrency(metrics.cashCollection),
                      icon: Icons.payments_outlined,
                      color: AppColors.cashColor,
                      onTap: () => widget.onNavigateTab?.call(3),
                    );
                  case 2:
                    return _buildStatCard(
                      title: AppStrings.upiCollection,
                      value: AppFormatters.formatCurrency(metrics.upiCollection),
                      icon: Icons.qr_code,
                      color: AppColors.upiColor,
                      onTap: () => widget.onNavigateTab?.call(3),
                    );
                  case 3:
                    return _buildStatCard(
                      title: AppStrings.todayEntries,
                      value: '${metrics.todayEntries}',
                      icon: Icons.login,
                      color: AppColors.primaryLight,
                      onTap: () => widget.onNavigateTab?.call(4),
                    );
                  case 4:
                  default:
                    return _buildStatCard(
                      title: AppStrings.todayExits,
                      value: '${metrics.todayExits}',
                      icon: Icons.logout,
                      color: AppColors.textSecondary,
                      onTap: () => widget.onNavigateTab?.call(4),
                    );
                }
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildStatCard(title: title, value: value, icon: icon, color: color, onTap: onTap);
  }

  Widget _buildErrorCard(dynamic error) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${AppStrings.unableToLoadData} ($error)',
                style: const TextStyle(fontSize: 12, color: AppColors.dangerDark),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: _refresh,
              child: Text(AppStrings.refresh),
            ),
          ],
        ),
      ),
    );
  }
}
