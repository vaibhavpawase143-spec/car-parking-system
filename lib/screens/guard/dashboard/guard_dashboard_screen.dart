import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/handover_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/shift_model.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/financial_responsibility_service.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/common/stat_card.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/guard/capacity_indicator.dart';
import '../payment/payment_management_screen.dart';
import '../reports/guard_reports_screen.dart';

/// Real Guard Dashboard screen connected to Firestore real-time streams.
class GuardDashboardScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final ValueChanged<int> onNavigateTab;

  const GuardDashboardScreen({
    super.key,
    required this.currentGuard,
    required this.onNavigateTab,
  });

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  late final DashboardService _dashboardService;
  late final ShiftService _shiftService;
  late Stream<CapacityData> _capacityStream;
  late Stream<DashboardMetrics> _metricsStream;
  late Stream<List<ParkingRecord>> _recentActivityStream;
  late Stream<ShiftModel?> _activeShiftStream;
  late Stream<GuardFinancialResponsibility> _responsibilityStream;
  late Stream<List<HandoverModel>> _pendingHandoversStream;

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService();
    _shiftService = ShiftService();
    _initStreams();
  }

  void _initStreams() {
    _capacityStream = _dashboardService.watchCapacity();
    _metricsStream = _dashboardService.watchGuardTodayMetrics(
      widget.currentGuard.uid,
      guardName: widget.currentGuard.name,
    );
    _recentActivityStream = _dashboardService.watchRecentActivity(limit: 5);
    _activeShiftStream = _shiftService.watchGuardCurrentActiveShift(
      widget.currentGuard.uid,
      widget.currentGuard.email,
      widget.currentGuard.name,
    );
    _responsibilityStream = FinancialResponsibilityService.instance.watchGuardResponsibility(
      widget.currentGuard.uid,
      widget.currentGuard.name,
    );
    _pendingHandoversStream = FinancialResponsibilityService.instance.watchPendingHandoversForGuard(
      widget.currentGuard.uid,
    );
  }

  @override
  void didUpdateWidget(covariant GuardDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentGuard.uid != widget.currentGuard.uid ||
        oldWidget.currentGuard.email != widget.currentGuard.email ||
        oldWidget.currentGuard.name != widget.currentGuard.name) {
      _initStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section A: Real Guard & Active Shift Information Banner
          _buildGuardInfoCard(),
          const SizedBox(height: 16),

          // Section B: Real-Time Parking Capacity from Firestore
          StreamBuilder<CapacityData>(
            stream: _capacityStream,
            builder: (context, snapshot) {
              final capacity = snapshot.data ??
                  const CapacityData(
                    carTotal: 100,
                    carOccupied: 0,
                    twoWheelerTotal: 150,
                    twoWheelerOccupied: 0,
                  );

              return CapacityIndicator(
                carTotal: capacity.carTotal,
                carOccupied: capacity.carOccupied,
                twoWheelerTotal: capacity.twoWheelerTotal,
                twoWheelerOccupied: capacity.twoWheelerOccupied,
              );
            },
          ),
          const SizedBox(height: 16),

          // Section C: Today's Operational Statistics from Firestore
          StreamBuilder<DashboardMetrics>(
            stream: _metricsStream,
            builder: (context, snapshot) {
              final metrics = snapshot.data ?? DashboardMetrics.zero;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: AppStrings.todaysEntries,
                          value: '${metrics.todayEntries}',
                          icon: Icons.login,
                          iconColor: AppColors.primary,
                          subtitle: AppStrings.liveEntryCounter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.todaysExits,
                          value: '${metrics.todayExits}',
                          icon: Icons.logout,
                          iconColor: AppColors.secondary,
                          subtitle: AppStrings.completedSessions,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatCard(
                    title: AppStrings.todaysCollection,
                    value: AppFormatters.formatCurrency(metrics.todayCollection),
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.cashColor,
                    subtitle:
                        '${AppStrings.cash}: ${AppFormatters.formatCurrency(metrics.cashCollection)} • ${AppStrings.upi}: ${AppFormatters.formatCurrency(metrics.upiCollection)}',
                  ),
                  const SizedBox(height: 10),
                  // Outstanding Responsibility & Incoming Handover
                  StreamBuilder<GuardFinancialResponsibility>(
                    stream: _responsibilityStream,
                    builder: (context, respSnap) {
                      final resp = respSnap.data;
                      if (resp == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${AppStrings.cashOutstanding}: ${AppFormatters.formatCurrency(resp.outstandingCash)}  •  ${AppStrings.upiOutstanding}: ${AppFormatters.formatCurrency(resp.outstandingUpi)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  StreamBuilder<List<HandoverModel>>(
                    stream: _pendingHandoversStream,
                    builder: (context, pendingSnap) {
                      final list = pendingSnap.data ?? [];
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pending_actions, color: AppColors.warningDark, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${AppStrings.pendingHandoverRequest} (${list.length})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warningDark),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentManagementScreen(currentGuard: widget.currentGuard),
                                  ),
                                );
                              },
                              child: Text(AppStrings.view, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Section D: Quick Actions Grid (6 actions)
          Text(
            AppStrings.quickActions,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionsGrid(context),
          const SizedBox(height: 24),

          // Section E: Recent Activity (Real Firestore data or clean empty state)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppStrings.recentActivity,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(2), // Jump to Active Vehicles tab
                child: Text(AppStrings.viewAllActive),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<ParkingRecord>>(
            stream: _recentActivityStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return _buildEmptyActivityCard();
              }

              return Column(
                children: records.map((record) => _buildRecentRecordCard(record)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGuardInfoCard() {
    return StreamBuilder<ShiftModel?>(
      stream: _activeShiftStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${AppStrings.verifyingActiveShift} (${widget.currentGuard.name})',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warningDark, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentGuard.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.unableToVerifyShift,
                        style: const TextStyle(fontSize: 12, color: AppColors.warningDark),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _initStreams();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(AppStrings.retry, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }

        final activeShift = snapshot.data;
        final hasActiveShift = activeShift != null;

        return InkWell(
          onTap: () => widget.onNavigateTab(4), // Jump to My Shift
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasActiveShift ? AppColors.primarySurface : AppColors.dangerLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveShift
                    ? AppColors.primaryLight.withValues(alpha: 0.25)
                    : AppColors.danger.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasActiveShift ? AppColors.primary : AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasActiveShift ? Icons.shield_outlined : Icons.event_busy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.currentGuard.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: hasActiveShift ? AppColors.primary : AppColors.dangerDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusBadge(
                            label: hasActiveShift ? AppStrings.activeState.toUpperCase() : 'NO SHIFT',
                            type: hasActiveShift ? BadgeType.active : BadgeType.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (hasActiveShift)
                        Text(
                          '${AppStrings.startTime} - ${AppStrings.endTime}: ${AppFormatters.formatTime(activeShift.startTime)} - ${AppFormatters.formatTime(activeShift.endTime)} • ${AppStrings.timeRemaining}: ${activeShift.timeRemaining.inHours}h ${activeShift.timeRemaining.inMinutes % 60}m',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        Text(
                          '${AppStrings.noActiveShiftAssigned} ${AppStrings.contactAdmin}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.dangerDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _buildActionTile(
              title: AppStrings.vehicleEntry,
              icon: Icons.add_circle_outline,
              color: AppColors.primary,
              onTap: () => widget.onNavigateTab(1),
            ),
            _buildActionTile(
              title: AppStrings.vehicleExit,
              icon: Icons.output_outlined,
              color: AppColors.danger,
              onTap: () => widget.onNavigateTab(3),
            ),
            _buildActionTile(
              title: AppStrings.activeParking,
              icon: Icons.local_parking_outlined,
              color: AppColors.secondary,
              onTap: () => widget.onNavigateTab(2),
            ),
            _buildActionTile(
              title: AppStrings.myShift,
              icon: Icons.schedule_outlined,
              color: AppColors.warningDark,
              onTap: () => widget.onNavigateTab(4),
            ),
            _buildActionTile(
              title: AppStrings.dailyCollection,
              icon: Icons.receipt_long_outlined,
              color: AppColors.cashColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentManagementScreen(currentGuard: widget.currentGuard),
                  ),
                );
              },
            ),
            _buildActionTile(
              title: AppStrings.reports,
              icon: Icons.bar_chart_outlined,
              color: AppColors.upiColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuardReportsScreen(currentGuard: widget.currentGuard),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivityCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              AppStrings.noRecentActivity,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.noRecentActivityDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecordCard(ParkingRecord record) {
    final isCar = record.vehicleType.name == 'fourWheeler';
    final statusLabel = record.isActive ? AppStrings.active : AppStrings.exited;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isCar ? AppColors.primarySurface : AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCar ? Icons.directions_car : Icons.two_wheeler,
            color: isCar ? AppColors.primary : AppColors.secondary,
            size: 20,
          ),
        ),
        title: Text(
          record.vehicleNumber,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${AppStrings.entryTime}: ${AppFormatters.formatTime(record.entryTime)} • ${AppStrings.ticketNumber}: ${record.ticketNumber}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: StatusBadge(
          label: statusLabel,
          type: record.isActive ? BadgeType.active : BadgeType.exited,
        ),
      ),
    );
  }
}
