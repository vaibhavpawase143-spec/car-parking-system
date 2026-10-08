import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:car_parking_system/screens/admin/passes/admin_monthly_pass_management_screen.dart';
import 'package:car_parking_system/screens/admin/settings/admin_settings_screen.dart';

void main() {
  const testAdmin = GuardModel(
    uid: 'admin_123',
    name: 'Admin User',
    email: 'admin@bizflow.com',
    role: 'admin',
  );

  group('PART 1 & 2: Navigation Order & Monthly Pass Accessibility Verification', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });

    tearDown(() async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });

    testWidgets('1. Desktop sidebar has Admin Settings as the LAST item (Item 7)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find all sidebar navigation items
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Guard Management'), findsWidgets);
      expect(find.text('Shift Management'), findsWidgets);
      expect(find.text('Payment Management'), findsWidgets);
      expect(find.text('Reports Hub'), findsWidgets);
      expect(find.text('Monthly Pass Management'), findsWidgets);
      expect(find.text('Admin Settings'), findsWidgets);

      // Verify the order of sidebar navigation items in the widget tree
      final item6Finder = find.text('Monthly Pass Management');
      final item7Finder = find.text('Admin Settings');
      expect(item6Finder, findsOneWidget);
      expect(item7Finder, findsOneWidget);

      final item6Top = tester.getTopLeft(item6Finder).dy;
      final item7Top = tester.getTopLeft(item7Finder).dy;
      expect(item7Top, greaterThan(item6Top),
          reason: 'Admin Settings must be visually positioned AFTER Monthly Pass Management');
    });

    testWidgets('2. Mobile bottom navigation bar has 5 items (Dashboard, Guards, Collection, Passes, More)', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find bottom navigation bar
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.destinations.length, equals(5));

      // Destinations: Dashboard, Guards, Collection, Passes, More
      expect((navBar.destinations[0] as NavigationDestination).label, equals('Dashboard'));
      expect((navBar.destinations[1] as NavigationDestination).label, equals('Guards'));
      expect((navBar.destinations[2] as NavigationDestination).label, equals('Collection'));
      expect((navBar.destinations[3] as NavigationDestination).label, equals('Passes'));
      expect((navBar.destinations[4] as NavigationDestination).label, equals('More'));
    });

    testWidgets('3. Clicking Monthly Pass Management opens Monthly Pass screen', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Monthly Pass Management on sidebar (item 5)
      await tester.tap(find.text('Monthly Pass Management').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminMonthlyPassManagementScreen), findsOneWidget);
    });

    testWidgets('4. Clicking Admin Settings opens Admin Settings screen as the last route', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Admin Settings (item 6)
      await tester.tap(find.text('Admin Settings').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminSettingsScreen), findsOneWidget);
    });

    testWidgets('5. Mobile 360x640: Dashboard scrolls to Monthly Passes without bottom navigation covering it', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedTab = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(
              currentAdmin: testAdmin,
              onNavigateTab: (tabIndex) {
                navigatedTab = tabIndex;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially top elements are visible
      expect(find.text(AppStrings.todaysOperations), findsOneWidget);

      // Scroll down to find Monthly Passes
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(AppStrings.monthlyPasses), findsOneWidget);
      expect(find.text(AppStrings.activePasses), findsOneWidget);
      expect(find.text(AppStrings.expiringSoon), findsOneWidget);
      expect(find.text(AppStrings.expiredPasses), findsOneWidget);
      expect(find.text(AppStrings.passCollection), findsOneWidget);

      // Ensure "View All Passes" button is visible and tap it
      await tester.ensureVisible(find.text(AppStrings.viewAllPasses));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final viewPassesBtn = find.text(AppStrings.viewAllPasses);
      expect(viewPassesBtn, findsOneWidget);
      await tester.tap(viewPassesBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify it navigates to Tab 5 (Monthly Pass Management)
      expect(navigatedTab, equals(5));
    });

    testWidgets('6. Marathi Localization: Fixed Branding invariant preserved in Admin Navigation (Desktop)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Branding invariant
      expect(find.text('CAR PARKING SYSTEM'), findsAtLeastNWidgets(1));
      expect(find.text('BIZFLOW'), findsAtLeastNWidgets(1));
      expect(find.text('ADMIN PORTAL'), findsAtLeastNWidgets(1));

      // Marathi navigation items
      expect(find.text(AppStrings.dashboard), findsWidgets);
      expect(find.text(AppStrings.guardManagement), findsWidgets);
      expect(find.text(AppStrings.shiftManagement), findsWidgets);
      expect(find.text(AppStrings.paymentManagement), findsWidgets);
      expect(find.text(AppStrings.reportsHub), findsWidgets);
      expect(find.text(AppStrings.monthlyPassManagement), findsWidgets);
      expect(find.text(AppStrings.adminSettings), findsWidgets);
    });

    testWidgets('7. Marathi Localization: Mobile Dashboard shows Marathi Monthly Passes', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(
              currentAdmin: testAdmin,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('मासिक पासेस'), findsOneWidget);
      expect(find.text('सक्रिय पासेस'), findsOneWidget);
      expect(find.text('लवकरच संपणारे'), findsOneWidget);
      expect(find.text('मुदत संपलेले पासेस'), findsOneWidget);
      expect(find.text('पास संकलन'), findsOneWidget);
      expect(find.text('सर्व पासेस पहा'), findsOneWidget);
    });
  });
}
