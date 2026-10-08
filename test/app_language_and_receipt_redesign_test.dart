import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/config/business_profile.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/marathi_receipt_rasterizer.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRecord = ParkingRecord(
    id: 'test-rec-1',
    ticketNumber: '1005',
    qrReference: '1005',
    vehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.twoWheeler,
    entryTime: DateTime(2026, 9, 24, 15, 30),
    entryGuardUid: 'g1',
    entryGuardName: 'Ramesh Guard',
    entryShift: 'Shift 1',
    customerMobile: '9690793434',
    advanceAmount: 50.0,
    advancePaymentMethod: 'cash',
    status: 'ACTIVE',
    photoUrl: 'https://example.com/p.jpg',
  );

  final sampleExitRecord = ParkingRecord(
    id: 'test-rec-2',
    ticketNumber: '1006',
    qrReference: '1006',
    vehicleNumber: 'MH14XY9999',
    vehicleType: VehicleType.fourWheeler,
    entryTime: DateTime(2026, 9, 24, 12, 00),
    exitTime: DateTime(2026, 9, 24, 15, 30),
    entryGuardUid: 'g1',
    entryGuardName: 'Suresh Guard',
    entryShift: 'Shift 1',
    customerMobile: '9690793434',
    advanceAmount: 20.0,
    grossCharge: 60.0,
    balanceDue: 40.0,
    paymentMethod: 'cash',
    status: 'EXITED',
    exitGuardName: 'Mahesh Guard',
    exitShift: 'Shift 1',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await BusinessProfileController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('A. Global App Language Localization & Persistence', () {
    test('1. Default global language is English', () {
      expect(AppLanguageController.instance.currentLanguage, equals(AppLanguage.english));
      expect(AppStrings.dashboard, equals('Dashboard'));
      expect(AppStrings.entry, equals('Vehicle Entry'));
      expect(AppStrings.exit, equals('Vehicle Exit'));
      expect(AppStrings.active, equals('Active Parking'));
      expect(AppStrings.settings, equals('Language & Settings'));
    });

    test('2. Switching language to Marathi updates UI strings immediately', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppLanguageController.instance.isMarathi, isTrue);
      expect(AppStrings.dashboard, equals('डॅशबोर्ड'));
      expect(AppStrings.entry, equals('वाहन प्रवेश'));
      expect(AppStrings.exit, equals('वाहन निर्गमन'));
      expect(AppStrings.active, equals('सक्रिय पार्किंग'));
      expect(AppStrings.shift, equals('माझी पाळी'));
      expect(AppStrings.settings, equals('भाषा व सेटिंग्ज'));
    });

    test('3. Switching back from Marathi to English updates strings immediately', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.dashboard, equals('डॅशबोर्ड'));

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.dashboard, equals('Dashboard'));
      expect(AppStrings.entry, equals('Vehicle Entry'));
    });

    test('4. Language selection persists across app reloads', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language_code'), equals('mr'));
    });
  });

  group('B. Business Identity & Mobile Number Verification', () {
    test('5. Business profile contains verified CAR PARKING SYSTEM identity', () {
      final profile = BusinessProfileController.instance.profile;
      expect(profile.marathiName, equals('CAR PARKING SYSTEM'));
      expect(profile.englishName, equals('CAR PARKING SYSTEM'));
      expect(profile.marathiLocation, equals('संगमनेर बसस्थानक'));
      expect(profile.englishLocation, equals('SANGAMNER BUS STAND'));
      expect(profile.mobile, equals('9690793434'));
      expect(profile.marathiMobile, equals('९६९०७९३४३४'));
      expect(profile.marathiAuthority, equals('म. रा. मा. परिवहन महामंडळाचे अधिकृत वाहनतळ'));
      expect(profile.bizflowBrandingEnabled, isTrue);
    });
  });

  group('C. 58mm Thermal Receipt Follows Global App Language', () {
    test('6. Global English mode produces English Entry Receipt', () {
      final html = ReceiptPrintService.build58mmReceiptHtml(sampleRecord, language: AppLanguage.english);
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('JAY GANESH')));
      expect(html, contains('SANGAMNER BUS STAND'));
      expect(html, contains('Mo. 9690793434'));
      expect(html, contains('ENTRY RECEIPT'));
      expect(html, contains('TICKET: 1005'));
      expect(html, contains('MH12AB1234'));
      expect(html, contains('Powered by'));
      expect(html, contains('BIZFLOW'));
      expect(html, contains('Parking Management System'));
    });

    test('7. Global Marathi mode produces Marathi Entry Receipt with Devanagari headers', () {
      final html = ReceiptPrintService.build58mmReceiptHtml(sampleRecord, language: AppLanguage.marathi);
      expect(html, contains('॥ श्री ॥'));
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('जय गणेश')));
      expect(html, contains('संगमनेर बसस्थानक'));
      expect(html, contains('मो. ९६९०७९३४३४'));
      expect(html, contains('वाहनतळ पावती (प्रवेश पावती)'));
      expect(html, contains('पावती क्र.: 1005'));
      expect(html, contains('प्रवेश दिनांक:'));
      expect(html, contains('प्रवेश वेळ:'));
      expect(html, contains('सुरक्षा रक्षक:'));
      expect(html, contains('कृपया ही पावती सांभाळून ठेवा.'));
      expect(html, contains('द्वारे संचालित'));
      expect(html, contains('BIZFLOW'));
    });

    test('8. Global English mode produces English Exit Settlement Receipt', () {
      final html = ReceiptPrintService.build58mmExitReceiptHtml(sampleExitRecord, language: AppLanguage.english);
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('JAY GANESH')));
      expect(html, contains('SANGAMNER BUS STAND'));
      expect(html, contains('EXIT RECEIPT'));
      expect(html, contains('TOTAL AMOUNT'));
      expect(html, contains('Advance Paid'));
      expect(html, contains('BALANCE DUE:'));
      expect(html, contains('Powered by'));
      expect(html, contains('BIZFLOW'));
    });

    test('9. Global Marathi mode produces Marathi Exit Settlement Receipt', () {
      final html = ReceiptPrintService.build58mmExitReceiptHtml(sampleExitRecord, language: AppLanguage.marathi);
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('जय गणेश')));
      expect(html, contains('वाहनतळ पावती (बाहेर जाण्याची पावती)'));
      expect(html, contains('एकूण रक्कम'));
      expect(html, contains('वसूल केलेली शिल्लक:'));
      expect(html, contains('धन्यवाद! पुन्हा भेट द्या.'));
      expect(html, contains('द्वारे संचालित'));
      expect(html, contains('BIZFLOW'));
    });

    test('10. BizFlow branding can be toggled OFF via Business Profile', () {
      final customProfile = const BusinessProfile(bizflowBrandingEnabled: false);
      final html = ReceiptPrintService.build58mmReceiptHtml(
        sampleRecord,
        language: AppLanguage.english,
        profile: customProfile,
      );
      expect(html, isNot(contains('BIZFLOW')));
    });
  });

  group('D. WhatsApp Message Follows Global App Language', () {
    test('11. WhatsApp message in English', () {
      final msg = WhatsAppService.buildEntryMessage(sampleRecord, language: AppLanguage.english);
      expect(msg, contains('Car Parking Entry Confirmation'));
      expect(msg, contains('Ticket No: 1005'));
      expect(msg, contains('Vehicle No: MH12AB1234'));
      expect(msg, contains('Please keep this message'));
    });

    test('12. WhatsApp message in Marathi', () {
      final msg = WhatsAppService.buildEntryMessage(sampleRecord, language: AppLanguage.marathi);
      expect(msg, contains('वाहन पार्किंग प्रवेश पावती'));
      expect(msg, contains('तिकीट क्र.: 1005'));
      expect(msg, contains('वाहन क्र.: MH12AB1234'));
      expect(msg, contains('कृपया ही माहिती'));
    });
  });

  group('E. Marathi Thermal Rasterizer & 58mm Width Verification', () {
    test('13. Raster images strictly match 384-pixel printable width for 58mm thermal printers', () async {
      final header = await MarathiReceiptRasterizer.renderEntryHeader();
      expect(header.width, equals(384));

      final body = await MarathiReceiptRasterizer.renderEntryBody(sampleRecord);
      expect(body.width, equals(384));

      final footer = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.marathi);
      expect(footer.width, equals(384));
    });
  });

  group('F. Instant Reactive Screen Rebuild on Language Change', () {
    testWidgets('14. Changing language immediately rebuilds active screen without navigation', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController.instance,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Dependency tracking through AppLanguageScope
                AppLanguageScope.of(context);
                return Text(AppStrings.dashboard);
              },
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('डॅशबोर्ड'), findsNothing);

      // Change language
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      await tester.pump();

      // Screen updates immediately
      expect(find.text('डॅशबोर्ड'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    });
  });
}
