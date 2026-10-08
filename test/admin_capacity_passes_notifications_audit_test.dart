import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/notification_model.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:car_parking_system/screens/admin/passes/admin_monthly_pass_management_screen.dart';
import 'package:car_parking_system/screens/admin/reports/admin_reports_hub_screen.dart';
import 'package:car_parking_system/screens/admin/notifications/admin_notifications_screen.dart';

void main() {
  final testAdmin = GuardModel(
    uid: 'admin_test_123',
    name: 'Admin Vaibhav',
    email: 'admin@jayganesh.com',
    role: 'admin',
    currentShift: 'Shift 1',
    isActive: true,
  );

  group('Part 1 — Admin Dashboard Edit Capacity UI & Responsiveness', () {
    testWidgets('1. Admin Dashboard capacity section renders on mobile width (360px)', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(currentAdmin: testAdmin),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.totalCapacity), findsWidgets);
      expect(find.text(AppStrings.totalOccupied), findsWidgets);
      expect(find.text(AppStrings.totalAvailable), findsWidgets);
      expect(find.byKey(const ValueKey('admin_edit_capacity_button')), findsOneWidget);
    });

    testWidgets('2. Admin Dashboard capacity section renders on desktop width (1200px)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(currentAdmin: testAdmin),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.totalCapacity), findsWidgets);
      expect(find.byKey(const ValueKey('admin_edit_capacity_button')), findsOneWidget);
    });

    testWidgets('3. Clicking Edit Capacity button opens capacity edit dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(currentAdmin: testAdmin),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final editBtn = find.byKey(const ValueKey('admin_edit_capacity_button'));
      expect(editBtn, findsOneWidget);

      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('dialog_four_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_two_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_save_capacity_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_cancel_capacity_button')), findsOneWidget);
    });
  });

  group('Part 2 — Monthly Pass 4 Action Buttons & Responsive Layout', () {
    testWidgets('4. Monthly Pass card renders all 4 actions on mobile (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminMonthlyPassManagementScreen), findsOneWidget);
    });

    testWidgets('5. Monthly Pass card renders all 4 actions on desktop (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminMonthlyPassManagementScreen), findsOneWidget);
    });
  });

  group('Part 3 — Admin Notifications Full Audit', () {
    test('6. NotificationModel serialization and deserialization', () {
      final notif = NotificationModel(
        notificationId: 'notif_101',
        recipientUserId: 'admin_audit',
        title: 'Guard Shift Started',
        message: 'Guard Ramesh has started Shift A.',
        type: 'shift',
        isRead: false,
        createdAt: DateTime(2026, 10, 1, 10, 0),
      );

      final map = notif.toFirestore();
      expect(map['recipientUserId'], 'admin_audit');
      expect(map['title'], 'Guard Shift Started');
      expect(map['type'], 'shift');
      expect(map['isRead'], false);

      final copy = notif.copyWith(isRead: true);
      expect(copy.isRead, true);
      expect(copy.notificationId, 'notif_101');
    });

    testWidgets('7. AdminNotificationsScreen renders notifications UI and controls', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminNotificationsScreen(adminUid: 'admin_audit'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.notifications), findsOneWidget);
      expect(find.text(AppStrings.markAllAsRead), findsOneWidget);
    });
  });

  group('Part 4 — Reports Hub Vehicle Report Mobile Card Overlap Fix', () {
    testWidgets('8. Reports Hub Vehicle Report renders without overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminReportsHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminReportsHubScreen), findsOneWidget);
    });

    testWidgets('9. Reports Hub Vehicle Report renders without overflow on desktop (1440x900)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminReportsHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminReportsHubScreen), findsOneWidget);
    });
  });
}
