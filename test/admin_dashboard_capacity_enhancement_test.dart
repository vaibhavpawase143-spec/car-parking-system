import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/theme/app_colors.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/dashboard_service.dart';
import 'package:car_parking_system/services/settings_service.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:car_parking_system/widgets/guard/capacity_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  const testAdmin = GuardModel(
    uid: 'admin_test_123',
    name: 'Super Admin',
    email: 'admin@jayganesh.com',
    role: 'admin',
    isActive: true,
  );

  group('A) PARKING CAPACITY MODEL & VALIDATION TESTS', () {
    test('1. CapacityData correctly calculates available slots and blocked status per vehicle type', () {
      const capacity = CapacityData(
        carTotal: 100,
        carOccupied: 100,
        twoWheelerTotal: 150,
        twoWheelerOccupied: 50,
      );

      expect(capacity.carAvailable, 0);
      expect(capacity.isBlocked(VehicleType.fourWheeler), isTrue);

      expect(capacity.twoWheelerAvailable, 100);
      expect(capacity.isBlocked(VehicleType.twoWheeler), isFalse);
    });

    test('2. SettingsService updateCapacity validates capacity is not less than occupied vehicles', () async {
      expect(
        () => SettingsService.instance.updateCapacity(
          fourWheelerCapacity: 70,
          twoWheelerCapacity: 150,
          adminUid: 'admin_1',
          adminName: 'Admin',
          currentFourWheelerOccupied: 80,
          currentTwoWheelerOccupied: 20,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('80'),
        )),
      );

      expect(
        () => SettingsService.instance.updateCapacity(
          fourWheelerCapacity: 100,
          twoWheelerCapacity: 30,
          adminUid: 'admin_1',
          adminName: 'Admin',
          currentFourWheelerOccupied: 50,
          currentTwoWheelerOccupied: 40,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('40'),
        )),
      );
    });

    test('3. English and Marathi validation error strings format correctly', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      final enCarError = AppStrings.fourWheelerCapacityError(80);
      expect(enCarError, 'Four-Wheeler capacity cannot be less than the current occupied vehicles (80).');

      final enBikeError = AppStrings.twoWheelerCapacityError(45);
      expect(enBikeError, 'Two-Wheeler capacity cannot be less than the current occupied vehicles (45).');

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      final mrCarError = AppStrings.fourWheelerCapacityError(80);
      expect(mrCarError, 'Four-Wheeler ची क्षमता सध्याच्या 80 वाहनांपेक्षा कमी असू शकत नाही.');

      final mrBikeError = AppStrings.twoWheelerCapacityError(45);
      expect(mrBikeError, 'Two-Wheeler ची क्षमता सध्याच्या 45 वाहनांपेक्षा कमी असू शकत नाही.');

      // Reset to English
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });

    test('4. Full parking message per vehicle type', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.fourWheelerParkingFull, 'Four-Wheeler parking is full. No space is currently available.');
      expect(AppStrings.twoWheelerParkingFull, 'Two-Wheeler parking is full. No space is currently available.');

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.fourWheelerParkingFull, 'चारचाकी पार्किंग पूर्ण भरले आहे. सध्या जागा उपलब्ध नाही.');
      expect(AppStrings.twoWheelerParkingFull, 'दुचाकी पार्किंग पूर्ण भरले आहे. सध्या जागा उपलब्ध नाही.');

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });
  });

  group('B) GUARD DASHBOARD CAPACITY INDICATOR TESTS', () {
    testWidgets('5. Guard CapacityIndicator displays 4W & 2W total, occupied, available and occupancy %', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapacityIndicator(
              carTotal: 100,
              carOccupied: 70,
              twoWheelerTotal: 150,
              twoWheelerOccupied: 40,
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.fourWheeler), findsOneWidget);
      expect(find.text(AppStrings.twoWheeler), findsOneWidget);

      expect(find.text('70% ${AppStrings.occupied}'), findsOneWidget);
      expect(find.text('26% ${AppStrings.occupied}'), findsOneWidget);

      expect(find.text('30'), findsOneWidget); // 4W available
      expect(find.text('110'), findsOneWidget); // 2W available
    });

    testWidgets('6. Guard CapacityIndicator marks full vehicle type with Full Entry Blocked badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapacityIndicator(
              carTotal: 100,
              carOccupied: 100, // FULL
              twoWheelerTotal: 150,
              twoWheelerOccupied: 50, // AVAILABLE
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.fullEntryBlocked), findsOneWidget);
      expect(find.text('33% ${AppStrings.occupied}'), findsOneWidget);
    });
  });

  group('C) ADMIN DASHBOARD RENDERING & SECTIONS TESTS', () {
    testWidgets('7. Admin Dashboard renders header, capacity section, quick actions without overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Header checks
      expect(find.textContaining('Super Admin'), findsWidgets);
      expect(find.textContaining(AppStrings.adminPortalTitle), findsWidgets);

      // Section Titles - Present
      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.parkingCapacity), findsOneWidget);
      expect(find.text(AppStrings.todaysOperations), findsOneWidget);

      // Section Titles - Lower sections NOT rendered on Dashboard
      expect(find.text(AppStrings.financialResponsibility), findsNothing);
      expect(find.text(AppStrings.shiftOverview), findsNothing);
      expect(find.text(AppStrings.handoverWithdrawalActivity), findsNothing);
      expect(find.text(AppStrings.recentActivity), findsNothing);
      expect(find.text(AppStrings.recentNotifications), findsNothing);
      expect(find.text(AppStrings.quickNavigation), findsNothing);

      // Capacity card elements
      expect(find.text(AppStrings.fourWheeler), findsOneWidget);
      expect(find.text(AppStrings.twoWheeler), findsOneWidget);
      expect(find.text(AppStrings.editCapacity), findsWidgets);
    });

    testWidgets('8. Clicking Edit Capacity opens dialog with calculated total and validation', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Find and tap Edit Capacity
      final editBtn = find.text(AppStrings.editCapacity).first;
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text(AppStrings.parkingCapacity), findsWidgets);
      expect(find.text(AppStrings.fourWheelerCapacity), findsOneWidget);
      expect(find.text(AppStrings.twoWheelerCapacity), findsOneWidget);
      expect(find.text(AppStrings.totalCapacity), findsWidgets);
      expect(find.text(AppStrings.saveChanges), findsOneWidget);
      expect(find.text(AppStrings.cancel), findsOneWidget);

      // Tap Cancel to close
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.fourWheelerCapacity), findsNothing);
    });

    testWidgets('9. Admin Dashboard reactive language change from English to Marathi', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await AppLanguageController.instance.setLanguage(AppLanguage.english);

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
      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.parkingCapacity), findsOneWidget);

      // Switch to Marathi
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

      expect(find.text(AppStrings.guardStatistics), findsOneWidget);
      expect(find.text(AppStrings.parkingCapacity), findsWidgets);

      // Reset
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });
  });

  group('D) COLOR SYSTEM & VISUAL ACCESSIBILITY', () {
    test('10. Curated color palette matches specified design requirements', () {
      expect(AppColors.primary, const Color(0xFF0F172A)); // Deep Navy #0F172A
      expect(AppColors.secondaryNavy, const Color(0xFF1E3A8A)); // Secondary Navy #1E3A8A
      expect(AppColors.primaryOrange, const Color(0xFFF97316)); // Primary Orange #F97316
      expect(AppColors.success, const Color(0xFF10B981)); // Success #10B981
      expect(AppColors.warning, const Color(0xFFF59E0B)); // Amber #F59E0B
      expect(AppColors.danger, const Color(0xFFDC2626)); // Red #DC2626
    });
  });
}
