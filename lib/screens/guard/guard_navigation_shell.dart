import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_language_controller.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/guard_model.dart';
import '../../models/handover_model.dart';
import '../../models/shift_model.dart';
import '../../models/withdrawal_model.dart';
import '../../services/financial_responsibility_service.dart';
import '../../services/guard_auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/guard/guard_app_bar.dart';
import '../../widgets/guard/guard_bottom_nav.dart';
import '../../widgets/guard/mandatory_handover_popup.dart';
import '../../widgets/notifications/notification_dialog.dart';
import '../../widgets/printer/bluetooth_printer_dialog.dart';
import '../../widgets/settings/language_settings_dialog.dart';
import 'active/active_parking_screen.dart';
import 'dashboard/guard_dashboard_screen.dart';
import 'entry/vehicle_entry_screen.dart';
import 'exit/vehicle_exit_search_screen.dart';
import 'payment/payment_management_screen.dart';
import 'reports/guard_reports_screen.dart';
import 'shift/guard_my_shift_screen.dart';

/// Primary navigation shell for authenticated Guards.
/// Integrates Tab 0 (Dashboard), Tab 1 (Vehicle Entry), Tab 2 (Active Parking), Tab 3 (Vehicle Exit), Tab 4 (My Shift).
class GuardNavigationShell extends StatefulWidget {
  final GuardModel currentGuard;

  const GuardNavigationShell({
    super.key,
    required this.currentGuard,
  });

  @override
  State<GuardNavigationShell> createState() => _GuardNavigationShellState();
}

