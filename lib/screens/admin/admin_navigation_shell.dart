import 'package:flutter/material.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_language_controller.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/guard_model.dart';
import '../../services/guard_auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/settings/language_settings_dialog.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'guards/admin_guard_management_screen.dart';
import 'notifications/admin_notifications_screen.dart';
import 'payments/admin_payment_management_screen.dart';
import 'passes/admin_monthly_pass_management_screen.dart';
import 'reports/admin_reports_hub_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'shifts/admin_shift_management_screen.dart';

/// AdminNavigationShell provides the responsive root scaffold and navigation
/// for the Admin Portal (Sidebar on desktop/tablet, Bottom nav on mobile).
class AdminNavigationShell extends StatefulWidget {
  final GuardModel currentAdmin;

  const AdminNavigationShell({
    super.key,
    required this.currentAdmin,
  });

  @override
  State<AdminNavigationShell> createState() => _AdminNavigationShellState();
}

class _AdminNavigationShellState extends State<AdminNavigationShell> {
  int _currentIndex = 0;
  final _notificationService = NotificationService();
  final _guardAuthService = GuardAuthService();
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = _notificationService.watchUnreadCount(widget.currentAdmin.uid);
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  int _getMobileNavSelectedIndex() {
    switch (_currentIndex) {
      case 0:
        return 0; // Dashboard
      case 1:
        return 1; // Guards
      case 3:
        return 2; // Collection
      case 5:
        return 3; // Passes
      case 2: // Shift
      case 4: // Reports
      case 6: // Settings
        return 4; // More
      default:
        return 0;
    }
  }

