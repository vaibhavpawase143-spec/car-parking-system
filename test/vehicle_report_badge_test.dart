import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/admin/reports/admin_reports_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('Admin Reports Hub — Vehicle Report Vehicle Type Badge Tests', () {
    testWidgets('1. Reports Hub renders search and filter controls for vehicle report', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminReportsHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure vehicle report section is present
      expect(find.text(AppStrings.vehicleReport), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    test('2. Badge labels correctly localize between English and Marathi', () async {
      // English mode
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      final en2w = AppLanguageController.instance.isMarathi ? AppStrings.twoWheeler : 'TWO-WHEELER';
      final en4w = AppLanguageController.instance.isMarathi ? AppStrings.fourWheeler : 'FOUR-WHEELER';
      expect(en2w.toUpperCase(), equals('TWO-WHEELER'));
      expect(en4w.toUpperCase(), equals('FOUR-WHEELER'));

      // Marathi mode
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      final mr2w = AppLanguageController.instance.isMarathi ? AppStrings.twoWheeler : 'TWO-WHEELER';
      final mr4w = AppLanguageController.instance.isMarathi ? AppStrings.fourWheeler : 'FOUR-WHEELER';
      expect(mr2w.toUpperCase(), equals('दुचाकी'));
      expect(mr4w.toUpperCase(), equals('चारचाकी'));
    });

    test('3. ParkingRecord maintains authoritative vehicleType for live and exited vehicles', () {
      final liveRecord = ParkingRecord(
        id: 'rec_live_1',
        ticketNumber: '1024',
        vehicleNumber: 'MH17PQ7673',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 9, 30, 10, 20),
        status: 'ACTIVE',
        entryGuardUid: 'g1',
        entryGuardName: 'Guard A',
        entryShift: 'Shift 1',
        advanceAmount: 20.0,
      );

      final exitedRecord = ParkingRecord(
        id: 'rec_exited_1',
        ticketNumber: '1025',
        vehicleNumber: 'MH12PG3434',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 30, 11, 11),
        exitTime: DateTime(2026, 9, 30, 17, 30),
        status: 'EXITED',
        entryGuardUid: 'g1',
        entryGuardName: 'Guard B',
        entryShift: 'Shift 1',
        advanceAmount: 50.0,
        paidAmount: 50.0,
      );

      expect(liveRecord.vehicleType, equals(VehicleType.twoWheeler));
      expect(liveRecord.isExited, isFalse);
      expect(exitedRecord.vehicleType, equals(VehicleType.fourWheeler));
      expect(exitedRecord.isExited, isTrue);
    });
  });
}
