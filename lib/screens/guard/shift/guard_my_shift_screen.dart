import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/shift_model.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/stat_card.dart';
import '../../../widgets/common/status_badge.dart';

/// Dedicated READ-ONLY "My Shift" page for Guards.
/// Guards cannot start, end, or edit any shift. All shifts are Admin-assigned fixed 8-hour sessions.
class GuardMyShiftScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final Stream<List<ShiftModel>>? customShiftsStream;

  const GuardMyShiftScreen({
    super.key,
    required this.currentGuard,
    required this.onReturnDashboard,
    this.customShiftsStream,
  });

  @override
  State<GuardMyShiftScreen> createState() => _GuardMyShiftScreenState();
}

class _GuardMyShiftScreenState extends State<GuardMyShiftScreen> {
  final _shiftService = ShiftService();
  late Stream<List<ShiftModel>> _shiftsStream;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initStream();
    // Update live elapsed/remaining countdown every 30 seconds
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _initStream() {
    _shiftsStream = widget.customShiftsStream ??
        _shiftService.watchGuardShifts(
          widget.currentGuard.uid,
          widget.currentGuard.email,
          widget.currentGuard.name,
        );
  }

  @override
  void didUpdateWidget(covariant GuardMyShiftScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentGuard.uid != widget.currentGuard.uid ||
        oldWidget.currentGuard.email != widget.currentGuard.email ||
        oldWidget.currentGuard.name != widget.currentGuard.name ||
        oldWidget.customShiftsStream != widget.customShiftsStream) {
      _initStream();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShiftModel>>(
      stream: _shiftsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.loadingShiftInfo,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync_problem, size: 48, color: AppColors.warning),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.unableToLoadShiftDetails,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: AppStrings.retry,
                    icon: Icons.refresh,
                    type: AppButtonType.primary,
                    onPressed: () {
                      setState(() {
                        _initStream();
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final shifts = snapshot.data ?? [];
        debugPrint('[MY_SHIFT] Guard: ${widget.currentGuard.name} (${widget.currentGuard.uid}) | Raw shifts received: ${shifts.length}');

        // Separate shifts
        ShiftModel? activeShift;
        final upcomingShifts = <ShiftModel>[];
        final completedShifts = <ShiftModel>[];

        for (final s in shifts) {
          if (s.isCancelled) continue;
          if (s.isActive) {
            activeShift ??= s;
          } else if (s.isUpcoming) {
            upcomingShifts.add(s);
          } else if (s.isCompleted) {
            completedShifts.add(s);
          }
        }

        debugPrint('[MY_SHIFT] Active shift: ${activeShift?.shiftId} (status=${activeShift?.status}) | Upcoming count: ${upcomingShifts.length} | Completed count: ${completedShifts.length}');

        // Sort upcoming soonest first
        upcomingShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
        // Sort completed newest first
        completedShifts.sort((a, b) => b.endTime.compareTo(a.endTime));

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _initStream();
            });
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Current / Assigned Shift Section
                Text(
                  AppStrings.currentShift,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (activeShift != null)
                  _buildActiveShiftCard(activeShift)
                else if (upcomingShifts.isNotEmpty)
                  _buildUpcomingPrimaryCard(upcomingShifts.first)
                else
                  _buildNoActiveShiftCard(),

                const SizedBox(height: 24),

                // 2. Upcoming Assigned Shifts Section (if additional upcoming exist)
                if (activeShift != null || upcomingShifts.length > 1) ...[
                  Text(
                    AppStrings.upcomingShifts,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (activeShift != null && upcomingShifts.isEmpty)
                    _buildEmptyStateCard(
                      icon: Icons.event_available_outlined,
                      message: AppStrings.noUpcomingShifts,
                    )
                  else
                    Column(
                      children: (activeShift != null ? upcomingShifts : upcomingShifts.skip(1))
                          .map((s) => _buildUpcomingShiftCard(s))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                ],

                // 3. Completed Shifts History
                Text(
                  AppStrings.shiftHistory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (completedShifts.isEmpty)
                  _buildEmptyStateCard(
                    icon: Icons.history_outlined,
                    message: AppStrings.noCompletedShifts,
                  )
                else
                  Column(
                    children: completedShifts.map((s) => _buildCompletedShiftCard(s)).toList(),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveShiftCard(ShiftModel shift) {
    final elapsed = shift.timeElapsed;
    final remaining = shift.timeRemaining;

    final elapsedStr = '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    final remainingStr = '${remaining.inHours}h ${remaining.inMinutes % 60}m';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.guardName.isNotEmpty ? shift.guardName : widget.currentGuard.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppFormatters.formatDate(shift.shiftDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatusBadge(
                label: AppStrings.activeState.toUpperCase(),
                type: BadgeType.active,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Time & Duration Grid
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.startTime,
                  value: AppFormatters.formatTime(shift.startTime),
                  icon: Icons.login_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.endTime,
                  value: AppFormatters.formatTime(shift.endTime),
                  icon: Icons.logout_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.duration,
                  value: AppStrings.eightHours,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Elapsed and Remaining Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timelapse, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.timeElapsed}: ',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      elapsedStr,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: AppColors.border),
                Row(
                  children: [
                    const Icon(Icons.hourglass_bottom, color: AppColors.warning, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.timeRemaining}: ',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      remainingStr,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warningDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Shift Operational Statistics
          StreamBuilder<ShiftStats>(
            stream: _shiftService.watchShiftStats(shift),
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data ?? ShiftStats.zero;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: AppStrings.todaysEntries,
                          value: '${stats.entriesCount}',
                          icon: Icons.login,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.todaysExits,
                          value: '${stats.exitsCount}',
                          icon: Icons.logout,
                          iconColor: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StatCard(
                    title: AppStrings.todaysCollection,
                    value: AppFormatters.formatCurrency(stats.totalCollection),
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.cashColor,
                    subtitle:
                        '${AppStrings.cash}: ${AppFormatters.formatCurrency(stats.cashCollection)} • ${AppStrings.upi}: ${AppFormatters.formatCurrency(stats.upiCollection)}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPrimaryCard(ShiftModel shift) {
    final now = DateTime.now();
    final startsInDuration = shift.startTime.isAfter(now)
        ? shift.startTime.difference(now)
        : Duration.zero;
    final startsInStr = '${startsInDuration.inHours}h ${startsInDuration.inMinutes % 60}m';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.guardName.isNotEmpty ? shift.guardName : widget.currentGuard.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppFormatters.formatDate(shift.shiftDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatusBadge(
                label: AppStrings.assigned.toUpperCase(),
                type: BadgeType.info,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Time & Duration Grid
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.startTime,
                  value: AppFormatters.formatTime(shift.startTime),
                  icon: Icons.login_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.endTime,
                  value: AppFormatters.formatTime(shift.endTime),
                  icon: Icons.logout_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: AppStrings.duration,
                  value: AppStrings.eightHours,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Countdown Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm, color: AppColors.primaryLight, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${AppStrings.startsIn} ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  startsInStr,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveShiftCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.dangerLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.dangerLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy, color: AppColors.danger, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.noShiftAssigned,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.dangerDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.contactAdmin,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              AppStrings.noActiveShiftWarning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.dangerDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingShiftCard(ShiftModel shift) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.formatDate(shift.shiftDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.formatTime(shift.startTime)} - ${AppFormatters.formatTime(shift.endTime)} • ${AppStrings.eightHours}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: AppStrings.assigned.toUpperCase(),
              type: BadgeType.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedShiftCard(ShiftModel shift) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppFormatters.formatDate(shift.shiftDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scheduled: ${AppFormatters.formatTime(shift.startTime)} - ${AppFormatters.formatTime(shift.endTime)} • ${shift.durationHours} Hours',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (shift.actualStartTime != null || shift.actualEndTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Actual: ${shift.actualStartTime != null ? AppFormatters.formatTime(shift.actualStartTime!) : "-"} - ${shift.actualEndTime != null ? AppFormatters.formatTime(shift.actualEndTime!) : "-"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (shift.startedBy == 'SYSTEM')
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Start: ${shift.startedBy == 'SYSTEM' ? 'AUTO' : (shift.startedBy != null ? 'MANUAL' : 'AUTO')}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (shift.startedBy == 'SYSTEM') ? AppColors.primary : AppColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (shift.endedBy == 'SYSTEM')
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'End: ${shift.endedBy == 'SYSTEM' ? 'AUTO' : (shift.endedBy != null ? 'MANUAL' : 'AUTO')}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (shift.endedBy == 'SYSTEM') ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: AppStrings.completedState.toUpperCase(),
                  type: BadgeType.active,
                ),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<ShiftStats>(
              stream: _shiftService.watchShiftStats(shift),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? ShiftStats.zero;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        '${AppStrings.entry}: ${stats.entriesCount}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${AppStrings.exit}: ${stats.exitsCount}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${AppStrings.collection}: ${AppFormatters.formatCurrency(stats.totalCollection)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.cashColor),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