  void _onMobileNavTap(int mobileIndex) {
    switch (mobileIndex) {
      case 0:
        _onNavTap(0);
        break;
      case 1:
        _onNavTap(1);
        break;
      case 2:
        _onNavTap(3);
        break;
      case 3:
        _onNavTap(5);
        break;
      case 4:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMoreBottomSheet();
        });
        break;
    }
  }

  void _showMoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isMarathi = AppLanguageController.instance.currentLanguage == AppLanguage.marathi;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.moreOptions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                    title: Text(AppStrings.shiftManagement, style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: _currentIndex == 2,
                    selectedColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onNavTap(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_outlined, color: AppColors.primary),
                    title: Text(AppStrings.reportsHub, style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: _currentIndex == 4,
                    selectedColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onNavTap(4);
                    },
                  ),
                  StreamBuilder<int>(
                    stream: _unreadStream,
                    initialData: 0,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return ListTile(
                        leading: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count', style: const TextStyle(fontSize: 10)),
                          child: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                        ),
                        title: Text(AppStrings.notifications, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: count > 0
                            ? StatusBadge(label: '$count NEW', type: BadgeType.warning)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminNotificationsScreen(adminUid: widget.currentAdmin.uid),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_circle_outlined, color: AppColors.primary),
                    title: Text(AppStrings.profile, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(widget.currentAdmin.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAdminProfileModal();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.language, color: AppColors.primary),
                    title: Text(AppStrings.language, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      isMarathi ? 'मराठी' : 'English',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      LanguageSettingsDialog.show(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                    title: Text(AppStrings.adminSettings, style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: _currentIndex == 6,
                    selectedColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onNavTap(6);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.confirmSignOut),
        content: Text(AppStrings.adminSignOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.signOut, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _guardAuthService.signOut();
    }
  }

  void _showAdminProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  child: const Icon(Icons.admin_panel_settings, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.currentAdmin.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentAdmin.email,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const StatusBadge(label: 'ADMIN', type: BadgeType.active),
                const SizedBox(height: 24),
                AppButton(
                  label: AppStrings.signOut,
                  type: AppButtonType.danger,
                  icon: Icons.logout,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleLogout();
                  },
                ),
              ],
            ),
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            Widget buildCurrentScreen() {
              debugPrint('[ADMIN_NAV] selectedIndex = $_currentIndex building screen for tab $_currentIndex (isDesktop=$isDesktop, constraints=${constraints.maxWidth}x${constraints.maxHeight})');
              switch (_currentIndex) {
                case 0:
                  debugPrint('[ADMIN_NAV] selectedIndex = 0 building AdminDashboardScreen');
                  return AdminDashboardScreen(
                    key: const ValueKey('admin_dashboard_screen'),
                    currentAdmin: widget.currentAdmin,
                    onNavigateTab: _onNavTap,
                  );
                case 1:
                  return AdminGuardManagementScreen(
                    key: const ValueKey('admin_guard_management_screen'),
                    onNavigateToShift: () => _onNavTap(2),
                  );
                case 2:
                  return const AdminShiftManagementScreen(
                    key: ValueKey('admin_shift_management_screen'),
                  );
                case 3:
                  return const AdminPaymentManagementScreen(
                    key: ValueKey('admin_payment_management_screen'),
                  );
                case 4:
                  return const AdminReportsHubScreen(
                    key: ValueKey('admin_reports_hub_screen'),
                  );
                case 5:
                  return AdminMonthlyPassManagementScreen(
                    key: const ValueKey('admin_monthly_pass_management_screen'),
                    currentAdmin: widget.currentAdmin,
                  );
                case 6:
                  return const AdminSettingsScreen(
                    key: ValueKey('admin_settings_screen'),
                  );
                default:
                  return AdminDashboardScreen(
                    key: const ValueKey('admin_dashboard_screen_default'),
                    currentAdmin: widget.currentAdmin,
                    onNavigateTab: _onNavTap,
                  );
              }
            }

            if (isDesktop) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Row(
                  children: [
                    // Desktop Left Sidebar
                    _buildDesktopSidebar(),

                    // Main Content
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopAppBar(isDesktop: true),
                          Expanded(
                            child: buildCurrentScreen(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile / Tablet Viewport
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: _buildTopAppBar(isDesktop: false),
              body: buildCurrentScreen(),
              bottomNavigationBar: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                    (Set<WidgetState> states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _getMobileNavSelectedIndex(),
                  onDestinationSelected: _onMobileNavTap,
                  backgroundColor: AppColors.surface,
                  height: 65,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: const Icon(Icons.dashboard, color: AppColors.primaryOrange),
                      label: AppStrings.dashboard,
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.people_outline),
                      selectedIcon: const Icon(Icons.people, color: AppColors.primaryOrange),
                      label: AppStrings.guards,
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: const Icon(Icons.account_balance_wallet, color: AppColors.primaryOrange),
                      label: AppStrings.collection,
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.credit_card_outlined),
                      selectedIcon: const Icon(Icons.credit_card, color: AppColors.primaryOrange),
                      label: AppStrings.passes,
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.more_horiz_outlined),
                      selectedIcon: const Icon(Icons.more_horiz, color: AppColors.primaryOrange),
                      label: AppStrings.more,
                      tooltip: '',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildTopAppBar({required bool isDesktop}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (!isDesktop) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_parking, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              AppStrings.companyBrand,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                            SizedBox(width: 6),
                            Text(
                              AppStrings.adminPortal,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  _getTitleForTab(_currentIndex),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const Spacer(),
              ],

              // Notifications Icon with badge
              StreamBuilder<int>(
                stream: _unreadStream,
                initialData: 0,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: count > 0,
                      backgroundColor: AppColors.primaryOrange,
                      label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminNotificationsScreen(adminUid: widget.currentAdmin.uid),
                        ),
                      );
                    },
                  );
                },
              ),

              // Language Switcher
              IconButton(
                icon: const Icon(Icons.language, color: AppColors.textSecondary),
                onPressed: () => LanguageSettingsDialog.show(context),
              ),

              // Profile Avatar
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
                onPressed: _showAdminProfileModal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
      ),
      child: Column(
        children: [
          // Header Branding
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_parking, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        AppStrings.companyBrand,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryOrange, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          AppStrings.adminPortal,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Sidebar Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSidebarItem(0, Icons.dashboard_outlined, Icons.dashboard, AppStrings.dashboard),
                _buildSidebarItem(1, Icons.people_outline, Icons.people, AppStrings.guardManagement),
                _buildSidebarItem(2, Icons.calendar_month_outlined, Icons.calendar_month, AppStrings.shiftManagement),
                _buildSidebarItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, AppStrings.paymentManagement),
                _buildSidebarItem(4, Icons.bar_chart_outlined, Icons.bar_chart, AppStrings.reportsHub),
                _buildSidebarItem(5, Icons.credit_card_outlined, Icons.credit_card, AppStrings.monthlyPassManagement),
                _buildSidebarItem(6, Icons.settings_outlined, Icons.settings, AppStrings.adminSettings),
              ],
            ),
          ),

          // User Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                  child: const Icon(Icons.admin_panel_settings, size: 20, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentAdmin.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.currentAdmin.email,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData unselectedIcon, IconData selectedIcon, String title) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onNavTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  size: 20,
                  color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryOrange : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitleForTab(int index) {
    switch (index) {
      case 0:
        return AppStrings.adminDashboard;
      case 1:
        return AppStrings.guardManagement;
      case 2:
        return AppStrings.shiftManagement;
      case 3:
        return AppStrings.paymentManagement;
      case 4:
        return AppStrings.reportsHub;
      case 5:
        return AppStrings.monthlyPassManagement;
      case 6:
        return AppStrings.adminSettings;
      default:
        return AppStrings.appName;
    }
  }
}
