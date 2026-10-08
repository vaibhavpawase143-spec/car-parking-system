import 'package:flutter_test/flutter_test.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/marathi_receipt_rasterizer.dart';

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

  group('MarathiReceiptRasterizer & ESC/POS Integration Tests', () {
    test('1. Renders Entry Header image with 384px width', () async {
      final img = await MarathiReceiptRasterizer.renderEntryHeader();
      expect(img.width, equals(384));
      expect(img.height, greaterThan(100));

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.imageRaster(img);
      expect(bytes, isNotEmpty);
    });

    test('2. Renders Entry Body image with 384px width', () async {
      final img = await MarathiReceiptRasterizer.renderEntryBody(sampleRecord);
      expect(img.width, equals(384));
      expect(img.height, greaterThan(200));

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.imageRaster(img);
      expect(bytes, isNotEmpty);
    });

    test('3. Renders Exit Header & Body images', () async {
      final headerImg = await MarathiReceiptRasterizer.renderExitHeader();
      expect(headerImg.width, equals(384));

      final bodyImg = await MarathiReceiptRasterizer.renderExitBody(sampleExitRecord);
      expect(bodyImg.width, equals(384));
      expect(bodyImg.height, greaterThan(200));

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.imageRaster(bodyImg);
      expect(bytes, isNotEmpty);
    });

    test('4. Renders BizFlow Branding Footer for Marathi and English', () async {
      final marathiFooter = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.marathi);
      expect(marathiFooter.width, equals(384));

      final englishFooter = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.english);
      expect(englishFooter.width, equals(384));
    });

    test('5. Renders 28mm prominent QR image bitmap (224x224 dots centered in safe width on 384px)', () {
      final qrImg = MarathiReceiptRasterizer.renderQrImage('1005', qrPixelSize: 224);
      expect(qrImg.width, equals(384));
      expect(qrImg.height, equals(240)); // 224 + 16 padding
    });

    test('6. Verifies safeContentWidth (312px) reserves right margin on 384px printhead for HDFC strip', () {
      expect(MarathiReceiptRasterizer.printableWidth, equals(384.0));
      expect(MarathiReceiptRasterizer.safeContentWidth, equals(312.0));
      expect(MarathiReceiptRasterizer.safeLeftMargin, equals(8.0));
      // Content ends at 8 + 312 = 320, leaving 64px (8mm) clear right margin
      final rightMargin = MarathiReceiptRasterizer.printableWidth -
          (MarathiReceiptRasterizer.safeLeftMargin + MarathiReceiptRasterizer.safeContentWidth);
      expect(rightMargin, equals(64.0));
    });

    test('7. Renders Marathi Monthly Pass Slip image with 384px width', () async {
      final samplePass = MonthlyPassModel(
        id: 'pass-test-1',
        passNumber: 'MP-2026-0001',
        vehicleNumber: 'MH14AA1111',
        normalizedVehicleNumber: 'MH14AA1111',
        vehicleType: VehicleType.fourWheeler,
        customerName: 'Rahul Patil',
        customerMobile: '9876543210',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'cash',
        createdAt: DateTime(2026, 10, 1),
        createdBy: 'Admin',
      );

      final passImg = await MarathiReceiptRasterizer.renderMonthlyPassSlip(samplePass);
      expect(passImg.width, equals(384));
      expect(passImg.height, greaterThan(250));

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.imageRaster(passImg);
      expect(bytes, isNotEmpty);
    });
  });
}
