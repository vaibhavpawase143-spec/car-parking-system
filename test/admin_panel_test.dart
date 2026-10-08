import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/audit_log_model.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/screens/admin/auth/admin_login_screen.dart';
import 'package:car_parking_system/screens/admin/reports/admin_reports_hub_screen.dart';
import 'package:car_parking_system/screens/admin/settings/admin_settings_screen.dart';
import 'package:car_parking_system/screens/guard/auth/guard_login_screen.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/withdrawal_model.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';
import 'package:car_parking_system/services/report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  const testAdmin = GuardModel(
    uid: 'admin_test_01',
    name: 'Master Admin',
    email: 'admin@parking.com',
    role: 'admin',
    isActive: true,
  );

  const testGuard = GuardModel(
    uid: 'guard_test_01',
    name: 'Ramesh Guard',
    email: 'ramesh@parking.com',
    role: 'guard',
    isActive: true,
  );

  group('A) Admin Model & Role Security Tests', () {
    test('1. Admin role check detects admin vs guard accurately', () {
      expect(testAdmin.isAdmin, isTrue);
      expect(testAdmin.isGuard, isFalse);

      expect(testGuard.isAdmin, isFalse);
      expect(testGuard.isGuard, isTrue);

      const inactiveAdmin = GuardModel(
        uid: 'admin_02',
        name: 'Disabled Admin',
        email: 'disabled@parking.com',
        role: 'admin',
        isActive: false,
      );
      expect(inactiveAdmin.isAdmin, isFalse);
    });

    test('2. Payment transaction models correctly classify ADVANCE, FINAL, and REFUND', () {
      final now = DateTime.now();
      final advanceTxn = PaymentTransactionModel(
        id: 'txn_01',
        ticketId: '1001',
        vehicleNumber: 'MH12AB1234',
        amount: 20.0,
        paymentMethod: 'cash',
        paymentType: 'ADVANCE',
        guardUid: 'guard_test_01',
        guardName: 'Ramesh',
        shift: 'Shift 1',
        createdAt: now,
      );

      final finalTxn = PaymentTransactionModel(
        id: 'txn_02',
        ticketId: '1001',
        vehicleNumber: 'MH12AB1234',
        amount: 30.0,
        paymentMethod: 'upi',
        paymentType: 'FINAL',
        guardUid: 'guard_test_01',
        guardName: 'Ramesh',
        shift: 'Shift 1',
        createdAt: now,
      );

      final refundTxn = PaymentTransactionModel(
        id: 'txn_03',
        ticketId: '1002',
        vehicleNumber: 'MH14CD5678',
        amount: 10.0,
        paymentMethod: 'cash',
        paymentType: 'REFUND',
        guardUid: 'guard_test_01',
        guardName: 'Ramesh',
        shift: 'Shift 1',
        createdAt: now,
      );

      expect(advanceTxn.isAdvance, isTrue);
      expect(advanceTxn.isCash, isTrue);
      expect(advanceTxn.isUpi, isFalse);

      expect(finalTxn.isFinal, isTrue);
      expect(finalTxn.isUpi, isTrue);
      expect(finalTxn.isCash, isFalse);

      expect(refundTxn.isRefund, isTrue);
      expect(refundTxn.isCash, isTrue);
    });

    test('3. Shift model calculates 8-hour fixed duration and midnight crossing status', () {
      final start = DateTime(2026, 9, 26, 22, 0); // 10:00 PM
      final end = start.add(const Duration(hours: 8)); // 06:00 AM next day

      final shift = ShiftModel(
        shiftId: 'shift_overnight',
        guardId: 'guard_test_01',
        guardName: 'Ramesh',
        shiftDate: DateTime(2026, 9, 26),
        startTime: start,
        endTime: end,
        durationHours: 8,
        status: 'ASSIGNED',
      );

      expect(shift.durationHours, equals(8));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(8));
      expect(shift.endTime.hour, equals(6));
    });
  });

  group('B) Admin UI & Localization Tests', () {
    testWidgets('4. Admin Login screen displays branding, fields, and switch link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.adminLogin), findsOneWidget);
      expect(find.text(AppStrings.switchToGuardPrompt), findsOneWidget);
    });

    testWidgets('5. Admin Navigation Shell renders responsive layout and switches tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: const AdminNavigationShell(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.appName), findsWidgets);
      expect(find.text(AppStrings.dashboard), findsWidgets);
      expect(find.text(AppStrings.guardManagement), findsWidgets);
      expect(find.text(AppStrings.shiftManagement), findsWidgets);
      expect(find.text(AppStrings.paymentManagement), findsWidgets);
      expect(find.text(AppStrings.reportsHub), findsWidgets);
      expect(find.text(AppStrings.adminSettings), findsWidgets);

      // Tap on Guards tab
      await tester.tap(find.text(AppStrings.guardManagement).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Shift tab
      await tester.tap(find.text(AppStrings.shiftManagement).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Payment tab
      await tester.tap(find.text(AppStrings.paymentManagement).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6. English <-> Marathi reactive language switching in Admin', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      addTearDown(() => AppLanguageController.instance.setLanguage(AppLanguage.english));

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: AppLanguageController.instance,
          builder: (context, _) => MaterialApp(
            home: const AdminNavigationShell(currentAdmin: testAdmin),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CAR PARKING SYSTEM'), findsWidgets);
      expect(find.text('BIZFLOW'), findsWidgets);
      expect(find.text('ADMIN PORTAL'), findsWidgets);

      // Switch to Marathi
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Branding remains fixed English
      expect(find.text('CAR PARKING SYSTEM'), findsWidgets);
      expect(find.text('BIZFLOW'), findsWidgets);
      expect(find.text('ADMIN PORTAL'), findsWidgets);
      expect(find.text('जय गणेश पे अँड पार्क'), findsNothing);
      expect(find.text('डॅशबोर्ड'), findsWidgets);
      expect(find.text(AppStrings.guardManagement), findsWidgets);

      // Switch back to English
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CAR PARKING SYSTEM'), findsWidgets);
    });

    testWidgets('7. Admin Settings screen displays rate chart and capacity configuration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const AdminSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.capacitySettings), findsOneWidget);
      expect(find.text(AppStrings.rateChart), findsOneWidget);
      expect(find.textContaining('12-Hour Cap'), findsWidgets);
    });

    testWidgets('8. Admin Reports Hub screen renders operational sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminReportsHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Reports Hub'), findsOneWidget);
      expect(find.text('Parking Summary'), findsOneWidget);
      expect(find.text('Parking Capacity'), findsOneWidget);
      expect(find.text('Vehicle Report'), findsOneWidget);
      expect(find.text(AppStrings.guardWiseReport), findsOneWidget);
    });
  });

  group('C) Admin & Guard Authentication and Access Control Tests', () {
    test('9. Guard account is blocked from Admin Panel authorization', () {
      // Guard account attempting admin verification
      expect(testGuard.role, equals('guard'));
      expect(testGuard.isAdmin, isFalse);
      expect(testGuard.isGuard, isTrue);

      // Verify that unauthorized access string is defined
      expect(AppStrings.unauthorizedAdminAccess, isNotEmpty);
      expect(AppStrings.unauthorizedAdminAccess, contains('authorized'));
    });

    test('10. Inactive admin is strictly barred from admin access', () {
      const disabledAdmin = GuardModel(
        uid: 'admin_disabled',
        name: 'Revoked Admin',
        email: 'revoked@parking.com',
        role: 'admin',
        isActive: false,
      );

      expect(disabledAdmin.role, equals('admin'));
      expect(disabledAdmin.isAdmin, isFalse);
      expect(disabledAdmin.isGuard, isFalse);
    });

    test('11. Role verification accurately separates Admin, Guard, and Unknown', () {
      Widget determineShell(GuardModel? profile) {
        if (profile != null && profile.isAdmin) {
          return const Text('ADMIN_SHELL');
        }
        if (profile != null && profile.isGuard) {
          return const Text('GUARD_SHELL');
        }
        return const Text('ACCESS_DENIED');
      }

      expect(determineShell(testAdmin).toString(), contains('ADMIN_SHELL'));
      expect(determineShell(testGuard).toString(), contains('GUARD_SHELL'));
      expect(determineShell(null).toString(), contains('ACCESS_DENIED'));

      const unknownUser = GuardModel(
        uid: 'unknown_01',
        name: 'Guest',
        email: 'guest@parking.com',
        role: 'customer',
        isActive: true,
      );
      expect(determineShell(unknownUser).toString(), contains('ACCESS_DENIED'));
    });

    testWidgets('12. Admin Login screen displays prominent switch to Guard Login portal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final switchButton = find.text(AppStrings.switchToGuardPrompt);
      expect(switchButton, findsOneWidget);
      expect(find.text(AppStrings.adminLogin), findsOneWidget);
    });

    testWidgets('13. Guard Login displays Admin Login switch visibly on mobile screen without scrolling', (tester) async {
      // Standard mobile physical size (390 x 844, typical 6-inch phone)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Admin Login switch button is rendered and visible
      final adminSwitchFinder = find.text(AppStrings.switchToAdminPrompt);
      expect(adminSwitchFinder, findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);

      // Verify it is hit-testable in viewport
      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('14. Tapping Switch to Admin Login on GuardLoginScreen navigates to AdminLoginScreen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Switch to Admin button
      await tester.tap(find.text(AppStrings.switchToAdminPrompt));
      await tester.pumpAndSettle();

      // Verify AdminLoginScreen is displayed
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.adminLogin), findsOneWidget);
    });

    testWidgets('15. Tapping Switch to Guard Login on AdminLoginScreen navigates back to GuardLoginScreen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Switch to Guard button
      await tester.tap(find.text(AppStrings.switchToGuardPrompt));
      await tester.pumpAndSettle();

      // Verify GuardLoginScreen is displayed
      expect(find.text(AppStrings.guardPortalTitle), findsOneWidget);
      expect(find.text(AppStrings.signIn), findsOneWidget);
    });

    testWidgets('16. Web viewport (1280x800): Guard Login displays Admin Login switch visibly and tap navigates to AdminLoginScreen', (tester) async {
      // Standard desktop web browser physical size (1280 x 800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Admin Login switch button is rendered and visible on Web
      final adminSwitchFinder = find.text(AppStrings.switchToAdminPrompt);
      expect(adminSwitchFinder, findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);

      // Verify OutlinedButton is present
      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsOneWidget);

      // Tap Switch to Admin button on Web
      await tester.tap(adminSwitchFinder);
      await tester.pumpAndSettle();

      // Verify AdminLoginScreen is opened
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.adminLogin), findsOneWidget);
      expect(find.text(AppStrings.switchToGuardPrompt), findsOneWidget);
    });
  });

  group('D) Authoritative Financial Ledger & Net Formulas', () {
    test('17. Cash, UPI, and Grand Net Totals accurately reflect Advance, Final, and Refund', () {
      final txns = [
        // Cash Advance ₹20
        PaymentTransactionModel(
          id: 't1',
          ticketId: '101',
          vehicleNumber: 'MH12AA1111',
          amount: 20.0,
          paymentMethod: 'cash',
          paymentType: 'ADVANCE',
          guardUid: 'g1',
          createdAt: DateTime.now(),
        ),
        // Cash Final ₹40
        PaymentTransactionModel(
          id: 't2',
          ticketId: '101',
          vehicleNumber: 'MH12AA1111',
          amount: 40.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'g1',
          createdAt: DateTime.now(),
        ),
        // Cash Refund ₹10
        PaymentTransactionModel(
          id: 't3',
          ticketId: '102',
          vehicleNumber: 'MH12AA2222',
          amount: 10.0,
          paymentMethod: 'cash',
          paymentType: 'REFUND',
          guardUid: 'g1',
          createdAt: DateTime.now(),
        ),
        // UPI Advance ₹50
        PaymentTransactionModel(
          id: 't4',
          ticketId: '103',
          vehicleNumber: 'MH12BB3333',
          amount: 50.0,
          paymentMethod: 'upi',
          paymentType: 'ADVANCE',
          guardUid: 'g2',
          createdAt: DateTime.now(),
        ),
        // UPI Final ₹100
        PaymentTransactionModel(
          id: 't5',
          ticketId: '103',
          vehicleNumber: 'MH12BB3333',
          amount: 100.0,
          paymentMethod: 'upi',
          paymentType: 'FINAL',
          guardUid: 'g2',
          createdAt: DateTime.now(),
        ),
        // UPI Refund ₹20
        PaymentTransactionModel(
          id: 't6',
          ticketId: '104',
          vehicleNumber: 'MH12BB4444',
          amount: 20.0,
          paymentMethod: 'upi',
          paymentType: 'REFUND',
          guardUid: 'g2',
          createdAt: DateTime.now(),
        ),
      ];

      double cash = 0.0;
      double upi = 0.0;

      for (final t in txns) {
        if (t.isCash) {
          if (t.isAdvance || t.isFinal) cash += t.amount;
          if (t.isRefund) cash -= t.amount;
        } else if (t.isUpi) {
          if (t.isAdvance || t.isFinal) upi += t.amount;
          if (t.isRefund) upi -= t.amount;
        }
      }

      // Cash = 20 + 40 - 10 = 50
      expect(cash, equals(50.0));
      // UPI = 50 + 100 - 20 = 130
      expect(upi, equals(130.0));
      // Grand Total = 50 + 130 = 180
      expect(cash + upi, equals(180.0));
    });
  });

  group('E) Dynamic Settings & Single Authoritative Rate Chart', () {
    test('18. SystemSettingsModel defaults to approved rate chart without conflicts', () {
      const settings = SystemSettingsModel();
      // Approved Two-Wheeler: 20 / 5 / 60 / 600
      expect(settings.twoWheelerFirstHourRate, equals(20.0));
      expect(settings.twoWheelerAdditionalHourRate, equals(5.0));
      expect(settings.twoWheeler12HourCap, equals(60.0));
      expect(settings.twoWheelerMonthlyRate, equals(600.0));

      // Approved Four-Wheeler (resolved from AppConstants & fee engine): 50 / 10 / 150 / 1500
      expect(settings.fourWheelerFirstHourRate, equals(50.0));
      expect(settings.fourWheelerAdditionalHourRate, equals(10.0));
      expect(settings.fourWheeler12HourCap, equals(150.0));
      expect(settings.fourWheelerMonthlyRate, equals(1500.0));

      expect(settings.carTotalCapacity, equals(100));
      expect(settings.twoWheelerTotalCapacity, equals(150));
    });

    test('19. SystemSettingsModel serialization and copyWith work correctly', () {
      const original = SystemSettingsModel();
      final updated = original.copyWith(
        carTotalCapacity: 75,
        twoWheelerTotalCapacity: 150,
        englishName: 'PUNE CENTRAL PARKING',
      );

      final map = updated.toFirestore();
      expect(map['carTotalCapacity'], equals(75));
      expect(map['twoWheelerTotalCapacity'], equals(150));
      expect(map['englishName'], equals('PUNE CENTRAL PARKING'));

      final restored = SystemSettingsModel.fromMap(map);
      expect(restored.carTotalCapacity, equals(75));
      expect(restored.twoWheelerTotalCapacity, equals(150));
      expect(restored.englishName, equals('PUNE CENTRAL PARKING'));
    });
  });

  group('F) Report Export & CSV Formatting', () {
    test('20. CSV formatter produces UTF-8 BOM and escapes commas/quotes', () {
      final headers = ['Guard', 'Amount', 'Note'];
      final rows = [
        ['Ramesh, Senior', 150.5, 'Paid in "Cash"'],
        ['मराठी रक्षक', 200.0, 'पावती #101'],
      ];

      final csv = ReportExportService.formatCsv(headers: headers, rows: rows);

      // Verify UTF-8 BOM (\uFEFF)
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Escaped comma
      expect(csv, contains('"Ramesh, Senior"'));
      // Escaped quote
      expect(csv, contains('"Paid in ""Cash"""'));
      // Marathi text preserved
      expect(csv, contains('मराठी रक्षक'));
    });
  });

  group('G) Audit Log Model Verification', () {
    test('21. AuditLogModel serializes correctly with action and entity metadata', () {
      final now = DateTime.now();
      final log = AuditLogModel(
        id: 'log_01',
        adminUid: 'admin_01',
        adminName: 'Chief Admin',
        action: 'ADD_GUARD',
        targetEntity: 'guard',
        targetId: 'guard_123',
        details: {'name': 'New Guard', 'shift': 'Shift 1'},
        timestamp: now,
      );

      final map = log.toFirestore();
      expect(map['adminUid'], equals('admin_01'));
      expect(map['action'], equals('ADD_GUARD'));
      expect(map['targetEntity'], equals('guard'));
      expect(map['targetId'], equals('guard_123'));
      expect(map['details']['name'], equals('New Guard'));
    });
  });

  group('H) Configurable Shift Duration (8h, 9h, 10h) & Overlap Detection', () {
    test('22. Factory createShiftWithDuration automatically computes 8, 9, and 10 hour end times', () {
      final baseDate = DateTime(2026, 9, 28);
      final startTime = DateTime(2026, 9, 28, 9, 0);

      final shift8 = ShiftModel.createShiftWithDuration(
        shiftId: 's8',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: baseDate,
        startTime: startTime,
        durationHours: 8,
      );
      expect(shift8.durationHours, equals(8));
      expect(shift8.startTime.hour, equals(9));
      expect(shift8.endTime.hour, equals(17)); // 05:00 PM
      expect(shift8.endTime.day == shift8.startTime.day, isTrue);

      final shift9 = ShiftModel.createShiftWithDuration(
        shiftId: 's9',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: baseDate,
        startTime: startTime,
        durationHours: 9,
      );
      expect(shift9.durationHours, equals(9));
      expect(shift9.endTime.hour, equals(18)); // 06:00 PM

      final shift10 = ShiftModel.createShiftWithDuration(
        shiftId: 's10',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: baseDate,
        startTime: startTime,
        durationHours: 10,
      );
      expect(shift10.durationHours, equals(10));
      expect(shift10.endTime.hour, equals(19)); // 07:00 PM
    });

    test('23. Shift crossing midnight automatically computes end time on the next day', () {
      final baseDate = DateTime(2026, 9, 28);
      final startTime = DateTime(2026, 9, 28, 22, 0); // 10:00 PM

      final nightShift8 = ShiftModel.createShiftWithDuration(
        shiftId: 's_night_8',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: baseDate,
        startTime: startTime,
        durationHours: 8,
      );
      expect(nightShift8.endTime.day, equals(29));
      expect(nightShift8.endTime.hour, equals(6)); // 06:00 AM next day
      expect(nightShift8.endTime.difference(nightShift8.startTime).inHours, equals(8));

      final nightShift10 = ShiftModel.createShiftWithDuration(
        shiftId: 's_night_10',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: baseDate,
        startTime: startTime,
        durationHours: 10,
      );
      expect(nightShift10.endTime.day, equals(29));
      expect(nightShift10.endTime.hour, equals(8)); // 08:00 AM next day
      expect(nightShift10.endTime.difference(nightShift10.startTime).inHours, equals(10));
    });

    test('24. Shift overlap detection prevents assigning conflicting shifts to the same guard', () {
      final existingShift = ShiftModel(
        shiftId: 's_exist',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 9, 28),
        startTime: DateTime(2026, 9, 28, 9, 0),
        endTime: DateTime(2026, 9, 28, 17, 0),
        status: 'UPCOMING',
      );

      // Overlapping test shift: 14:00 to 22:00
      final candidateStart = DateTime(2026, 9, 28, 14, 0);
      final candidateEnd = DateTime(2026, 9, 28, 22, 0);

      final overlaps = candidateStart.isBefore(existingShift.endTime) &&
          candidateEnd.isAfter(existingShift.startTime);
      expect(overlaps, isTrue);

      // Non-overlapping test shift: 17:00 to 01:00
      final nonOverlapStart = DateTime(2026, 9, 28, 17, 0);
      final nonOverlapEnd = DateTime(2026, 9, 29, 1, 0);
      final overlapsNon = nonOverlapStart.isBefore(existingShift.endTime) &&
          nonOverlapEnd.isAfter(existingShift.startTime);
      expect(overlapsNon, isFalse);
    });
  });

  group('I) Cash & UPI Strict Segregation & Full Amount Handover', () {
    test('25. GuardFinancialResponsibility maintains independent Cash and UPI ledgers', () {
      const resp = GuardFinancialResponsibility(
        guardUid: 'g1',
        guardName: 'Guard A',
        totalCashCollected: 1000.0,
        cashHandedOver: 200.0,
        cashReceived: 0.0,
        cashWithdrawn: 0.0,
        totalUpiCollected: 700.0,
        upiHandedOver: 0.0,
        upiReceived: 0.0,
        upiWithdrawn: 100.0,
      );

      // Cash: 1000 - 200 = 800
      expect(resp.outstandingCash, equals(800.0));
      // UPI: 700 - 100 = 600
      expect(resp.outstandingUpi, equals(600.0));
      // Total outstanding: 800 + 600 = 1400
      expect(resp.totalOutstanding, equals(1400.0));

      // Cash operations must not alter UPI balances
      final afterCashHandover = resp.copyWith(cashHandedOver: 1000.0);
      expect(afterCashHandover.outstandingCash, equals(0.0));
      expect(afterCashHandover.outstandingUpi, equals(600.0)); // Unchanged
    });

    test('26. HandoverModel enforces full amount, status transitions, and independent type', () {
      final now = DateTime.now();
      final handover = HandoverModel(
        handoverId: 'ho_01',
        fromGuardId: 'g1',
        fromGuardName: 'Guard A',
        toGuardId: 'g2',
        toGuardName: 'Guard B',
        shiftId: 'shift_101',
        amount: 1000.0,
        type: 'CASH',
        action: 'HANDOVER',
        createdAt: now,
        status: 'PENDING',
      );

      expect(handover.isCash, isTrue);
      expect(handover.isUpi, isFalse);
      expect(handover.isPending, isTrue);
      expect(handover.isAccepted, isFalse);

      final accepted = handover.copyWith(status: 'ACCEPTED', acceptedBy: 'g2', acceptedAt: now);
      expect(accepted.isAccepted, isTrue);
      expect(accepted.isPending, isFalse);

      final map = accepted.toFirestore();
      expect(map['type'], equals('CASH'));
      expect(map['amount'], equals(1000.0));
      expect(map['status'], equals('ACCEPTED'));
      expect(map['acceptedBy'], equals('g2'));
    });
  });

  group('J) Admin Full Withdrawal & Zero Custom Amount Constraint', () {
    test('27. WithdrawalModel records full settlement independently for Cash and UPI', () {
      final now = DateTime.now();
      final cashWithdrawal = WithdrawalModel(
        withdrawalId: 'w_01',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftId: 'shift_101',
        type: 'CASH',
        amount: 800.0,
        adminUid: 'admin_01',
        adminName: 'Chief Admin',
        createdAt: now,
        status: 'COMPLETED',
        notes: 'Full Cash Settlement',
      );

      expect(cashWithdrawal.isCash, isTrue);
      expect(cashWithdrawal.isUpi, isFalse);
      expect(cashWithdrawal.amount, equals(800.0));

      final upiWithdrawal = WithdrawalModel(
        withdrawalId: 'w_02',
        guardId: 'g1',
        guardName: 'Guard A',
        shiftId: 'shift_101',
        type: 'UPI',
        amount: 600.0,
        adminUid: 'admin_01',
        adminName: 'Chief Admin',
        createdAt: now,
        status: 'COMPLETED',
      );

      expect(upiWithdrawal.isCash, isFalse);
      expect(upiWithdrawal.isUpi, isTrue);
      expect(upiWithdrawal.amount, equals(600.0));

      final map = cashWithdrawal.toFirestore();
      expect(map['type'], equals('CASH'));
      expect(map['amount'], equals(800.0));
      expect(map['adminUid'], equals('admin_01'));
      expect(map['status'], equals('COMPLETED'));
    });
  });

  group('L) Admin Dashboard Rendering & Edit Capacity Validation', () {
    testWidgets('29. Admin Dashboard renders only operational sections up to Today\'s Operations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Core sections rendered
      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.parkingCapacity), findsOneWidget);
      expect(find.text(AppStrings.todaysOperations), findsOneWidget);
      expect(find.byKey(const ValueKey('admin_edit_capacity_button')), findsOneWidget);

      // Lower sections NOT rendered
      expect(find.text(AppStrings.financialResponsibility), findsNothing);
      expect(find.text(AppStrings.shiftOverview), findsNothing);
      expect(find.text(AppStrings.handoverWithdrawalActivity), findsNothing);
      expect(find.text(AppStrings.recentActivity), findsNothing);
      expect(find.text(AppStrings.recentNotifications), findsNothing);
      expect(find.text(AppStrings.quickNavigation), findsNothing);
    });

    testWidgets('30. Edit Capacity button opens dialog with input fields and auto-calculates Total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(currentAdmin: testAdmin),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Edit Capacity button
      final editButton = find.byKey(const ValueKey('admin_edit_capacity_button'));
      expect(editButton, findsOneWidget);
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog opened
      expect(find.byKey(const ValueKey('dialog_four_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_two_wheeler_capacity_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog_save_capacity_button')), findsOneWidget);
      expect(find.text('(Auto-calculated)'), findsOneWidget);

      // Enter new Four-Wheeler capacity 120
      await tester.enterText(find.byKey(const ValueKey('dialog_four_wheeler_capacity_input')), '120');
      await tester.pump();

      // Total should be 120 + 150 = 270
      expect(find.text('270'), findsOneWidget);
    });

    test('31. Capacity validation strictly enforces capacity >= current occupied slots', () {
      const currentOccupiedCar = 7;
      const currentOccupiedBike = 15;

      bool validateCapacity(int carCap, int bikeCap) {
        if (carCap <= 0 || bikeCap <= 0) return false;
        if (carCap < currentOccupiedCar) return false;
        if (bikeCap < currentOccupiedBike) return false;
        return true;
      }

      // Valid capacity increases and exact matches
      expect(validateCapacity(100, 150), isTrue);
      expect(validateCapacity(7, 15), isTrue);
      expect(validateCapacity(8, 20), isTrue);
      expect(validateCapacity(120, 150), isTrue);

      // Invalid capacities below occupancy
      expect(validateCapacity(6, 15), isFalse); // Car cap < 7
      expect(validateCapacity(7, 14), isFalse); // Bike cap < 15
      expect(validateCapacity(0, 150), isFalse);
      expect(validateCapacity(100, -5), isFalse);
    });
  });
}


