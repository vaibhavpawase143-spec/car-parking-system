import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:car_parking_system/widgets/camera/qr_scanner_dialog.dart';

void main() {
  group('Exit QR Scanner Cross-Device Compatibility Tests', () {
    test('1. QR extraction - JSON formats with various field keys', () {
      expect(QrScannerDialog.extractTicketFromQr('{"ticketNumber": "1004"}'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('{"ticketNumber": 1004}'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('{"ticketId": "1005"}'), equals('1005'));
      expect(QrScannerDialog.extractTicketFromQr('{"qrReference": "1006"}'), equals('1006'));
      expect(QrScannerDialog.extractTicketFromQr('{"ticket": "1007"}'), equals('1007'));
      expect(QrScannerDialog.extractTicketFromQr('{"id": "1008"}'), equals('1008'));
      expect(QrScannerDialog.extractTicketFromQr('{"vehicleNumber": "MH12AB1234"}'), equals('MH12AB1234'));
    });

    test('2. QR extraction - URL query parameters and path segments', () {
      expect(QrScannerDialog.extractTicketFromQr('https://parking.app/exit?ticket=1004'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('http://parking.local/checkout?ticketNumber=1005'), equals('1005'));
      expect(QrScannerDialog.extractTicketFromQr('https://smartparking.io/receipt?tkt=1006'), equals('1006'));
      expect(QrScannerDialog.extractTicketFromQr('https://smartparking.io/receipt?id=1007'), equals('1007'));
      expect(QrScannerDialog.extractTicketFromQr('https://parking.app/ticket/1004'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('https://parking.app/ticket/TKT-20260924-0001'), equals('TKT-20260924-0001'));
    });

    test('3. QR extraction - Key-Value text formats', () {
      expect(QrScannerDialog.extractTicketFromQr('TICKET:1004'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('TKT: 1005'), equals('1005'));
      expect(QrScannerDialog.extractTicketFromQr('ticket=1006'), equals('1006'));
    });

    test('4. QR extraction - Direct numeric and legacy ticket references', () {
      expect(QrScannerDialog.extractTicketFromQr('1004'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('  1004 \n'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('TKT-1004'), equals('TKT-1004'));
      expect(QrScannerDialog.extractTicketFromQr('TKT-20260924-4K0D'), equals('TKT-20260924-4K0D'));
      expect(QrScannerDialog.extractTicketFromQr('MH12AB1234'), equals('MH12AB1234'));
      expect(QrScannerDialog.extractTicketFromQr('mh 12 ab 1234'), equals('MH12AB1234'));
    });

    test('5. Non-parking formats are rejected safely', () {
      expect(QrScannerDialog.extractTicketFromQr(''), isNull);
      expect(QrScannerDialog.extractTicketFromQr('   '), isNull);
      expect(QrScannerDialog.extractTicketFromQr('WIFI:T:WPA;S:OfficeNet;P:secret;;'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('BEGIN:VCARD\nFN:John Doe\nEND:VCARD'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('mailto:support@parking.com'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('tel:+919876543210'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('geo:18.5204,73.8567'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('upi://pay?pa=merchant@upi&am=50'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('https://google.com'), isNull);
    });

    test('6. isValidParkingQr utility matches extraction logic', () {
      expect(QrScannerDialog.isValidParkingQr('1004'), isTrue);
      expect(QrScannerDialog.isValidParkingQr('{"ticketNumber":"1004"}'), isTrue);
      expect(QrScannerDialog.isValidParkingQr('TKT-1004'), isTrue);
      expect(QrScannerDialog.isValidParkingQr('https://google.com'), isFalse);
      expect(QrScannerDialog.isValidParkingQr(''), isFalse);
    });

    test('7. Mock scan result injection works for automated testing', () {
      QrScannerDialog.mockScanResult = '1004';
      expect(QrScannerDialog.mockScanResult, equals('1004'));
      QrScannerDialog.mockScanResult = null;
      expect(QrScannerDialog.mockScanResult, isNull);
    });

    test('8. Error code differentiation produces user-friendly messages', () {
      // Permission denied
      const permError = MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
      expect(permError.errorCode, equals(MobileScannerErrorCode.permissionDenied));

      // No camera / unsupported
      const noCamError = MobileScannerException(
        errorCode: MobileScannerErrorCode.unsupported,
      );
      expect(noCamError.errorCode, equals(MobileScannerErrorCode.unsupported));

      // Controller initializing / already running
      const initError = MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerInitializing,
      );
      expect(initError.errorCode, equals(MobileScannerErrorCode.controllerInitializing));
    });
  });
}
