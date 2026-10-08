import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';

void main() {
  test('Generate realistic sample receipt HTML files', () {
    final record1 = ParkingRecord(
      id: 'test-1',
      ticketId: 'TKT-20260923-T26V',
      ticketNumber: 'TKT-20260923-T26V',
      vehicleNumber: 'MH20AS8471',
      vehicleType: VehicleType.fourWheeler,
      customerMobile: '7666084107',
      entryTime: DateTime(2026, 9, 23, 13, 58),
      status: 'ACTIVE',
      entryGuardUid: 'guard-1',
      entryGuardName: 'Guard Officer',
      entryShift: 'Shift 1 (08:00 - 16:00)',
      advanceAmount: 100.0,
      advancePaymentMethod: 'cash',
      photoUrl: 'https://example.com/p1.jpg',
      qrReference: 'TKT-20260923-T26V',
    );

    final record2 = ParkingRecord(
      id: 'test-2',
      ticketId: 'TKT-20260923-T26V',
      ticketNumber: 'TKT-20260923-T26V',
      vehicleNumber: 'MH20AS8471',
      vehicleType: VehicleType.twoWheeler,
      customerMobile: '7666084107',
      entryTime: DateTime(2026, 9, 23, 13, 58),
      status: 'ACTIVE',
      entryGuardUid: 'guard-1',
      entryGuardName: 'Guard Officer Long Name Extra',
      entryShift: 'Shift 1 (08:00 - 16:00)',
      advanceAmount: 0.0,
      advancePaymentMethod: 'none',
      photoUrl: 'https://example.com/p2.jpg',
      qrReference: 'TKT-20260923-T26V',
    );

    final html1 = ReceiptPrintService.build58mmReceiptHtml(record1);
    final html2 = ReceiptPrintService.build58mmReceiptHtml(record2);

    expect(html1, contains('40mm'));
    expect(html1, contains('MH20AS8471'));
    expect(html1, contains('TKT-20260923-T26V'));
    expect(html1, contains('Guard Officer'));
    expect(html1, contains('Shift 1 (08:00 - 16:00)'));
    expect(html1, contains('7666084107'));
    expect(html1, contains('₹100'));
    expect(html1, contains('CASH'));

    expect(html2, contains('Two-Wheeler'));
    expect(html2, contains('₹0'));
    expect(html2, contains('None'));

    Directory('build/web/receipt_preview').createSync(recursive: true);
    File('build/web/receipt_preview/sample1.html').writeAsStringSync(html1);
    File('build/web/receipt_preview/sample2.html').writeAsStringSync(html2);
    Directory('web/receipt_preview').createSync(recursive: true);
    File('web/receipt_preview/sample1.html').writeAsStringSync(html1);
    File('web/receipt_preview/sample2.html').writeAsStringSync(html2);
  });
}
