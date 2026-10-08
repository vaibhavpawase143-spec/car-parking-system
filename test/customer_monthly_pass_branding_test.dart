import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPassTwoWheelerCash = MonthlyPassModel(
    id: 'pass_001',
    passNumber: 'PASS-2026-002',
    vehicleNumber: 'MH17PD2121',
    normalizedVehicleNumber: 'MH17PD2121',
    vehicleType: VehicleType.twoWheeler,
    customerName: 'Pawase Vaibhav',
    customerMobile: '9876543210',
    startDate: DateTime(2026, 9, 30, 0, 0),
    endDate: DateTime(2026, 10, 29, 23, 59),
    amount: 600.0,
    paymentMethod: 'CASH',
    paymentStatus: 'PAID',
    status: 'ACTIVE',
    createdAt: DateTime(2026, 9, 30, 10, 0),
    createdBy: 'Admin Vaibhav',
  );

  final testPassFourWheelerUpi = MonthlyPassModel(
    id: 'pass_002',
    passNumber: 'PASS-2026-003',
    vehicleNumber: 'MH12AB1234',
    normalizedVehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.fourWheeler,
    customerName: 'Rohan Sharma',
    customerMobile: '9876543211',
    startDate: DateTime(2026, 10, 1, 0, 0),
    endDate: DateTime(2026, 10, 31, 23, 59),
    amount: 600.0,
    paymentMethod: 'UPI',
    paymentStatus: 'PAID',
    status: 'ACTIVE',
    createdAt: DateTime(2026, 10, 1, 9, 0),
    createdBy: 'Admin Vaibhav',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('Customer-Facing Monthly Pass Receipt HTML Branding Tests', () {
    test('1. English Receipt HTML contains exact operator and company branding hierarchy', () {
      final html = ReceiptPrintService.buildMonthlyPassReceiptHtml(
        testPassTwoWheelerCash,
        language: AppLanguage.english,
      );

      // Primary client header
      expect(html, contains('JAY GANESH PAY & PARK'));
      expect(html, contains('Monthly Pass'));

      // Fields
      expect(html, contains('Pass No:'));
      expect(html, contains('PASS-2026-002'));
      expect(html, contains('MH17PD2121'));
      expect(html, contains('Two-Wheeler'));
      expect(html, contains('Pawase Vaibhav'));
      expect(html, contains('30 Sep 2026 → 29 Oct 2026'));
      expect(html, contains('Pass Amount:'));
      expect(html, contains('₹600'));
      expect(html, contains('Payment:'));
      expect(html, contains('PAID (CASH)'));
      expect(html, contains('Parking Fee During Validity:'));
      expect(html, contains('₹0'));
      expect(html, contains('Thank You!'));

      // Footer branding
      expect(html, contains('Powered by BIZFLOW'));
      expect(html, contains('CAR PARKING SYSTEM'));
    });

    test('2. Marathi Receipt HTML contains exact operator and Marathi translations', () {
      final html = ReceiptPrintService.buildMonthlyPassReceiptHtml(
        testPassTwoWheelerCash,
        language: AppLanguage.marathi,
      );

      // Operator remains in English (proper business name)
      expect(html, contains('JAY GANESH PAY & PARK'));
      expect(html, contains('मासिक पास'));

      // Fields in Marathi
      expect(html, contains('पास क्रमांक:'));
      expect(html, contains('PASS-2026-002'));
      expect(html, contains('MH17PD2121'));
      expect(html, contains('दुचाकी'));
      expect(html, contains('Pawase Vaibhav'));
      expect(html, contains('30 सप्टेंबर 2026 → 29 ऑक्टोबर 2026'));
      expect(html, contains('पास रक्कम:'));
      expect(html, contains('₹600'));
      expect(html, contains('पेमेंट:'));
      expect(html, contains('भरलेले (रोख)'));
      expect(html, contains('वैधतेदरम्यान पार्किंग शुल्क:'));
      expect(html, contains('₹0'));
      expect(html, contains('धन्यवाद!'));

      // Footer branding in Marathi
      expect(html, contains('BIZFLOW द्वारे समर्थित'));
      expect(html, contains('CAR PARKING SYSTEM'));
    });

    test('3. Four-Wheeler UPI Pass in English and Marathi', () {
      final htmlEnglish = ReceiptPrintService.buildMonthlyPassReceiptHtml(
        testPassFourWheelerUpi,
        language: AppLanguage.english,
      );
      expect(htmlEnglish, contains('Four-Wheeler'));
      expect(htmlEnglish, contains('PAID (UPI)'));

      final htmlMarathi = ReceiptPrintService.buildMonthlyPassReceiptHtml(
        testPassFourWheelerUpi,
        language: AppLanguage.marathi,
      );
      expect(htmlMarathi, contains('चारचाकी'));
      expect(htmlMarathi, contains('भरलेले (UPI)'));
    });
  });

  group('Customer-Facing Monthly Pass WhatsApp Messaging Tests', () {
    test('1. English WhatsApp text matches exact branding structure', () {
      final msg = WhatsAppService.buildMonthlyPassMessage(
        testPassTwoWheelerCash,
        language: AppLanguage.english,
      );

      expect(msg, startsWith('JAY GANESH PAY & PARK\nMonthly Pass'));
      expect(msg, contains('Pass No: PASS-2026-002'));
      expect(msg, contains('Vehicle No: MH17PD2121'));
      expect(msg, contains('Vehicle Type: Two-Wheeler'));
      expect(msg, contains('Customer: Pawase Vaibhav'));
      expect(msg, contains('Validity: 30 Sep 2026 → 29 Oct 2026'));
      expect(msg, contains('Pass Amount: ₹600'));
      expect(msg, contains('Payment: PAID (CASH)'));
      expect(msg, contains('Parking Fee During Validity: ₹0'));
      expect(msg, contains('Thank You!'));
      expect(msg, contains('Powered by BIZFLOW\nCAR PARKING SYSTEM'));
    });

    test('2. Marathi WhatsApp text matches exact branding structure', () {
      final msg = WhatsAppService.buildMonthlyPassMessage(
        testPassTwoWheelerCash,
        language: AppLanguage.marathi,
      );

      expect(msg, startsWith('JAY GANESH PAY & PARK\nमासिक पास'));
      expect(msg, contains('पास क्र.: PASS-2026-002'));
      expect(msg, contains('वाहन क्र.: MH17PD2121'));
      expect(msg, contains('वाहन प्रकार: दुचाकी'));
      expect(msg, contains('ग्राहक: Pawase Vaibhav'));
      expect(msg, contains('वैधता: 30 सप्टेंबर 2026 → 29 ऑक्टोबर 2026'));
      expect(msg, contains('पास रक्कम: ₹600'));
      expect(msg, contains('पेमेंट: भरलेले (रोख)'));
      expect(msg, contains('वैधता कालावधीत पार्किंग शुल्क: ₹०'));
      expect(msg, contains('धन्यवाद!'));
      expect(msg, contains('BIZFLOW द्वारे समर्थित\nCAR PARKING SYSTEM'));
    });
  });
}