class _GuardNavigationShellState extends State<GuardNavigationShell> {
  int _currentIndex = 0;
  final _guardAuthService = GuardAuthService();
  final _shiftService = ShiftService();
  final _financialService = FinancialResponsibilityService.instance;
  final _notificationService = NotificationService();

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: AppStrings.confirmSignOut,
      message: AppStrings.signOutConfirmMessage,
      confirmLabel: AppStrings.signOut,
      cancelLabel: AppStrings.cancel,
      isDestructive: true,
      icon: Icons.logout,
    );

    if (confirmed && mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      await _guardAuthService.signOut();
    }
  }

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primarySurface,
                    child: Icon(Icons.person, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentGuard.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Email: ${widget.currentGuard.email}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.currentGuard.mobile.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Mobile: ${widget.currentGuard.mobile}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StatusBadge(
                              label: widget.currentGuard.role.toUpperCase(),
                              type: BadgeType.info,
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: widget.currentGuard.isActive ? 'Active' : 'Inactive',
                              type: widget.currentGuard.isActive ? BadgeType.active : BadgeType.danger,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Real-time Current Shift Card inside Profile
              StreamBuilder<ShiftModel?>(
                stream: _shiftService.watchGuardCurrentActiveShift(
                  widget.currentGuard.uid,
                  widget.currentGuard.email,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHIFT STATUS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Could not connect to shift service. Retrying...',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    );
                  }

                  final shift = snapshot.data;
                  final bool hasActiveShift = shift != null;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasActiveShift ? AppColors.primarySurface : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasActiveShift ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.currentShift.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            StatusBadge(
                              label: hasActiveShift ? AppStrings.activeState.toUpperCase() : 'NO SHIFT',
                              type: hasActiveShift ? BadgeType.active : BadgeType.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (hasActiveShift) ...[
                          Text(
                            '${AppStrings.shiftDate}: ${AppFormatters.formatDate(shift.shiftDate)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppStrings.startTime} - ${AppStrings.endTime}: ${AppFormatters.formatTime(shift.startTime)} - ${AppFormatters.formatTime(shift.endTime)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppStrings.duration}: ${AppStrings.eightHours} • ${AppStrings.timeElapsed}: ${shift.timeElapsed.inHours}h ${shift.timeElapsed.inMinutes % 60}m • ${AppStrings.timeRemaining}: ${shift.timeRemaining.inHours}h ${shift.timeRemaining.inMinutes % 60}m',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ] else ...[
                          Text(
                            AppStrings.noActiveShiftAssigned,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dangerDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.contactAdmin,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _onNavTap(4); // Jump to My Shift tab
                            },
                            icon: const Icon(Icons.schedule, size: 16),
                            label: Text(AppStrings.viewMyShift, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Live Financial Responsibility Card inside Profile
              StreamBuilder<GuardFinancialResponsibility>(
                stream: _financialService.watchGuardResponsibility(widget.currentGuard.uid, widget.currentGuard.name),
                builder: (context, respSnap) {
                  final resp = respSnap.data ?? GuardFinancialResponsibility.zero;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.financialResponsibilityTitle.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppStrings.cashOutstanding, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(
                              AppFormatters.formatCurrency(resp.outstandingCash),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: resp.outstandingCash > 0 ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppStrings.upiOutstanding, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(
                              AppFormatters.formatCurrency(resp.outstandingUpi),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: resp.outstandingUpi > 0 ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppStrings.totalOutstanding, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              AppFormatters.formatCurrency(resp.totalOutstanding),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: resp.totalOutstanding > 0 ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Navigation Action Buttons
              AppButton(
                label: AppStrings.paymentManagement,
                type: AppButtonType.secondary,
                icon: Icons.account_balance_wallet_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentManagementScreen(currentGuard: widget.currentGuard),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: AppStrings.guardReports,
                type: AppButtonType.secondary,
                icon: Icons.bar_chart_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuardReportsScreen(currentGuard: widget.currentGuard),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: AppStrings.notifications,
                type: AppButtonType.outline,
                icon: Icons.notifications_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  NotificationDialog.show(context, userId: widget.currentGuard.uid);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showHandoverHistoryModal();
                      },
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: Text(AppStrings.handoverHistory, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showWithdrawalHistoryModal();
                      },
                      icon: const Icon(Icons.account_balance_outlined, size: 16),
                      label: Text(AppStrings.withdrawalHistory, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                label: AppStrings.signOut,
                type: AppButtonType.danger,
                icon: Icons.logout,
                onPressed: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHandoverHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.handoverHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<HandoverModel>>(
                  stream: _financialService.watchGuardHandovers(widget.currentGuard.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final handovers = snapshot.data ?? [];
                    if (handovers.isEmpty) {
                      return const Center(child: Text('No handover history recorded.'));
                    }
                    return ListView.separated(
                      itemCount: handovers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final h = handovers[i];
                        final isOutgoing = h.fromGuardId == widget.currentGuard.uid;
                        return ListTile(
                          leading: Icon(
                            isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isOutgoing ? AppColors.warningDark : AppColors.success,
                          ),
                          title: Text(
                            '${isOutgoing ? "To ${h.toGuardName}" : "From ${h.fromGuardName}"} (${h.type})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${AppFormatters.formatDate(h.createdAt)} ${AppFormatters.formatTime(h.createdAt)} • ${h.status}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            AppFormatters.formatCurrency(h.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWithdrawalHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.withdrawalHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<WithdrawalModel>>(
                  stream: _financialService.watchGuardWithdrawals(widget.currentGuard.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final withdrawals = snapshot.data ?? [];
                    if (withdrawals.isEmpty) {
                      return Center(child: Text(AppStrings.noWithdrawalRecordsFound));
                    }
                    return ListView.separated(
                      itemCount: withdrawals.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final w = withdrawals[i];
                        return ListTile(
                          leading: const Icon(Icons.account_balance, color: AppColors.secondary),
                          title: Text(
                            '${w.type} ${AppStrings.withdrawalByAdmin} (${w.adminName})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${AppFormatters.formatDate(w.createdAt)} ${AppFormatters.formatTime(w.createdAt)} • ${w.status}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            AppFormatters.formatCurrency(w.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        return StreamBuilder<ShiftModel?>(
          stream: _shiftService.watchGuardCurrentActiveShift(
            widget.currentGuard.uid,
            widget.currentGuard.email,
            widget.currentGuard.name,
          ),
          builder: (context, activeShiftSnap) {
            final activeShift = activeShiftSnap.data;
            final dynamicShiftName = activeShift?.displayShiftName;

            return StreamBuilder<List<HandoverModel>>(
              stream: _financialService.watchPendingHandoversForGuard(widget.currentGuard.uid),
              builder: (context, handoverSnap) {
                final pendingHandovers = (handoverSnap.data ?? [])
                    .where((h) => h.isPending && h.toGuardId.trim() == widget.currentGuard.uid.trim())
                    .toList();
                final hasPendingHandover = pendingHandovers.isNotEmpty;

                return Stack(
                  children: [
                    Scaffold(
                      backgroundColor: AppColors.background,
                      appBar: GuardAppBar(
                        guardUid: widget.currentGuard.uid,
                        guardName: widget.currentGuard.name,
                        shiftName: dynamicShiftName,
                        onProfileTap: _showProfileModal,
                    actions: [
                      StreamBuilder<int>(
                        stream: _notificationService.watchUnreadCount(widget.currentGuard.uid),
                        builder: (context, notifSnap) {
                          final unread = notifSnap.data ?? 0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined),
                                color: AppColors.textSecondary,
                                tooltip: AppStrings.notifications,
                                onPressed: () => NotificationDialog.show(context, userId: widget.currentGuard.uid),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.language),
                        color: AppColors.textSecondary,
                        tooltip: AppStrings.settings,
                        onPressed: () => LanguageSettingsDialog.show(context),
                      ),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.print_outlined),
                          color: AppColors.textSecondary,
                          tooltip: AppStrings.bluetoothPrinter,
                          onPressed: () => BluetoothPrinterDialog.show(context),
                        ),
                      IconButton(
                        icon: const Icon(Icons.account_circle_outlined),
                        color: AppColors.textSecondary,
                        tooltip: AppStrings.guardProfile,
                        onPressed: _showProfileModal,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          GuardDashboardScreen(
                            currentGuard: widget.currentGuard,
                            onNavigateTab: _onNavTap,
                          ),
                          VehicleEntryScreen(
                            currentGuard: widget.currentGuard,
                            onReturnDashboard: () => _onNavTap(0),
                            onViewActiveParking: () => _onNavTap(2),
                          ),
                          ActiveParkingScreen(
                            onNewEntryTap: () => _onNavTap(1),
                          ),
                          VehicleExitSearchScreen(
                            currentGuard: widget.currentGuard,
                            onReturnDashboard: () => _onNavTap(0),
                          ),
                          GuardMyShiftScreen(
                            currentGuard: widget.currentGuard,
                            onReturnDashboard: () => _onNavTap(0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  bottomNavigationBar: Center(
                    heightFactor: 1.0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: GuardBottomNav(
                        currentIndex: _currentIndex,
                        onTap: _onNavTap,
                      ),
                    ),
                  ),
                ),
                if (hasPendingHandover) ...[
                  const ModalBarrier(
                    key: ValueKey('mandatory_handover_barrier'),
                    dismissible: false,
                    color: Colors.black54,
                  ),
                  MandatoryHandoverPopup(
                    handover: pendingHandovers.first,
                    currentGuard: widget.currentGuard,
                    financialService: _financialService,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  },
);
}
}
