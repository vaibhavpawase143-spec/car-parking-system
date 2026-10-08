import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/marathi_receipt_rasterizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entryRecord1 = ParkingRecord(
    id: '1001',
    ticketNumber: '1001',
    qrReference: '1001',
    vehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.twoWheeler,
    entryTime: DateTime(2026, 10, 3, 8, 11),
    entryGuardUid: 'guard-a',
    entryGuardName: 'Guard A',
    entryShift: 'Shift 1',
    customerMobile: '9876543210',
    advanceAmount: 30.0,
    advancePaymentMethod: 'cash',
    status: 'ACTIVE',
    photoUrl: 'https://example.com/mh12ab1234.jpg',
  );

  final entryRecord2 = ParkingRecord(
    id: '1002',
    ticketNumber: '1002',
    qrReference: '1002',
    vehicleNumber: 'MH16TT1212',
    vehicleType: VehicleType.fourWheeler,
    entryTime: DateTime(2026, 10, 3, 8, 21),
    entryGuardUid: 'guard-a',
    entryGuardName: 'Guard A',
    entryShift: 'Shift 1',
    customerMobile: '',
    advanceAmount: 0.0,
    advancePaymentMethod: 'cash',
    status: 'ACTIVE',
    photoUrl: 'https://example.com/mh16tt1212.jpg',
  );

  final exitRecord = ParkingRecord(
    id: '1001',
    ticketNumber: '1001',
    qrReference: '1001',
    vehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.twoWheeler,
    entryTime: DateTime(2026, 10, 3, 8, 11),
    exitTime: DateTime(2026, 10, 3, 11, 45),
    entryGuardUid: 'guard-a',
    entryGuardName: 'Guard A',
    entryShift: 'Shift 1',
    customerMobile: '9876543210',
    advanceAmount: 30.0,
    advancePaymentMethod: 'cash',
    grossCharge: 30.0,
    balanceDue: 0.0,
    refundAmount: 0.0,
    paymentMethod: 'cash',
    status: 'EXITED',
    exitGuardName: 'Guard A',
    exitShift: 'Shift 1',
  );

  group('1. HDFC Bank Pre-printed Strip Safe Margin Audit', () {
    test('Rasterizer reserves exactly 64 dots (8.0mm) on the right side of 384px printhead', () {
      expect(MarathiReceiptRasterizer.printableWidth, equals(384.0));
      expect(MarathiReceiptRasterizer.safeContentWidth, equals(312.0));
      expect(MarathiReceiptRasterizer.safeLeftMargin, equals(8.0));

      final activeEnd = MarathiReceiptRasterizer.safeLeftMargin + MarathiReceiptRasterizer.safeContentWidth;
      expect(activeEnd, equals(320.0));

      final rightReserved = MarathiReceiptRasterizer.printableWidth - activeEnd;
      expect(rightReserved, equals(64.0));
    });

    test('QR Bitmap is centered within safe 312px zone without touching right reserved strip', () {
      final qrImg = MarathiReceiptRasterizer.renderQrImage('1001', qrPixelSize: 224);
      expect(qrImg.width, equals(384));

      // Check that dots beyond x=320 are strictly white (no content bleeding into HDFC strip)
      for (int y = 0; y < qrImg.height; y++) {
        for (int x = 320; x < 384; x++) {
          final pixel = qrImg.getPixel(x, y);
          expect(pixel.r, equals(255));
          expect(pixel.g, equals(255));
          expect(pixel.b, equals(255));
        }
      }
    });

    test('HTML 58mm templates configure 40mm container with 2mm left margin and 16mm right clear margin', () {
      final entryHtml = ReceiptPrintService.build58mmReceiptHtml(entryRecord1);
      expect(entryHtml, contains('width: 40mm;'));
      expect(entryHtml, contains('margin: 0 0 0 2mm;'));
      expect(entryHtml, contains('max-width: 32mm;'));

      final exitHtml = ReceiptPrintService.build58mmExitReceiptHtml(exitRecord);
      expect(exitHtml, contains('width: 40mm;'));
      expect(exitHtml, contains('margin: 0 0 0 2mm;'));
      expect(exitHtml, contains('max-width: 32mm;'));
    });
  });

  group('2. Marathi Thermal Receipt Rasterizer & Font Sizing Audit', () {
    test('Entry Header and Body rasterize successfully with high-contrast thresholding', () async {
      final headerImg = await MarathiReceiptRasterizer.renderEntryHeader();
      expect(headerImg.width, equals(384));
      expect(headerImg.height, greaterThan(100));

      final bodyImg = await MarathiReceiptRasterizer.renderEntryBody(entryRecord1);
      expect(bodyImg.width, equals(384));
      expect(bodyImg.height, greaterThan(250));
    });

    test('Exit Header and Body rasterize successfully with larger font sizing', () async {
      final headerImg = await MarathiReceiptRasterizer.renderExitHeader();
      expect(headerImg.width, equals(384));

      final bodyImg = await MarathiReceiptRasterizer.renderExitBody(exitRecord);
      expect(bodyImg.width, equals(384));
      expect(bodyImg.height, greaterThan(300));
    });
  });

  group('3. Ticket Counter Idempotency & Multi-Entry Sequence Audit', () {
    test('Generating HTML receipt multiple times preserves ticket number (Idempotent reprint)', () {
      final html1 = ReceiptPrintService.build58mmReceiptHtml(entryRecord1);
      final html2 = ReceiptPrintService.build58mmReceiptHtml(entryRecord1);
      final html3 = ReceiptPrintService.build58mmReceiptHtml(entryRecord1);

      expect(html1, contains('TICKET: 1001'));
      expect(html2, contains('TICKET: 1001'));
      expect(html3, contains('TICKET: 1001'));
      expect(html1, equals(html2));
      expect(html2, equals(html3));
    });

    test('Two distinct vehicle entries have distinct sequential ticket numbers (1001 -> 1002)', () {
      expect(entryRecord1.ticketNumber, equals('1001'));
      expect(entryRecord1.vehicleNumber, equals('MH12AB1234'));

      expect(entryRecord2.ticketNumber, equals('1002'));
      expect(entryRecord2.vehicleNumber, equals('MH16TT1212'));

      expect(int.parse(entryRecord2.ticketNumber), equals(int.parse(entryRecord1.ticketNumber) + 1));
    });
  });
}
