import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/config/business_profile.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await BusinessProfileController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('1. Final Branding Constants - Non-Negotiable', () {
    test('Branding constants are strictly English in English mode', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.appName, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.companyBrand, equals('BIZFLOW'));
      expect(AppStrings.adminPortal, equals('ADMIN PORTAL'));
      expect(AppStrings.browserTitle, equals('CAR PARKING SYSTEM | BIZFLOW'));
    });

    test('Branding constants remain strictly uppercase English in Marathi mode', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.appName, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.companyBrand, equals('BIZFLOW'));
      expect(AppStrings.adminPortal, equals('ADMIN PORTAL'));
      expect(AppStrings.browserTitle, equals('CAR PARKING SYSTEM | BIZFLOW'));
    });
  });

  group('2. BusinessProfile & SystemSettingsModel Cleansing', () {
    test('Default BusinessProfile has CAR PARKING SYSTEM and no Jay Ganesh', () {
      final profile = BusinessProfileController.instance.profile;
      expect(profile.englishName, equals('CAR PARKING SYSTEM'));
      expect(profile.marathiName, equals('CAR PARKING SYSTEM'));
      expect(profile.englishName.contains('JAY GANESH'), isFalse);
      expect(profile.marathiName.contains('जय गणेश'), isFalse);
    });

    test('BusinessProfile cleanses cached SharedPreferences with old name', () async {
      SharedPreferences.setMockInitialValues({
        'biz_profile_marathi_name': 'जय गणेश पे अँड पार्क',
        'biz_profile_english_name': 'JAY GANESH PAY & PARK',
      });
      await BusinessProfileController.instance.init();
      final p = BusinessProfileController.instance.profile;
      expect(p.marathiName, equals('CAR PARKING SYSTEM'));
      expect(p.englishName, equals('CAR PARKING SYSTEM'));
    });

    test('SystemSettingsModel sanitizes old Firestore data on load', () {
      final oldModel = SystemSettingsModel.fromMap({
        'englishName': 'JAY GANESH PAY & PARK',
        'marathiName': 'जय गणेश पे अँड पार्क',
      });
      expect(oldModel.englishName, equals('CAR PARKING SYSTEM'));
      expect(oldModel.marathiName, equals('CAR PARKING SYSTEM'));
    });
  });

  group('3. Admin Navigation Shell Renders Fixed English Branding & Localized Role', () {
    testWidgets('AdminNavigationShell displays CAR PARKING SYSTEM, BIZFLOW, ADMIN PORTAL in Marathi', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      const admin = GuardModel(
        uid: 'admin_test_1',
        name: 'Mahesh Sharma',
        email: 'admin@bizflow.com',
        role: 'admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminNavigationShell(currentAdmin: admin),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAR PARKING SYSTEM'), findsAtLeastNWidgets(1));
      expect(find.text('BIZFLOW'), findsAtLeastNWidgets(1));
      expect(find.text('ADMIN PORTAL'), findsAtLeastNWidgets(1));

      // User name is preserved (not translated)
      expect(find.text('Mahesh Sharma'), findsOneWidget);

      // Verify old branding is completely absent
      expect(find.text('जय गणेश पे अँड पार्क'), findsNothing);
      expect(find.text('JAY GANESH PAY & PARK'), findsNothing);
      expect(find.text('Jay Ganesh Pay & Park'), findsNothing);
    });
  });

  group('4. Marathi Localization Audit for Operational Labels', () {
    test('Upcoming, Full, Rate Chart labels, and Master Admin are localized in Marathi', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.upcoming, equals('आगामी'));
      expect(AppStrings.full, equals('पूर्ण'));
      expect(AppStrings.firstHour, equals('पहिला तास'));
      expect(AppStrings.additionalHour, equals('पुढील तास'));
      expect(AppStrings.twelveHourCap, equals('१२-तास मर्यादा'));
      expect(AppStrings.monthlyPass, equals('मासिक पास'));
      expect(AppStrings.masterAdmin, equals('मास्टर ॲडमिन'));
    });

    test('Status formatters localize accurately without altering database keys', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.formatStatus('ASSIGNED'), equals('नियुक्त'));
      expect(AppStrings.formatStatus('ACTIVE'), equals('सक्रिय'));
      expect(AppStrings.formatStatus('COMPLETED'), equals('पूर्ण'));
      expect(AppStrings.formatStatus('CANCELLED'), equals('रद्द केले'));
      expect(AppStrings.formatStatus('UPCOMING'), equals('आगामी'));

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.formatStatus('ASSIGNED'), equals('Assigned'));
      expect(AppStrings.formatStatus('ACTIVE'), equals('Active'));
      expect(AppStrings.formatStatus('COMPLETED'), equals('Completed'));
      expect(AppStrings.formatStatus('CANCELLED'), equals('Cancelled'));
      expect(AppStrings.formatStatus('UPCOMING'), equals('Upcoming'));
    });

    test('Payment type formatters localize accurately', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.formatPaymentType('ADVANCE'), equals('अ‍ॅडव्हान्स'));
      expect(AppStrings.formatPaymentType('FINAL'), equals('अंतिम'));
      expect(AppStrings.formatPaymentType('REFUND'), equals('परतावा'));

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.formatPaymentType('ADVANCE'), equals('Advance'));
      expect(AppStrings.formatPaymentType('FINAL'), equals('Final'));
      expect(AppStrings.formatPaymentType('REFUND'), equals('Refund'));
    });

    test('Payment method formatters localize accurately', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.formatPaymentMethod('CASH'), equals('रोख'));
      expect(AppStrings.formatPaymentMethod('UPI'), equals('UPI'));

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.formatPaymentMethod('CASH'), equals('Cash'));
      expect(AppStrings.formatPaymentMethod('UPI'), equals('UPI'));
    });
  });

  group('5. Receipts and WhatsApp Templates Use CAR PARKING SYSTEM', () {
    final sample = ParkingRecord(
      id: 'rec_1',
      ticketNumber: '1001',
      vehicleNumber: 'MH12AB1234',
      vehicleType: VehicleType.fourWheeler,
      entryTime: DateTime(2026, 9, 30, 10, 0),
      entryGuardUid: 'g1',
      entryGuardName: 'Suresh Guard',
      entryShift: 'Shift 1',
      advanceAmount: 50.0,
      advancePaymentMethod: 'cash',
      exitTime: DateTime(2026, 9, 30, 12, 0),
      grossCharge: 70.0,
      balanceDue: 20.0,
      paymentMethod: 'cash',
      status: 'EXITED',
    );

    test('Receipt HTML in Marathi mode renders CAR PARKING SYSTEM and no old name', () {
      final html = ReceiptPrintService.build58mmReceiptHtml(sample, language: AppLanguage.marathi);
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html.contains('जय गणेश पे अँड पार्क'), isFalse);
      expect(html.contains('JAY GANESH'), isFalse);
    });

    test('WhatsApp exit message in Marathi mode contains CAR PARKING SYSTEM and no old name', () {
      final msg = WhatsAppService.buildExitMessage(sample, language: AppLanguage.marathi);
      expect(msg, contains('CAR PARKING SYSTEM'));
      expect(msg.contains('जय गणेश पे अँड पार्क'), isFalse);
      expect(msg.contains('JAY GANESH'), isFalse);
    });
  });
}
