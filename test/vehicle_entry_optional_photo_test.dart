import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/entry/vehicle_entry_screen.dart';
import 'package:car_parking_system/services/plate_scanner_service.dart';
import 'package:car_parking_system/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testGuard = GuardModel(
    uid: 'guard-test-42',
    name: 'Ramesh Patil',
    email: 'ramesh@parking.biz',
    mobile: '9876543210',
    isActive: true,
  );

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  setUp(() {
    VehicleEntryScreen.resetTestMocks();
    SettingsService.instance.setMockSettings(
      const SystemSettingsModel(
        requireNumberPlate: true,
        requireCustomerMobile: false,
        requirePlatePhoto: false,
      ),
    );
  });

  tearDown(() {
    VehicleEntryScreen.resetTestMocks();
  });

  group('Vehicle Entry — Optional Number Plate Photo & Mandatory Plate Confirmation Tests', () {
    testWidgets('1. Entry with an unconfirmed plate is strictly BLOCKED', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter vehicle number without clicking confirm
      final plateFinder = find.byKey(const ValueKey('vehicle_number_field'));
      await tester.ensureVisible(plateFinder);
      await tester.enterText(plateFinder, 'MH12AB1234');
      await tester.pumpAndSettle();

      // Enter mobile
      final mobileFinder = find.byKey(const ValueKey('customer_mobile_field'));
      await tester.ensureVisible(mobileFinder);
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pumpAndSettle();

      // Attempt Save without confirming plate
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Must be blocked with mandatory confirmation error
      expect(find.text(AppStrings.plateConfirmationRequired), findsOneWidget);
    });

    testWidgets('2. Entry WITHOUT a photo is ALLOWED when plate is confirmed', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preview card clearly indicates photo is optional
      expect(find.text(AppStrings.numberPlatePhotoOptional), findsOneWidget);

      // Enter valid vehicle number
      final plateFinder = find.byKey(const ValueKey('vehicle_number_field'));
      await tester.ensureVisible(plateFinder);
      await tester.enterText(plateFinder, 'MH12AB1234');
      await tester.pumpAndSettle();

      // Confirm plate
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.plateConfirmed), findsWidgets);

      // Enter mobile
      final mobileFinder = find.byKey(const ValueKey('customer_mobile_field'));
      await tester.ensureVisible(mobileFinder);
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pumpAndSettle();

      // Attempt Save with NO photo captured
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Missing photo does NOT block submission — no photo required error
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsNothing);
      expect(find.text(AppStrings.plateConfirmationRequired), findsNothing);
    });

    testWidgets('3. Entry WITH a photo displays auto-captured preview and allows entry', (tester) async {
      setTestSurfaceSize(tester);

      // Supply genuine sample photo bytes via mock
      VehicleEntryScreen.mockCapturedPhoto = PlateScannerService.kTestSamplePhotoBytes;
      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH12AB1234',
        confidence: 0.95,
        photoBytes: PlateScannerService.kTestSamplePhotoBytes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preview card displays auto-captured on detection subtitle
      expect(find.text(AppStrings.autoCapturedOnDetection), findsOneWidget);

      // Confirm plate
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Enter mobile
      final mobileFinder = find.byKey(const ValueKey('customer_mobile_field'));
      await tester.ensureVisible(mobileFinder);
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Entry is allowed without any photo error
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsNothing);
    });

    test('4. ParkingRecord model safely supports null photoUrl and vehiclePhotoUrl without null crashes', () {
      final record = ParkingRecord(
        id: 'TKT-TEST-001',
        ticketNumber: 'TKT-TEST-001',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: '9876543210',
        entryTime: DateTime(2026, 10, 26, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: testGuard.uid,
        entryGuardName: testGuard.name,
        entryShiftId: 'Morning',
        entryShift: 'Morning',
        photoUrl: null,
        vehiclePhotoUrl: null,
        photoPublicId: null,
        photoDeleteToken: null,
      );

      expect(record.photoUrl, isNull);
      expect(record.vehiclePhotoUrl, isNull);
      expect(record.photoPublicId, isNull);
      expect(record.vehicleNumber, equals('MH12AB1234'));

      final map = record.toFirestore();
      expect(map['photoUrl'], isNull);
      expect(map['vehiclePhotoUrl'], isNull);
      expect(map['vehicleNumber'], equals('MH12AB1234'));
    });

    test('5. PlateScannerService.isPlaceholder correctly identifies 1x1 png vs genuine photo', () {
      expect(PlateScannerService.isPlaceholder(PlateScannerService.kTransparent1x1Png), isTrue);
      expect(PlateScannerService.isPlaceholder(PlateScannerService.kTestSamplePhotoBytes), isFalse);
      expect(PlateScannerService.isPlaceholder(null), isTrue);
      expect(PlateScannerService.isPlaceholder(Uint8List(0)), isTrue);
    });
  });
}
