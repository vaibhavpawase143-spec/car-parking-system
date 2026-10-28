import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/entry/entry_slip_screen.dart';
import 'package:car_parking_system/screens/guard/entry/vehicle_entry_screen.dart';
import 'package:car_parking_system/screens/guard/exit/exit_receipt_screen.dart';
import 'package:car_parking_system/services/ocr/plate_ocr_service.dart';
import 'package:car_parking_system/services/plate_scanner_service.dart';
import 'package:car_parking_system/services/receipt_print_stub.dart';
import 'package:car_parking_system/services/settings_service.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';
import 'package:car_parking_system/widgets/camera/web_camera_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? launchedUrl;

  setUp(() {
    launchedUrl = null;
    ReceiptPlatformPrinter.shouldSucceed = true;
    VehicleEntryScreen.resetTestMocks();
    PlateScannerService.resetMocks();
    PlateOcrService.resetMocks();
    WebCameraPlatform.resetMocks();

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

  tearDown(() {
    VehicleEntryScreen.resetTestMocks();
    PlateScannerService.resetMocks();
    PlateOcrService.resetMocks();
    WebCameraPlatform.resetMocks();
  });

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  ParkingRecord createRecord({required String customerMobile}) {
    return ParkingRecord(
      id: 'rec-test-wa',
      ticketId: 'TKT-TEST-1001',
      ticketNumber: '1001',
      vehicleNumber: 'MH 12 AB 1234',
      vehicleType: VehicleType.fourWheeler,
      customerMobile: customerMobile,
      entryTime: DateTime(2026, 9, 24, 10, 0),
      status: 'ACTIVE',
      entryGuardUid: 'guard-01',
      entryGuardName: 'Test Guard',
      entryShift: 'General',
      advanceAmount: 50.0,
      advancePaymentMethod: 'CASH',
      qrReference: '1001',
      grossCharge: 80.0,
      balanceDue: 30.0,
      exitTime: DateTime(2026, 9, 24, 12, 0),
      exitGuardName: 'Exit Guard',
      exitShift: 'Shift 1',
    );
  }

  final testGuard = GuardModel(
    uid: 'guard-test-01',
    name: 'Santosh Guard',
    email: 'santosh@parking.biz',
    mobile: '9876543210',
    isActive: true,
  );

  group('1. WhatsAppService Validation & URL Generation Rules', () {
    test('hasCustomerMobile returns false for null, empty, or whitespace-only strings', () {
      expect(WhatsAppService.hasCustomerMobile(null), isFalse);
      expect(WhatsAppService.hasCustomerMobile(''), isFalse);
      expect(WhatsAppService.hasCustomerMobile('   '), isFalse);
      expect(WhatsAppService.hasCustomerMobile('\t\n'), isFalse);

      expect(WhatsAppService.hasCustomerMobile('9876543210'), isTrue);
      expect(WhatsAppService.hasCustomerMobile('  9876543210  '), isTrue);
    });

    test('hasValidCustomerMobile strictly validates Indian 10-digit mobile number', () {
      expect(WhatsAppService.hasValidCustomerMobile(null), isFalse);
      expect(WhatsAppService.hasValidCustomerMobile(''), isFalse);
      expect(WhatsAppService.hasValidCustomerMobile('   '), isFalse);
      expect(WhatsAppService.hasValidCustomerMobile('12345'), isFalse);
      expect(WhatsAppService.hasValidCustomerMobile('5123456789'), isFalse);
      expect(WhatsAppService.hasValidCustomerMobile('98765432101'), isFalse);

      expect(WhatsAppService.hasValidCustomerMobile('9876543210'), isTrue);
      expect(WhatsAppService.hasValidCustomerMobile('8123456789'), isTrue);
      expect(WhatsAppService.hasValidCustomerMobile('7000000000'), isTrue);
      expect(WhatsAppService.hasValidCustomerMobile('6999999999'), isTrue);
    });

    test('buildClickToChatUrl returns empty string when customer mobile is missing or whitespace', () {
      final emptyRecord = createRecord(customerMobile: '');
      expect(WhatsAppService.buildClickToChatUrl(emptyRecord), equals(''));

      final spacesRecord = createRecord(customerMobile: '   ');
      expect(WhatsAppService.buildClickToChatUrl(spacesRecord), equals(''));

      final validRecord = createRecord(customerMobile: '9876543210');
      expect(WhatsAppService.buildClickToChatUrl(validRecord), startsWith('https://wa.me/919876543210?text='));
    });

    test('buildExitClickToChatUrl returns empty string when customer mobile is missing or whitespace', () {
      final emptyRecord = createRecord(customerMobile: '');
      expect(WhatsAppService.buildExitClickToChatUrl(emptyRecord), equals(''));

      final spacesRecord = createRecord(customerMobile: '   ');
      expect(WhatsAppService.buildExitClickToChatUrl(spacesRecord), equals(''));

      final validRecord = createRecord(customerMobile: '9876543210');
      expect(WhatsAppService.buildExitClickToChatUrl(validRecord), startsWith('https://wa.me/919876543210?text='));
    });

    test('shareMonthlyPassConfirmation returns false when pass mobile is missing or spaces', () async {
      final emptyPass = MonthlyPassModel(
        id: 'pass-01',
        passNumber: 'MP-001',
        vehicleNumber: 'MH12AB1234',
        normalizedVehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        customerName: 'Kunal Test',
        customerMobile: '   ',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        amount: 600,
        paymentMethod: 'CASH',
        paymentStatus: 'PAID',
        createdBy: 'guard-01',
        createdAt: DateTime.now(),
      );

      final opened = await WhatsAppService.shareMonthlyPassConfirmation(emptyPass);
      expect(opened, isFalse);
      expect(launchedUrl, isNull);
    });
  });

  group('2. EntrySlipScreen WhatsApp Option Visibility', () {
    testWidgets('EntrySlipScreen HIDES WhatsApp button completely when customer mobile is empty', (tester) async {
      setTestSurfaceSize(tester);

      final emptyRecord = createRecord(customerMobile: '');

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(record: emptyRecord),
        ),
      );
      await tester.pumpAndSettle();

      // Complete print
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // WhatsApp option must NOT be rendered at all
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsNothing);
      expect(find.text(AppStrings.sendWhatsApp), findsNothing);
      expect(find.text(AppStrings.opensWhatsAppNotice), findsNothing);
    });

    testWidgets('EntrySlipScreen HIDES WhatsApp button completely when customer mobile contains only spaces', (tester) async {
      setTestSurfaceSize(tester);

      final spacesRecord = createRecord(customerMobile: '    ');

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(record: spacesRecord),
        ),
      );
      await tester.pumpAndSettle();

      // Complete print
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // WhatsApp option must NOT be rendered at all
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsNothing);
      expect(find.text(AppStrings.sendWhatsApp), findsNothing);
    });

    testWidgets('EntrySlipScreen SHOWS WhatsApp button when valid mobile is available and launches WhatsApp', (tester) async {
      setTestSurfaceSize(tester);

      final validRecord = createRecord(customerMobile: '9876543210');

      await tester.pumpWidget(
        MaterialApp(
          home: EntrySlipScreen(record: validRecord),
        ),
      );
      await tester.pumpAndSettle();

      // Complete print
      await tester.tap(find.byKey(const ValueKey('slip_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('print_confirm_success_button')));
      await tester.pumpAndSettle();

      // WhatsApp option IS visible
      expect(find.byKey(const ValueKey('slip_send_whatsapp_button')), findsOneWidget);
      expect(find.text(AppStrings.sendWhatsApp), findsOneWidget);

      // Tap Send WhatsApp launches correctly
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('slip_send_whatsapp_button')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('https://wa.me/919876543210?text='));
    });
  });

  group('3. ExitReceiptScreen WhatsApp Option Visibility', () {
    testWidgets('ExitReceiptScreen HIDES WhatsApp button completely when customer mobile is empty', (tester) async {
      setTestSurfaceSize(tester);

      final emptyRecord = createRecord(customerMobile: '');

      await tester.pumpWidget(
        MaterialApp(
          home: ExitReceiptScreen(
            record: emptyRecord,
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Print button is present, WhatsApp button is NOT present
      expect(find.byKey(const ValueKey('print_exit_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('exit_send_whatsapp_button')), findsNothing);
      expect(find.text(AppStrings.sendWhatsApp), findsNothing);
    });

    testWidgets('ExitReceiptScreen HIDES WhatsApp button completely when customer mobile is only spaces', (tester) async {
      setTestSurfaceSize(tester);

      final spacesRecord = createRecord(customerMobile: '   ');

      await tester.pumpWidget(
        MaterialApp(
          home: ExitReceiptScreen(
            record: spacesRecord,
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('exit_send_whatsapp_button')), findsNothing);
    });

    testWidgets('ExitReceiptScreen SHOWS WhatsApp button when valid mobile is available and opens WhatsApp', (tester) async {
      setTestSurfaceSize(tester);

      final validRecord = createRecord(customerMobile: '9876543210');

      await tester.pumpWidget(
        MaterialApp(
          home: ExitReceiptScreen(
            record: validRecord,
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // WhatsApp option IS visible
      expect(find.byKey(const ValueKey('exit_send_whatsapp_button')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('exit_send_whatsapp_button')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('https://wa.me/919876543210?text='));
    });
  });

  group('4. SystemSettingsModel & Firestore Deserialization Rules', () {
    test('Default SystemSettingsModel constructor has requireCustomerMobile = false', () {
      const defaultSettings = SystemSettingsModel();
      expect(defaultSettings.requireCustomerMobile, isFalse);
    });

    test('SystemSettingsModel.fromMap without requireCustomerMobile defaults to false', () {
      final settings = SystemSettingsModel.fromMap({
        'englishName': 'CAR PARKING SYSTEM',
        'carTotalCapacity': 50,
      });
      expect(settings.requireCustomerMobile, isFalse);
    });

    test('SystemSettingsModel.fromMap with requireCustomerMobile = true parses true', () {
      final settings = SystemSettingsModel.fromMap({
        'requireCustomerMobile': true,
      });
      expect(settings.requireCustomerMobile, isTrue);
    });

    test('SystemSettingsModel.fromMap with requireCustomerMobile = false parses false', () {
      final settings = SystemSettingsModel.fromMap({
        'requireCustomerMobile': false,
      });
      expect(settings.requireCustomerMobile, isFalse);
    });
  });

  group('5. VehicleEntryScreen requireCustomerMobile Admin Setting Enforcement', () {
    testWidgets('requireCustomerMobile OFF allows vehicle entry with empty mobile number', (tester) async {
      setTestSurfaceSize(tester);

      SettingsService.instance.setMockSettings(
        const SystemSettingsModel(
          requireCustomerMobile: false,
          requirePlatePhoto: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Asterisk is NOT shown on customer mobile label when requireCustomerMobile is OFF
      expect(find.text('3. ${AppStrings.customerMobile}'), findsOneWidget);
      expect(find.text('3. ${AppStrings.customerMobile} *'), findsNothing);

      // Enter vehicle number and confirm plate
      await tester.enterText(find.byKey(const ValueKey('vehicle_number_field')), 'MH12AB1234');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm_plate_button')));
      await tester.pumpAndSettle();

      // Leave mobile number field empty
      await tester.enterText(find.byKey(const ValueKey('customer_mobile_field')), '');
      await tester.pumpAndSettle();

      // Click Save Entry
      await tester.ensureVisible(find.byKey(const ValueKey('save_entry_button')));
      await tester.tap(find.byKey(const ValueKey('save_entry_button')));
      await tester.pumpAndSettle();

      // Mobile check was bypassed (no mobile required error), progressed past optional photo
      expect(find.text(AppStrings.mobileRequired), findsNothing);
      expect(find.text(AppStrings.customerMobileRequired), findsNothing);
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsNothing);
    });

    testWidgets('requireCustomerMobile ON blocks vehicle entry when mobile number is empty', (tester) async {
      setTestSurfaceSize(tester);

      SettingsService.instance.setMockSettings(
        const SystemSettingsModel(
          requireCustomerMobile: true,
          requirePlatePhoto: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Asterisk IS shown on customer mobile label when requireCustomerMobile is ON
      expect(find.text('3. ${AppStrings.customerMobile} *'), findsOneWidget);

      // Enter vehicle number and confirm plate
      await tester.enterText(find.byKey(const ValueKey('vehicle_number_field')), 'MH12AB1234');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm_plate_button')));
      await tester.pumpAndSettle();

      // Leave mobile number field empty
      await tester.enterText(find.byKey(const ValueKey('customer_mobile_field')), '');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('save_entry_button')));
      await tester.tap(find.byKey(const ValueKey('save_entry_button')));
      await tester.pumpAndSettle();

      // Must block with mobile required error!
      expect(find.text(AppStrings.mobileRequired), findsOneWidget);
    });

    testWidgets('VehicleEntryScreen reacts dynamically in real-time when settings change', (tester) async {
      setTestSurfaceSize(tester);

      SettingsService.instance.setMockSettings(
        const SystemSettingsModel(
          requireCustomerMobile: false,
          requirePlatePhoto: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3. ${AppStrings.customerMobile}'), findsOneWidget);
      expect(find.text('3. ${AppStrings.customerMobile} *'), findsNothing);

      // Dynamically toggle requireCustomerMobile ON in real-time
      SettingsService.instance.setMockSettings(
        const SystemSettingsModel(
          requireCustomerMobile: true,
          requirePlatePhoto: false,
        ),
      );
      await tester.pumpAndSettle();

      // Asterisk is now dynamically displayed
      expect(find.text('3. ${AppStrings.customerMobile} *'), findsOneWidget);
    });
  });
}
