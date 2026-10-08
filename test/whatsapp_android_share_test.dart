import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/entry/entry_slip_screen.dart';
import 'package:car_parking_system/services/receipt_print_stub.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? launchedUrl;

  final sampleRecord = ParkingRecord(
    id: 'rec-wa-001',
    ticketId: 'TKT-20260924-1004',
    ticketNumber: '1004',
    vehicleNumber: 'MH 12 BB 2333',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543210',
    entryTime: DateTime(2026, 9, 24, 13, 30),
    status: 'ACTIVE',
    entryGuardUid: 'guard-01',
    entryGuardName: 'Test Guard',
    entryShift: 'General',
    advanceAmount: 50.0,
    advancePaymentMethod: 'cash',
    photoUrl: 'https://example.com/photo.jpg',
    qrReference: '1004',
  );

  setUp(() {
    launchedUrl = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'canLaunch') {
          return true;
        }
        if (methodCall.method == 'launch') {
          launchedUrl = methodCall.arguments['url'] as String?;
          return true;
        }
        return null;
      },
    );
  });

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('WhatsApp Text-Only Sharing Tests', () {
    test('1. Validates Indian mobile number format', () {
      expect(WhatsAppService.isValidCustomerMobile('9876543210'), isTrue);
      expect(WhatsAppService.isValidCustomerMobile('8123456789'), isTrue);
      expect(WhatsAppService.isValidCustomerMobile('7000000000'), isTrue);
      expect(WhatsAppService.isValidCustomerMobile('6999999999'), isTrue);

      expect(WhatsAppService.isValidCustomerMobile('5123456789'), isFalse);
      expect(WhatsAppService.isValidCustomerMobile('12345'), isFalse);
      expect(WhatsAppService.isValidCustomerMobile(''), isFalse);
      expect(WhatsAppService.isValidCustomerMobile(null), isFalse);
      expect(WhatsAppService.isValidCustomerMobile('98765432101'), isFalse);
    });

    test('2. Builds correct entry confirmation text message', () {
      final message = WhatsAppService.buildEntryConfirmationMessage(sampleRecord);
      expect(message, contains('Car Parking Entry Confirmation'));
      expect(message, contains('Ticket No: 1004'));
      expect(message, contains('Vehicle No: MH12BB2333'));
      expect(message, contains('Vehicle Type: Four-Wheeler'));
      expect(message, contains('Advance Paid: ₹50 (CASH)'));
      expect(message, contains('QR / Entry Slip:\n1004'));
      // Confirm NO image or attachment references in the message
      expect(message.contains('.png'), isFalse);
      expect(message.contains('Ctrl+V'), isFalse);
    });

    test('3. Builds correct wa.me text URL with customer mobile and encoded message', () {
      final url = WhatsAppService.buildClickToChatUrl(sampleRecord);
      expect(url, startsWith('https://wa.me/919876543210?text='));
      expect(url, contains(Uri.encodeComponent('Ticket No: 1004')));
      expect(url, contains(Uri.encodeComponent('MH12BB2333')));
    });

    testWidgets('4. EntrySlipScreen Send WhatsApp launches text-only chat and navigates to Dashboard', (tester) async {
      setTestSurfaceSize(tester);
      ReceiptPlatformPrinter.shouldSucceed = true;

      bool returnedToDashboard = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(
            record: sampleRecord,
            onReturnDashboard: () {
              returnedToDashboard = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Print first to reveal WhatsApp button
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // Tap Send WhatsApp with runAsync
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('slip_send_whatsapp_button')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verifies wa.me launched with pre-filled text
      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('https://wa.me/919876543210?text='));
      expect(launchedUrl, contains(Uri.encodeComponent('Ticket No: 1004')));

      // Verifies NO Ctrl+V or image copy snackbars appear
      expect(find.textContaining('Ctrl+V'), findsNothing);
      expect(find.textContaining('QR image copied'), findsNothing);
      expect(find.textContaining('Clipboard Image Unsupported'), findsNothing);

      // Verifies navigated to Dashboard
      expect(returnedToDashboard, isTrue);
    });
  });
}
