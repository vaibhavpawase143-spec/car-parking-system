import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:car_parking_system/screens/admin/guards/admin_guard_management_screen.dart';
import 'package:car_parking_system/screens/admin/payments/admin_payment_management_screen.dart';
import 'package:car_parking_system/screens/admin/reports/admin_reports_hub_screen.dart';
import 'package:car_parking_system/screens/admin/settings/admin_settings_screen.dart';
import 'package:car_parking_system/screens/admin/shifts/admin_shift_management_screen.dart';

void main() {
  final testAdmin = GuardModel(
    uid: 'admin_test_123',
    name: 'Super Admin',
    email: 'admin@jayganesh.com',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
    createdAt: DateTime.now(),
  );

  Widget createDashboardApp({Function(int)? onNavigate}) {
    return MaterialApp(
      home: Scaffold(
        body: AdminDashboardScreen(
          currentAdmin: testAdmin,
          onNavigateTab: onNavigate,
        ),
      ),
    );
  }

  group('Final Admin Dashboard Scope Fix Tests', () {
    testWidgets('1. Dashboard header renders with admin profile and portal title', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Super Admin'), findsWidgets);
      expect(find.textContaining(AppStrings.adminPortalTitle), findsWidgets);
      expect(find.byIcon(Icons.admin_panel_settings), findsWidgets);
    });

    testWidgets('2. Guard Statistics renders with all 6 operational metric cards', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.totalGuards), findsOneWidget);
      expect(find.text(AppStrings.activeGuards), findsOneWidget);
      expect(find.text(AppStrings.inactiveGuards), findsOneWidget);
      expect(find.text(AppStrings.currentlyOnShift), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text(AppStrings.guardsWithNoShift), findsOneWidget);
    });

    testWidgets('3. Parking Capacity renders with 4W, 2W, Occupied, Available, Total, and Edit Capacity', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.parkingCapacity), findsOneWidget);
      expect(find.text(AppStrings.fourWheeler), findsOneWidget);
      expect(find.text(AppStrings.twoWheeler), findsOneWidget);
      expect(find.text(AppStrings.totalCapacity), findsOneWidget);
      expect(find.text(AppStrings.totalOccupied), findsOneWidget);
      expect(find.text(AppStrings.totalAvailable), findsOneWidget);
      expect(find.byKey(const ValueKey('admin_edit_capacity_button')), findsOneWidget);
    });

    testWidgets('4. Today\'s Operations renders with all 5 financial & activity metrics', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.todaysOperations), findsOneWidget);
      expect(find.text(AppStrings.todayTotalCollection), findsOneWidget);
      expect(find.text(AppStrings.cashCollection), findsOneWidget);
      expect(find.text(AppStrings.upiCollection), findsOneWidget);
      expect(find.text(AppStrings.todayEntries), findsOneWidget);
      expect(find.text(AppStrings.todayExits), findsOneWidget);
    });

    testWidgets('5. Dashboard ends immediately after Today\'s Operations - NO lower sections rendered', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Financial Responsibility is NOT rendered
      expect(find.text(AppStrings.financialResponsibility), findsNothing);
      expect(find.text(AppStrings.cashOutstanding), findsNothing);
      expect(find.text(AppStrings.upiOutstanding), findsNothing);

      // 7. Shift Overview is NOT rendered
      expect(find.text(AppStrings.shiftOverview), findsNothing);
      expect(find.text(AppStrings.viewShiftManagement), findsNothing);

      // 8. Handover & Withdrawal Activity is NOT rendered
      expect(find.text(AppStrings.handoverWithdrawalActivity), findsNothing);
      expect(find.text(AppStrings.pendingHandovers), findsNothing);
      expect(find.text(AppStrings.pendingWithdrawals), findsNothing);

      // 9. Recent Parking Activity is NOT rendered
      expect(find.text(AppStrings.recentActivity), findsNothing);
      expect(find.text(AppStrings.noRecentActivity), findsNothing);
      expect(find.text(AppStrings.viewAllActive), findsNothing);

      // 10. Notifications section & Quick Navigation are NOT rendered
      expect(find.text(AppStrings.recentNotifications), findsNothing);
      expect(find.text(AppStrings.quickNavigation), findsNothing);
    });

    testWidgets('11. Edit Capacity still opens dialog, validates input, and auto-calculates total', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final editBtn = find.byKey(const ValueKey('admin_edit_capacity_button'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Dialog content
      expect(find.byKey(const ValueKey('dialog_four_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_two_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_save_capacity_button')), findsOneWidget);
      expect(find.text(AppStrings.cancel), findsOneWidget);

      // Enter numbers and verify auto total
      await tester.enterText(find.byKey(const ValueKey('dialog_four_wheeler_capacity_input')), '120');
      await tester.enterText(find.byKey(const ValueKey('dialog_two_wheeler_capacity_input')), '180');
      await tester.pump();

      expect(find.text('300'), findsOneWidget); // 120 + 180 = 300

      // Cancel dialog closes properly
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dialog_save_capacity_button')), findsNothing);
    });

    testWidgets('12. Dashboard data streams remain functional and update state properly', (tester) async {
      await tester.pumpWidget(createDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Refresh button triggers reload of streams without crashing
      final refreshBtn = find.byIcon(Icons.refresh);
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.parkingCapacity), findsOneWidget);
      expect(find.text(AppStrings.todaysOperations), findsOneWidget);
    });

    testWidgets('13. Other Admin pages remain accessible and intact', (tester) async {
      // Guard Management
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminGuardManagementScreen), findsOneWidget);

      // Shift Management
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminShiftManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminShiftManagementScreen), findsOneWidget);

      // Payment Management
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPaymentManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminPaymentManagementScreen), findsOneWidget);

      // Reports Hub
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminReportsHubScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminReportsHubScreen), findsOneWidget);

      // Settings
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminSettingsScreen), findsOneWidget);
    });
  });
}
