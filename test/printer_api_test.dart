import 'package:flutter_test/flutter_test.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRecord = ParkingRecord(
    id: 'rec-101',
    ticketNumber: '1005',
    vehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543210',
    entryTime: DateTime(2026, 9, 24, 10, 0),
    exitTime: DateTime(2026, 9, 24, 12, 30),
    status: 'EXITED',
    entryGuardUid: 'g1',
    entryGuardName: 'Ramesh Guard',
    entryShift: 'Shift 1',
    advanceAmount: 50.0,
    advancePaymentMethod: 'cash',
    grossCharge: 80.0,
    balanceDue: 30.0,
    refundAmount: 0.0,
    paymentMethod: 'cash',
    exitGuardName: 'Suresh Guard',
    exitShift: 'Shift 1',
  );

  group('Bluetooth Thermal Printer (MPT-II 58mm) & ESC/POS Tests', () {
    test('1. Verify PrintBluetoothThermal and esc_pos_utils_plus API signatures', () async {
      expect(PrintBluetoothThermal.bluetoothEnabled, isNotNull);
      expect(PrintBluetoothThermal.connectionStatus, isNotNull);
      expect(PrintBluetoothThermal.isPermissionBluetoothGranted, isNotNull);
      expect(PrintBluetoothThermal.connect, isNotNull);
      expect(PrintBluetoothThermal.disconnect, isNotNull);
      expect(PrintBluetoothThermal.writeBytes, isNotNull);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];
      bytes.addAll(generator.text('CAR PARKING SYSTEM', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.qrcode('1005', size: QRSize.size4, cor: QRCorrection.M, align: PosAlign.center));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());
      expect(bytes, isNotEmpty);
    });

    test('2. ReceiptPlatformPrinter connection lifecycle', () async {
      expect(ReceiptPlatformPrinter.connectionState, isNotNull);

      // Simulation on test host
      final connected = await ReceiptPlatformPrinter.connect('00:11:22:33:44:55', printerName: 'MPT-II');
      expect(connected, isTrue);
      expect(ReceiptPlatformPrinter.savedMacAddress, equals('00:11:22:33:44:55'));
      expect(ReceiptPlatformPrinter.savedPrinterName, equals('MPT-II'));
      expect(ReceiptPlatformPrinter.connectionState, equals(BluetoothPrinterState.connected));

      final disconnected = await ReceiptPlatformPrinter.disconnect();
      expect(disconnected, isTrue);
      expect(ReceiptPlatformPrinter.connectionState, equals(BluetoothPrinterState.disconnected));
    });

    test('3. ReceiptPlatformPrinter printEntrySlip & printExitReceipt simulation', () async {
      ReceiptPlatformPrinter.shouldSucceed = true;

      final entryPrinted = await ReceiptPrintService.print58mmEntrySlip(sampleRecord);
      expect(entryPrinted, isTrue);
      expect(ReceiptPlatformPrinter.lastPrintedHtml, isNotNull);
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('58mm'));
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('1005'));
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('MH12AB1234'));

      final exitPrinted = await ReceiptPrintService.print58mmExitReceipt(sampleRecord);
      expect(exitPrinted, isTrue);
      expect(ReceiptPlatformPrinter.lastPrintedHtml, isNotNull);
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('EXIT RECEIPT'));
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('1005'));
    });

    test('4. Web HTML generation remains intact and unchanged', () {
      final entryHtml = ReceiptPrintService.build58mmReceiptHtml(sampleRecord);
      expect(entryHtml, contains('CAR PARKING SYSTEM'));
      expect(entryHtml, isNot(contains('JAY GANESH')));
      expect(entryHtml, contains('ENTRY RECEIPT'));
      expect(entryHtml, contains('TICKET: 1005'));
      expect(entryHtml, contains('58mm'));
      expect(entryHtml, contains('width: 58mm !important'));

      final exitHtml = ReceiptPrintService.build58mmExitReceiptHtml(sampleRecord);
      expect(exitHtml, contains('CAR PARKING SYSTEM'));
      expect(exitHtml, isNot(contains('JAY GANESH')));
      expect(exitHtml, contains('EXIT RECEIPT'));
      expect(exitHtml, contains('58mm'));
      expect(exitHtml, contains('TOTAL AMOUNT'));
      expect(exitHtml, contains('Advance Paid:'));
      expect(exitHtml, contains('Advance Adjusted:'));
      expect(exitHtml, contains('BALANCE DUE:'));
    });
  });
}
