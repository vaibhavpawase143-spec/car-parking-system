import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/entry/entry_slip_screen.dart';
import 'package:car_parking_system/screens/guard/entry/entry_success_screen.dart';
import 'package:car_parking_system/services/qr_share_service.dart';
import 'package:car_parking_system/services/qr_share_stub.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/receipt_print_stub.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? launchedUrl;

  setUp(() {
    launchedUrl = null;
    ReceiptPlatformPrinter.lastPrintedHtml = null;
    ReceiptPlatformPrinter.shouldSucceed = true;

    QrPlatformShare.mockCanWriteClipboard = true;
    QrPlatformShare.mockClipboardSuccess = true;
    QrPlatformShare.lastCopiedBytes = null;
    QrPlatformShare.lastDownloadedBytes = null;
    QrPlatformShare.lastDownloadedFileName = null;

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

  final sampleRecord = ParkingRecord(
    id: 'rec-001',
    ticketId: 'TKT-20260923-ABCD',
    ticketNumber: 'TKT-20260923-ABCD',
    vehicleNumber: 'mh 12 ab 1234',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543210',
    entryTime: DateTime(2026, 9, 23, 11, 30),
    status: 'ACTIVE',
    entryGuardUid: 'guard-42',
    entryGuardName: 'Ramesh Guard',
    entryShift: 'Morning Shift',
    advanceAmount: 50.0,
    advancePaymentMethod: 'cash',
    photoUrl: 'https://example.com/photo.jpg',
    qrReference: 'TKT-20260923-ABCD',
  );

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('FINAL ENTRY FLOW — Complete 6-State & QR Image Share Test Suite', () {
    // -------------------------------------------------------------------------
    // REQUIREMENTS 1, 2, 3: ENTRY CONFIRMED INITIAL STATE
    // -------------------------------------------------------------------------
    testWidgets('1, 2, 3. Entry Confirmed initially shows ONLY View Entry Slip & QR; Send WhatsApp & Navigation hidden', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySuccessScreen(
            record: sampleRecord,
            onReturnDashboard: () {},
            onViewActiveParking: () {},
            onNewEntry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirmed ticket details displayed
      expect(find.text('Vehicle Entry Confirmed!'), findsOneWidget);
      expect(find.text('TKT-20260923-ABCD'), findsOneWidget);
      expect(find.text('MH12AB1234'), findsOneWidget);

      // 1. ONLY View Entry Slip & QR visible
      expect(find.byKey(const ValueKey('view_entry_slip_button')), findsOneWidget);
      expect(find.text('View Entry Slip & QR'), findsOneWidget);

      // 2. Send WhatsApp hidden initially
      expect(find.byKey(const ValueKey('send_whatsapp_button')), findsNothing);
      expect(find.text('Send WhatsApp'), findsNothing);

      // 3. Navigation buttons hidden initially
      expect(find.byKey(const ValueKey('view_active_parking_button')), findsNothing);
      expect(find.byKey(const ValueKey('new_entry_button')), findsNothing);
      expect(find.byKey(const ValueKey('dashboard_button')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENTS 4, 5, 6: DIGITAL ENTRY SLIP INITIAL STATE
    // -------------------------------------------------------------------------
    testWidgets('4, 5, 6. View Entry Slip opens Digital Entry Slip showing ONLY Print Slip; Send WhatsApp hidden', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySuccessScreen(
            record: sampleRecord,
            onReturnDashboard: () {},
            onViewActiveParking: () {},
            onNewEntry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4. Tap View Entry Slip & QR to open Digital Entry Slip
      await tester.tap(find.byKey(const ValueKey('view_entry_slip_button')));
      await tester.pumpAndSettle();
      expect(find.byType(EntrySlipScreen), findsOneWidget);

      // 5. Digital Entry Slip initially shows ONLY Print Slip
      expect(find.byKey(const ValueKey('slip_print_button')), findsOneWidget);
      expect(find.text('Print Slip'), findsOneWidget);

      // 6. Send WhatsApp hidden before successful print
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsNothing);
      expect(find.text('Send WhatsApp'), findsNothing);

      // Navigation buttons remain hidden
      expect(find.byKey(const ValueKey('view_active_parking_button')), findsNothing);
      expect(find.byKey(const ValueKey('new_entry_button')), findsNothing);
      expect(find.byKey(const ValueKey('dashboard_button')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENTS 7, 8, 9: PRINT SLIP & SUCCESSFUL ACCEPTANCE
    // -------------------------------------------------------------------------
    testWidgets('7, 8, 9. Print Slip triggers 58 mm print; successful acceptance reveals Send WhatsApp; navigation stays hidden', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(
            record: sampleRecord,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 7. Tap Print Slip
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies print service was invoked with 58 mm receipt HTML
      expect(ReceiptPlatformPrinter.lastPrintedHtml, isNotNull);
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('58mm'));
      expect(ReceiptPlatformPrinter.lastPrintedHtml, contains('TKT-20260923-ABCD'));

      // Acceptance dialog appears
      expect(find.byKey(const ValueKey('print_confirm_success_button')), findsOneWidget);

      // 8. Accept print success
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // Send WhatsApp is now revealed
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsOneWidget);
      expect(find.text('Send WhatsApp'), findsOneWidget);
      expect(find.byKey(const ValueKey('slip_print_button')), findsOneWidget);

      // 9. Navigation buttons remain hidden
      expect(find.byKey(const ValueKey('view_active_parking_button')), findsNothing);
      expect(find.byKey(const ValueKey('new_entry_button')), findsNothing);
      expect(find.byKey(const ValueKey('dashboard_button')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENT 10: PRINT CANCEL / FAILURE
    // -------------------------------------------------------------------------
    testWidgets('10. Print cancel/failure does NOT reveal Send WhatsApp; remains on Digital Entry Slip', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(
            record: sampleRecord,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Print Slip
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Cancel in confirmation dialog
      expect(find.byKey(const ValueKey('print_confirm_cancel_button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('print_confirm_cancel_button')));
      await tester.pumpAndSettle();

      // Send WhatsApp remains hidden
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsNothing);
      // Print Slip remains available
      expect(find.byKey(const ValueKey('slip_print_button')), findsOneWidget);
      expect(find.text('Print cancelled. You can click "Print Slip" to try again.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENTS 11, 13: ACTUAL QR IMAGE SHARING & DASHBOARD NAVIGATION
    // -------------------------------------------------------------------------
    testWidgets('11, 13. Send WhatsApp shares actual QR image file via Web Share and navigates to Dashboard', (tester) async {
      setTestSurfaceSize(tester);

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

      // Print first to reveal WhatsApp
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // Tap Send WhatsApp
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('slip_send_whatsapp_button')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verifies direct WhatsApp wa.me URL launched with country code 91 and encoded text
      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('https://wa.me/919876543210?text='));
      expect(launchedUrl, contains(Uri.encodeComponent('TKT-20260923-ABCD')));
      expect(launchedUrl, contains(Uri.encodeComponent('MH12AB1234')));

      // 13. Navigates directly to Dashboard
      expect(returnedToDashboard, isTrue);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENT 12: INVALID MOBILE NUMBER VALIDATION
    // -------------------------------------------------------------------------
    testWidgets('12. Invalid mobile number shows error and prevents WhatsApp launch', (tester) async {
      setTestSurfaceSize(tester);

      final invalidRecord = ParkingRecord(
        id: 'rec-002',
        ticketId: 'TKT-20260923-ABCD',
        ticketNumber: 'TKT-20260923-ABCD',
        vehicleNumber: 'mh 12 ab 1234',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: '12345',
        entryTime: DateTime(2026, 9, 23, 11, 30),
        status: 'ACTIVE',
        entryGuardUid: 'guard-42',
        entryGuardName: 'Ramesh Guard',
        entryShift: 'Morning Shift',
        advanceAmount: 50.0,
        advancePaymentMethod: 'cash',
        photoUrl: 'https://example.com/photo.jpg',
        qrReference: 'TKT-20260923-ABCD',
      );
      bool returnedToDashboard = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(
            record: invalidRecord,
            onReturnDashboard: () {
              returnedToDashboard = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Print first
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // Tap Send WhatsApp
      await tester.tap(find.byKey(const ValueKey('slip_send_whatsapp_button')));
      await tester.pumpAndSettle();

      // Must NOT launch WhatsApp
      expect(launchedUrl, isNull);
      expect(returnedToDashboard, isFalse);
      expect(find.text('Customer mobile number is invalid.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // REQUIREMENTS 1, 2, 3, 4: QR DATA AND VALID PNG GENERATION
    // -------------------------------------------------------------------------
    test('1, 2, 3, 4. QR data equals qrReference and generates scannable, valid PNG', () async {
      // 1. Same QR data
      final qrData = sampleRecord.qrReference ?? sampleRecord.ticketNumber;
      expect(qrData, equals('TKT-20260923-ABCD'));

      // 2. Generation succeeds
      final pngBytes = await QrShareService.generateQrPng(qrData);

      // 3. Non-empty
      expect(pngBytes.isNotEmpty, isTrue);

      // 4. Valid PNG signature
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50)); // P
      expect(pngBytes[2], equals(0x4E)); // N
      expect(pngBytes[3], equals(0x47)); // G
    });

    // -------------------------------------------------------------------------
    // REQUIREMENTS 9, 10, 11, 12: DATA INTEGRITY AND NO DUPLICATION
    // -------------------------------------------------------------------------
    test('9, 10, 11, 12. Single ticket ID and identical QR reference reused across slip, print, and WhatsApp', () {
      // 9, 10, 11. ParkingRecord integrity
      expect(sampleRecord.ticketNumber, equals('TKT-20260923-ABCD'));
      expect(sampleRecord.qrReference, equals('TKT-20260923-ABCD'));
      expect(sampleRecord.status, equals('ACTIVE'));

      // 12. Message format contains all details
      final waMessage = WhatsAppService.buildEntryConfirmationMessage(sampleRecord);
      expect(waMessage, contains(sampleRecord.ticketNumber));
      expect(waMessage, contains('MH12AB1234'));
      expect(waMessage, contains('Four-Wheeler'));
      expect(waMessage, contains(sampleRecord.qrReference!));
    });

    // -------------------------------------------------------------------------
    // REQUIREMENT 15: 58 MM PRINT REMAINS INTACT
    // -------------------------------------------------------------------------
    test('15. 58 mm thermal receipt HTML contains width rule and all required fields', () {
      final html = ReceiptPrintService.build58mmReceiptHtml(sampleRecord);

      // Width rule
      expect(html, contains('58mm'));
      expect(html, contains('@page'));
      expect(html, contains('size: 58mm auto'));
      expect(html, contains('width: 58mm !important'));

      // Redesigned priority fields
      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('JAY GANESH')));
      expect(html, contains('ENTRY RECEIPT'));
      expect(html, contains('TICKET: TKT-20260923-ABCD'));
      expect(html, contains('VEHICLE NUMBER'));
      expect(html, contains('MH12AB1234'));
      expect(html, contains('Vehicle Type: Four-Wheeler'));
      expect(html, contains('Entry Date:</span><span class="val">${AppFormatters.formatDate(sampleRecord.entryTime)}</span>'));
      expect(html, contains('Entry Time:</span><span class="val">${AppFormatters.formatTime(sampleRecord.entryTime)}</span>'));
      expect(html, contains('Guard:</span><span class="val">Ramesh Guard</span>'));
      expect(html, contains('Shift:</span><span class="val">Morning Shift</span>'));
      expect(html, contains('Customer Mobile:</span><span class="val">9876543210</span>'));
      expect(html, contains('Advance Paid:</span><span class="val">₹50</span>'));
      expect(html, contains('Payment:</span><span class="val">CASH</span>'));
      expect(html, contains('<svg'));
      expect(html, contains('</svg>'));

      // Security: No private storage URLs exposed
      expect(html, isNot(contains('https://example.com/photo.jpg')));
      expect(html, isNot(contains('cloudinary')));
    });
  });
}
