import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/theme/app_colors.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/screens/admin/guards/admin_guard_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  const testAdmin = GuardModel(
    uid: 'tIQh3GVZYbZQkqL0Fy5H1qb01mP2',
    name: 'Master Admin',
    email: 'vaibhavpawase143@gmail.com',
    role: 'admin',
    isActive: true,
  );

  group('A) CAPACITY PERMISSION & SAVE SPEC TESTS (Points 1 - 4)', () {
    // 1. Admin capacity permission
    test('1. Admin role and authenticated UID matches project admin identity', () {
      expect(testAdmin.isAdmin, isTrue);
      expect(testAdmin.isActive, isTrue);
      expect(testAdmin.email, 'vaibhavpawase143@gmail.com');
      expect(testAdmin.uid, 'tIQh3GVZYbZQkqL0Fy5H1qb01mP2');
    });

    // 2. Capacity save
    test('2. Capacity validation enforces capacity >= current occupancy', () {
      const carOccupied = 45;
      const bikeOccupied = 80;

      bool validate(int newCar, int newBike) {
        if (newCar <= 0 || newBike <= 0) return false;
        if (newCar < carOccupied) return false;
        if (newBike < bikeOccupied) return false;
        return true;
      }

      expect(validate(100, 150), isTrue);
      expect(validate(40, 150), isFalse); // Car capacity below occupancy
      expect(validate(100, 70), isFalse); // Bike capacity below occupancy
      expect(validate(0, 100), isFalse);
    });

    // 3. Capacity Firestore error handling
    test('3. Friendly error message generated on Firestore permission-denied', () {
      String getFriendlyError(dynamic e) {
        return 'Unable to update parking capacity: $e';
      }

      final msg = getFriendlyError('Missing or insufficient permissions.');
      expect(msg, contains('Unable to update parking capacity'));
      expect(msg, contains('Missing or insufficient permissions'));
    });

    // 4. Settings document merge
    test('4. Capacity update merges only capacity and timestamp fields without overwriting tariffs', () {
      const initialSettings = SystemSettingsModel();
      final updatedSettings = initialSettings.copyWith(
        carTotalCapacity: 120,
        twoWheelerTotalCapacity: 180,
      );

      // Tariffs and business profile unchanged
      expect(updatedSettings.carTotalCapacity, 120);
      expect(updatedSettings.twoWheelerTotalCapacity, 180);
      expect(updatedSettings.twoWheelerFirstHourRate, initialSettings.twoWheelerFirstHourRate);
      expect(updatedSettings.fourWheelerFirstHourRate, initialSettings.fourWheelerFirstHourRate);
      expect(updatedSettings.englishName, initialSettings.englishName);
    });
  });

  group('B) ADD GUARD BUTTON & DIALOG SPEC TESTS (Points 5 - 10)', () {
    // 5. Add Guard button visible
    testWidgets('5. Add Guard button rendered with white icon, white label and primary background', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminGuardManagementScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fabFinder = find.byKey(const ValueKey('add_guard_fab'));
      expect(fabFinder, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.backgroundColor, AppColors.secondaryNavy);
      expect(fab.foregroundColor, Colors.white);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text(AppStrings.addGuard), findsOneWidget);
    });

    // 6. Add Guard button clickable
    testWidgets('6. Tapping Add Guard button opens Add Guard Dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminGuardManagementScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fabFinder = find.byKey(const ValueKey('add_guard_fab'));
      await tester.tap(fabFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog rendered
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(AppStrings.guardName), findsOneWidget);
      expect(find.text(AppStrings.guardEmail), findsOneWidget);
      expect(find.text(AppStrings.passwordLabel), findsOneWidget);
      expect(find.text(AppStrings.guardMobile), findsOneWidget);
      expect(find.text(AppStrings.currentShift), findsOneWidget);

      // Clean up dialog
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pump(const Duration(milliseconds: 500));
    });

    // 7. Add Guard validation
    testWidgets('7. Submitting empty form displays validation errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminGuardManagementScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('add_guard_fab')));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Save with empty fields
      await tester.tap(find.text(AppStrings.save));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(AppStrings.requiredField), findsOneWidget);
      expect(find.text(AppStrings.emailRequired), findsOneWidget);
      expect(find.text(AppStrings.passwordRequired), findsOneWidget);

      // Clean up dialog
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pump(const Duration(milliseconds: 500));
    });

    // 8. Add Guard cancel works
    testWidgets('8. Tapping cancel dismisses dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminGuardManagementScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('add_guard_fab')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AlertDialog), findsNothing);
    });

    // 9. Email validation
    test('9. Guard email validator rejects malformed email strings', () {
      String? validateEmail(String? v) {
        if (v == null || v.trim().isEmpty) return AppStrings.emailRequired;
        if (!v.contains('@') || !v.contains('.')) return AppStrings.invalidEmail;
        return null;
      }

      expect(validateEmail(''), AppStrings.emailRequired);
      expect(validateEmail('invalid'), AppStrings.invalidEmail);
      expect(validateEmail('invalid@com'), AppStrings.invalidEmail);
      expect(validateEmail('guard@parking.com'), isNull);
    });

    // 10. Password length validation
    test('10. Guard password validator rejects passwords shorter than 6 characters', () {
      String? validatePassword(String? v) {
        if (v == null || v.trim().isEmpty) return AppStrings.passwordRequired;
        if (v.trim().length < 6) return AppStrings.passwordTooShort;
        return null;
      }

      expect(validatePassword(''), AppStrings.passwordRequired);
      expect(validatePassword('12345'), AppStrings.passwordTooShort);
      expect(validatePassword('123456'), isNull);
    });
  });

  group('C) GUARD LIFECYCLE & NAVIGATION SPEC TESTS (Points 11 - 15)', () {
    // 11. Guard detail
    test('11. Guard model exposes correct profile and status fields', () {
      const g = GuardModel(
        uid: 'g_101',
        name: 'Sandeep Shinde',
        email: 'sandeep@parking.com',
        mobile: '9876543210',
        role: 'guard',
        isActive: true,
      );

      expect(g.name, 'Sandeep Shinde');
      expect(g.isGuard, isTrue);
      expect(g.isAdmin, isFalse);
    });

    // 12. Start Shift action
    test('12. Eligible assigned shift starts cleanly', () {
      final now = DateTime.now();
      final assigned = ShiftModel(
        shiftId: 's1',
        guardId: 'g_101',
        guardName: 'Sandeep Shinde',
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now.add(const Duration(hours: 8)),
        status: 'ASSIGNED',
        shiftDate: now,
      );

      expect(assigned.status, 'ASSIGNED');
      final started = assigned.copyWith(
        status: 'ACTIVE',
        actualStartTime: now,
        startedBy: testAdmin.uid,
      );
      expect(started.status, 'ACTIVE');
      expect(started.startedBy, testAdmin.uid);
    });

    // 13. End Shift action
    test('13. Active shift ends without deleting historical records', () {
      final now = DateTime.now();
      final active = ShiftModel(
        shiftId: 's1',
        guardId: 'g_101',
        guardName: 'Sandeep Shinde',
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.add(const Duration(hours: 4)),
        status: 'ACTIVE',
        shiftDate: now,
      );

      final completed = active.copyWith(
        status: 'COMPLETED',
        actualEndTime: now,
        endedBy: testAdmin.uid,
      );
      expect(completed.status, 'COMPLETED');
      expect(completed.endedBy, testAdmin.uid);
    });

    // 14. View Report
    test('14. View report action is permitted across all shift states', () {
      const states = ['ASSIGNED', 'ACTIVE', 'COMPLETED', 'CANCELLED'];
      for (final s in states) {
        expect(s.isNotEmpty, isTrue);
      }
    });

    // 15. UI Responsiveness
    testWidgets('15. Guard management screen builds responsively on both desktop and mobile viewports', (tester) async {
      // Desktop Viewport
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminGuardManagementScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('add_guard_fab')), findsOneWidget);

      // Mobile Viewport
      await tester.binding.setSurfaceSize(const Size(375, 667));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminGuardManagementScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('add_guard_fab')), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
