import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/exit/matching_vehicles_dialog.dart';
import 'package:car_parking_system/screens/guard/exit/vehicle_exit_search_screen.dart';
import 'package:car_parking_system/screens/guard/exit/exit_receipt_screen.dart';
import 'package:car_parking_system/screens/guard/exit/exit_success_screen.dart';
import 'package:car_parking_system/screens/guard/exit/vehicle_exit_verification_screen.dart';
import 'package:car_parking_system/services/parking_service.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/widgets/camera/qr_scanner_dialog.dart';

class FakeParkingService extends ParkingService {
  final List<ParkingRecord> records;
  int _lastTicket = 1000;

  FakeParkingService({this.records = const []});

  @override
  Future<String> generateNextTicketNumber() async {
    _lastTicket++;
    return _lastTicket.toString();
  }

  @override
  Future<ParkingRecord> lookupTicketForExit(String rawQuery) async {
    final clean = rawQuery.trim().toUpperCase();
    final match = records.cast<ParkingRecord?>().firstWhere(
      (r) => r?.ticketNumber.toUpperCase() == clean || r?.id.toUpperCase() == clean,
      orElse: () => null,
    );
    if (match == null) {
      throw TicketNotFoundException(clean);
    }
    if (match.status == 'EXITED') {
      throw VehicleAlreadyExitedException(match.ticketNumber);
    }
    if (!match.isActive) {
      throw VehicleNotActiveException(match.status);
    }
    return match;
  }

  @override
  Future<List<ParkingRecord>> searchTicketsForExit(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) throw const TicketNotFoundException('');

    final active = await searchActiveVehicles(trimmed);
    if (active.isNotEmpty) return active;

    final isLegacy = AppFormatters.isLegacyTicketQuery(trimmed);
    final lookupKey = isLegacy ? trimmed.toUpperCase() : trimmed;

    final exact = records.cast<ParkingRecord?>().firstWhere(
      (r) =>
          r?.ticketNumber.toUpperCase() == lookupKey.toUpperCase() ||
          r?.id.toUpperCase() == lookupKey.toUpperCase() ||
          AppFormatters.normalizeVehicleNumber(r?.vehicleNumber) == AppFormatters.normalizeVehicleNumber(trimmed),
      orElse: () => null,
    );
    if (exact != null) {
      if (exact.status == 'EXITED') throw VehicleAlreadyExitedException(exact.ticketNumber);
      if (!exact.isActive) throw VehicleNotActiveException(exact.status);
    }
    throw TicketNotFoundException(trimmed);
  }

  @override
  Future<List<ParkingRecord>> searchActiveVehicles(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return [];

    final isNumeric = AppFormatters.isNumericTicketQuery(trimmed);
    final isLegacy = AppFormatters.isLegacyTicketQuery(trimmed);

    if (isNumeric) {
      return records.where((r) {
        if (!r.isActive) return false;
        final normVeh = AppFormatters.normalizeVehicleNumber(r.vehicleNumber);
        final tNum = r.ticketNumber.trim();
        final matchesVehicleSuffix = normVeh.endsWith(trimmed);
        final matchesTicket = AppFormatters.isNumericTicketQuery(tNum) && tNum.endsWith(trimmed);
        return matchesVehicleSuffix || matchesTicket;
      }).toList();
    } else if (isLegacy) {
      final cleanTicket = trimmed.toUpperCase();
      return records
          .where((r) => r.isActive && (r.ticketNumber.toUpperCase() == cleanTicket || r.id.toUpperCase() == cleanTicket))
          .toList();
    } else {
      final cleanVehicle = AppFormatters.normalizeVehicleNumber(trimmed);
      return records
          .where((r) => r.isActive && (AppFormatters.normalizeVehicleNumber(r.vehicleNumber) == cleanVehicle || AppFormatters.normalizeVehicleNumber(r.vehicleNumber).contains(cleanVehicle)))
          .toList();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testGuard = const GuardModel(
    uid: 'guard-101',
    name: 'Officer Rajesh',
    email: 'rajesh@parking.com',
    role: 'guard',
    currentShift: 'Morning Shift',
    mobile: '9876543210',
  );

  final activeRecord = ParkingRecord(
    id: 'TKT-20260923-8EH9',
    ticketId: 'TKT-20260923-8EH9',
    ticketNumber: 'TKT-20260923-8EH9',
    vehicleNumber: 'MH20AS8471',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543210',
    entryTime: DateTime(2026, 9, 23, 10, 0),
    status: 'ACTIVE',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 100.0,
    advancePaymentMethod: 'cash',
    photoUrl: 'https://example.com/vehicle1.jpg',
    qrReference: 'TKT-20260923-8EH9',
  );

  final exitedRecord = ParkingRecord(
    id: 'TKT-20260923-OLD1',
    ticketId: 'TKT-20260923-OLD1',
    ticketNumber: 'TKT-20260923-OLD1',
    vehicleNumber: 'MH12AB1234',
    vehicleType: VehicleType.twoWheeler,
    customerMobile: '9876543211',
    entryTime: DateTime(2026, 9, 23, 8, 0),
    exitTime: DateTime(2026, 9, 23, 9, 30),
    status: 'EXITED',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 0.0,
    advancePaymentMethod: 'none',
    photoUrl: 'https://example.com/vehicle2.jpg',
    qrReference: 'TKT-20260923-OLD1',
  );

  final numericActive1 = ParkingRecord(
    id: '1004',
    ticketId: '1004',
    ticketNumber: '1004',
    vehicleNumber: 'MH12BB2333',
    vehicleType: VehicleType.twoWheeler,
    customerMobile: '9876543212',
    entryTime: DateTime(2026, 9, 23, 15, 36),
    status: 'ACTIVE',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 0.0,
    advancePaymentMethod: 'none',
    photoUrl: 'https://example.com/bike1.jpg',
    qrReference: '1004',
  );

  final numericActive2 = ParkingRecord(
    id: '1204',
    ticketId: '1204',
    ticketNumber: '1204',
    vehicleNumber: 'MH14AB1204',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543213',
    entryTime: DateTime(2026, 9, 23, 15, 41),
    status: 'ACTIVE',
    entryGuardUid: 'guard-101',
    entryGuardName: 'Officer Rajesh',
    entryShift: 'Morning Shift',
    advanceAmount: 50.0,
    advancePaymentMethod: 'cash',
    photoUrl: 'https://example.com/car2.jpg',
    qrReference: '1204',
  );

  final numericExited = ParkingRecord(
    id: '1000',
    ticketId: '1000',
    ticketNumber: '1000',
    vehicleNumber: 'MH02CD2000',
    vehicleType: VehicleType.twoWheeler,
    customerMobile: '9876543214',
    entryTime: DateTime(2026, 9, 23, 12, 0),
    exitTime: DateTime(2026, 9, 23, 13, 0),
    status: 'EXITED',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 0.0,
    advancePaymentMethod: 'none',
    photoUrl: 'https://example.com/bike2.jpg',
    qrReference: '1000',
  );

  final activeVehicle5656 = ParkingRecord(
    id: '1002',
    ticketId: '1002',
    ticketNumber: '1002',
    vehicleNumber: 'MH23ER5656',
    vehicleType: VehicleType.fourWheeler,
    customerMobile: '9876543215',
    entryTime: DateTime(2026, 9, 23, 14, 0),
    status: 'ACTIVE',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 0.0,
    advancePaymentMethod: 'none',
    photoUrl: 'https://example.com/car5656.jpg',
    qrReference: '1002',
  );

  final activeVehicle3233 = ParkingRecord(
    id: '1003',
    ticketId: '1003',
    ticketNumber: '1003',
    vehicleNumber: 'MH17PS3233',
    vehicleType: VehicleType.twoWheeler,
    customerMobile: '9876543216',
    entryTime: DateTime(2026, 9, 23, 14, 30),
    status: 'ACTIVE',
    entryGuardUid: 'guard-100',
    entryGuardName: 'Officer Kumar',
    entryShift: 'Morning Shift',
    advanceAmount: 0.0,
    advancePaymentMethod: 'none',
    photoUrl: 'https://example.com/bike3233.jpg',
    qrReference: '1003',
  );

  final fakeService = FakeParkingService(
    records: [
      activeRecord,
      exitedRecord,
      numericActive1,
      numericActive2,
      numericExited,
      activeVehicle5656,
      activeVehicle3233,
    ],
  );

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('NUMERIC-ONLY TICKETS & VEHICLE EXIT MODULE — Comprehensive Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. SEQUENTIAL DETERMINISTIC TICKET GENERATION
    // -------------------------------------------------------------------------
    test('1. Sequential Deterministic Ticket Generation (starts from 1001, digits only, no prefix)', () async {
      final service = FakeParkingService();
      final t1 = await service.generateNextTicketNumber();
      final t2 = await service.generateNextTicketNumber();
      final t3 = await service.generateNextTicketNumber();
      final t4 = await service.generateNextTicketNumber();

      expect(t1, equals('1001'));
      expect(t2, equals('1002'));
      expect(t3, equals('1003'));
      expect(t4, equals('1004'));

      // Strictly numeric
      expect(RegExp(r'^\d+$').hasMatch(t1), isTrue);
      expect(RegExp(r'^\d+$').hasMatch(t2), isTrue);
      expect(t1.contains('TKT-'), isFalse);
      expect(t1.contains('-'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 2. QUERY TYPE DETECTION & NORMALIZATION RULES
    // -------------------------------------------------------------------------
    test('2. Query Type Detection: Numeric Ticket vs Legacy vs Vehicle Number', () {
      // Purely numeric queries
      expect(AppFormatters.isNumericTicketQuery('4'), isTrue);
      expect(AppFormatters.isNumericTicketQuery('04'), isTrue);
      expect(AppFormatters.isNumericTicketQuery('004'), isTrue);
      expect(AppFormatters.isNumericTicketQuery('1004'), isTrue);
      expect(AppFormatters.isTicketQuery('4'), isTrue);
      expect(AppFormatters.isTicketQuery('04'), isTrue);
      expect(AppFormatters.isTicketQuery('1004'), isTrue);

      // Legacy ticket queries
      expect(AppFormatters.isLegacyTicketQuery('tkt-20260923-8eh9'), isTrue);
      expect(AppFormatters.isLegacyTicketQuery('TKT-20260923-8EH9'), isTrue);
      expect(AppFormatters.isTicketQuery('tkt-20260923-8eh9'), isTrue);
      expect(AppFormatters.isTicketQuery('TKT-20260923-8EH9'), isTrue);

      // Vehicle numbers do NOT match ticket query
      expect(AppFormatters.isTicketQuery('MH 20 AS 8471'), isFalse);
      expect(AppFormatters.isTicketQuery('MH-20-AS-8471'), isFalse);
      expect(AppFormatters.isTicketQuery('DL01AB1234'), isFalse);

      // Normalization rules:
      // Numeric tickets preserve leading zeros
      expect(AppFormatters.normalizeActiveSearchQuery('04'), equals('04'));
      expect(AppFormatters.normalizeActiveSearchQuery('004'), equals('004'));
      expect(AppFormatters.normalizeActiveSearchQuery('1004'), equals('1004'));

      // Legacy tickets preserve hyphens and uppercase
      expect(AppFormatters.normalizeActiveSearchQuery('tkt-20260923-8eh9'), equals('TKT-20260923-8EH9'));

      // Vehicle numbers remove spaces and hyphens
      expect(AppFormatters.normalizeActiveSearchQuery('MH 20 AS 8471'), equals('MH20AS8471'));
      expect(AppFormatters.normalizeActiveSearchQuery('MH-20-AS-8471'), equals('MH20AS8471'));
    });

    // -------------------------------------------------------------------------
    // 3. QR NUMERIC TICKET DATA
    // -------------------------------------------------------------------------
    test('3. QR code uses numeric ticket number for new entries', () {
      expect(numericActive1.ticketNumber, equals('1004'));
      expect(numericActive1.qrReference, equals('1004'));
      expect(numericActive1.id, equals('1004'));

      // Legacy ticket QR remains intact
      expect(activeRecord.ticketNumber, equals('TKT-20260923-8EH9'));
      expect(activeRecord.qrReference, equals('TKT-20260923-8EH9'));
    });

    // -------------------------------------------------------------------------
    // 4. EXACT NUMERIC TICKET SEARCH (1004) -> OPENS DIRECTLY
    // -------------------------------------------------------------------------
    testWidgets('4. Exact full numeric ticket search (1004) opens Verification directly', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 1004
      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), '1004');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      // Directly opens Verification Screen for 1004
      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      expect(find.text('MH12BB2333'), findsOneWidget);
      expect(find.text('1004'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 5. 1-DIGIT SUFFIX SEARCH (4) -> MATCHES 1004 & 1204
    // -------------------------------------------------------------------------
    test('5. 1-Digit Suffix Search (4) matches tickets ending in 4', () async {
      final matches = await fakeService.searchTicketsForExit('4');
      expect(matches.length, equals(2));
      expect(matches.any((r) => r.ticketNumber == '1004'), isTrue);
      expect(matches.any((r) => r.ticketNumber == '1204'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 6. 2-DIGIT SUFFIX SEARCH (04) -> MATCHES 1004 & 1204
    // -------------------------------------------------------------------------
    test('6. 2-Digit Suffix Search (04) matches tickets ending in 04', () async {
      final matches = await fakeService.searchTicketsForExit('04');
      expect(matches.length, equals(2));
      expect(matches.any((r) => r.ticketNumber == '1004'), isTrue);
      expect(matches.any((r) => r.ticketNumber == '1204'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 7. 3-DIGIT SUFFIX SEARCH (004) -> MATCHES 1004 ONLY
    // -------------------------------------------------------------------------
    test('7. 3-Digit Suffix Search (004) matches 1004 only', () async {
      final matches = await fakeService.searchTicketsForExit('004');
      expect(matches.length, equals(1));
      expect(matches.first.ticketNumber, equals('1004'));
    });

    // -------------------------------------------------------------------------
    // 8. 4-DIGIT SUFFIX SEARCH (1204) -> MATCHES 1204
    // -------------------------------------------------------------------------
    test('8. 4-Digit Suffix Search (1204) matches 1204', () async {
      final matches = await fakeService.searchTicketsForExit('1204');
      expect(matches.length, equals(1));
      expect(matches.first.ticketNumber, equals('1204'));
    });

    // -------------------------------------------------------------------------
    // 9. MULTIPLE MATCHES PRESENT SELECTION LIST WITH [ Select Vehicle ]
    // -------------------------------------------------------------------------
    testWidgets('9. Searching 04 displays MatchingVehiclesDialog with [ Select Vehicle ] button', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter partial 04
      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), '04');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      // MatchingVehiclesDialog opens
      expect(find.byType(MatchingVehiclesDialog), findsOneWidget);
      expect(find.text('MH12BB2333'), findsOneWidget);
      expect(find.text('MH14AB1204'), findsOneWidget);
      expect(find.text('Ticket: 1004'), findsOneWidget);
      expect(find.text('Ticket: 1204'), findsOneWidget);

      // Verify explicit [ Select Vehicle ] buttons exist
      expect(find.byKey(const ValueKey('select_vehicle_button_1004')), findsOneWidget);
      expect(find.byKey(const ValueKey('select_vehicle_button_1204')), findsOneWidget);

      // Guard selects 1204
      await tester.tap(find.byKey(const ValueKey('select_vehicle_button_1204')));
      await tester.pumpAndSettle();

      // Opens verification screen for 1204
      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      expect(find.text('MH14AB1204'), findsOneWidget);
      expect(find.text('1204'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 10. LEGACY TICKET SEARCH (TKT-20260923-8EH9 & lowercase)
    // -------------------------------------------------------------------------
    testWidgets('10. Legacy ticket (tkt-20260923-8eh9) opens Verification directly', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter lowercase legacy ticket
      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), 'tkt-20260923-8eh9');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      // Directly opens Verification Screen for legacy ticket
      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      expect(find.text('MH20AS8471'), findsOneWidget);
      expect(find.text('TKT-20260923-8EH9'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 11. EXITED TICKET REJECTION
    // -------------------------------------------------------------------------
    testWidgets('11. Searching an EXITED ticket displays "This vehicle has already exited."', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter exited ticket 1000
      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), '1000');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('This vehicle has already exited.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 12. NON-EXISTENT TICKET REJECTION
    // -------------------------------------------------------------------------
    testWidgets('12. Searching a non-existent ticket displays "Ticket not found."', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), '9999');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ticket not found.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 13. VEHICLE NUMBER LAST-DIGIT SEARCH (MH23ER5656 -> 5656, 656, 56, 6, MH23ER5656)
    // -------------------------------------------------------------------------
    test('13. Vehicle number suffix searches match MH23ER5656', () async {
      for (final query in ['5656', '656', '56', '6', 'MH23ER5656']) {
        final matches = await fakeService.searchTicketsForExit(query);
        expect(
          matches.any((r) => r.vehicleNumber == 'MH23ER5656'),
          isTrue,
          reason: 'Query "$query" must find MH23ER5656',
        );
      }
    });

    test('14. Vehicle number suffix searches match MH17PS3233', () async {
      for (final query in ['3233', '233', '33', '3']) {
        final matches = await fakeService.searchTicketsForExit(query);
        expect(
          matches.any((r) => r.vehicleNumber == 'MH17PS3233'),
          isTrue,
          reason: 'Query "$query" must find MH17PS3233',
        );
      }
    });

    testWidgets('15. Single active vehicle suffix search (5656) directly opens Verification Screen', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('exit_ticket_input_field')), '5656');
      await tester.tap(find.byKey(const ValueKey('exit_ticket_search_button')));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      expect(find.text('MH23ER5656'), findsOneWidget);
    });

    testWidgets('16. Scan QR Code directly decodes ticket and opens Verification Screen', (tester) async {
      setTestSurfaceSize(tester);

      QrScannerDialog.mockScanResult = '1004';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitSearchScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click [ Scan QR ]
      await tester.tap(find.byKey(const ValueKey('scan_qr_code_button')));
      await tester.pumpAndSettle();

      // Directly opens Verification Screen for 1004
      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      expect(find.text('MH12BB2333'), findsOneWidget);
      expect(find.text('1004'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 14. FEE CALCULATION & DUPLICATE EXIT PROTECTION
    // -------------------------------------------------------------------------
    test('14. Fee calculation: Advance greater than gross charge calculates refund correctly', () {
      final entry = DateTime(2026, 9, 23, 10, 0);
      final exit = DateTime(2026, 9, 23, 11, 0); // 1 hour -> ₹50 for car
      const advance = 100.0;

      final fee = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: entry,
        exitTime: exit,
        advancePaid: advance,
      );

      expect(fee.grossCharge, equals(50.0));
      expect(fee.advancePaid, equals(100.0));
      expect(fee.balanceDue, equals(0.0));
      expect(fee.refundAmount, equals(50.0));
      expect(fee.hasRefund, isTrue);
    });

    // -------------------------------------------------------------------------
    // 15. CANCEL LEAVES STATE UNCHANGED
    // -------------------------------------------------------------------------
    testWidgets('15. Verification screen cancel returns safely without changes', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleExitVerificationScreen(
              record: activeRecord,
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onExitAnotherVehicle: () {},
              parkingService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VehicleExitVerificationScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel_vehicle_verification_button')));
      await tester.pumpAndSettle();

      // Record remains active
      expect(activeRecord.status, equals('ACTIVE'));
    });

    // -------------------------------------------------------------------------
    // 17. EXIT SUCCESS SCREEN — ONLY ONE BUTTON [ View Final Exit Receipt ]
    // -------------------------------------------------------------------------
    testWidgets('17. Exit Success screen contains ONLY [ View Final Exit Receipt ] button', (tester) async {
      setTestSurfaceSize(tester);

      final settledRecord = ParkingRecord(
        id: 'TKT-20260923-8EH9',
        ticketNumber: 'TKT-20260923-8EH9',
        vehicleNumber: 'MH20AS8471',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 23, 10, 0),
        exitTime: DateTime(2026, 9, 23, 11, 0),
        status: 'EXITED',
        entryGuardUid: 'guard-100',
        entryGuardName: 'Officer Kumar',
        entryShift: 'Morning Shift',
        advanceAmount: 100.0,
        grossCharge: 50.0,
        refundAmount: 50.0,
        balanceDue: 0.0,
        paymentMethod: 'cash',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExitSuccessScreen(
              record: settledRecord,
              onReturnDashboard: () {},
              onExitAnotherVehicle: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // View Final Exit Receipt button MUST be present
      expect(find.byKey(const ValueKey('view_final_exit_receipt_button')), findsOneWidget);
      expect(find.text('View Final Exit Receipt'), findsOneWidget);

      // Other buttons MUST be removed
      expect(find.text('Exit Another Vehicle'), findsNothing);
      expect(find.text('Return to Dashboard'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 18. FINAL EXIT RECEIPT — SHOWS REFUND & ADVANCE ADJUSTMENT & [ Print Exit Receipt ]
    // -------------------------------------------------------------------------
    testWidgets('18. Final Exit Receipt shows Advance Adjusted, Refund Handed Back, Print and Done buttons', (tester) async {
      setTestSurfaceSize(tester);

      final refundRecord = ParkingRecord(
        id: '1004',
        ticketNumber: '1004',
        vehicleNumber: 'MH12BB2333',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 9, 23, 15, 0),
        exitTime: DateTime(2026, 9, 23, 15, 30),
        status: 'EXITED',
        entryGuardUid: 'guard-100',
        entryGuardName: 'Officer Kumar',
        entryShift: 'Morning Shift',
        advanceAmount: 50.0,
        advancePaymentMethod: 'cash',
        grossCharge: 10.0,
        refundAmount: 40.0,
        balanceDue: 0.0,
        paymentMethod: 'cash',
      );

      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExitReceiptScreen(
              record: refundRecord,
              onDone: () {
                doneCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Financial breakdown
      expect(find.text('Gross Parking Charge'), findsOneWidget);
      expect(find.text('₹10'), findsOneWidget);
      expect(find.text('Advance Paid'), findsOneWidget);
      expect(find.text('₹50 (CASH)'), findsOneWidget);
      expect(find.text('Advance Adjusted'), findsOneWidget);
      expect(find.text('- ₹50'), findsOneWidget);
      expect(find.text('Refund Handed Back'), findsOneWidget);
      expect(find.text('₹40 (CASH)'), findsOneWidget);

      // Buttons present
      expect(find.byKey(const ValueKey('print_exit_receipt_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('exit_receipt_done_button')), findsOneWidget);

      // Clicking Done triggers onDone callback
      await tester.tap(find.byKey(const ValueKey('exit_receipt_done_button')));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });

    // -------------------------------------------------------------------------
    // 19. 58MM THERMAL EXIT RECEIPT HTML CONTAINS ALL REQUIRED FIELDS
    // -------------------------------------------------------------------------
    test('19. 58mm Thermal Exit Receipt HTML contains refund and settlement details', () {
      final refundRecord = ParkingRecord(
        id: '1004',
        ticketNumber: '1004',
        vehicleNumber: 'MH12BB2333',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 9, 23, 15, 0),
        exitTime: DateTime(2026, 9, 23, 15, 30),
        status: 'EXITED',
        entryGuardUid: 'guard-100',
        entryGuardName: 'Officer Kumar',
        entryShift: 'Morning Shift',
        advanceAmount: 50.0,
        advancePaymentMethod: 'cash',
        grossCharge: 10.0,
        refundAmount: 40.0,
        balanceDue: 0.0,
        paymentMethod: 'cash',
      );

      final html = ReceiptPrintService.build58mmExitReceiptHtml(refundRecord);

      expect(html, contains('CAR PARKING SYSTEM'));
      expect(html, isNot(contains('JAY GANESH')));
      expect(html, contains('EXIT RECEIPT'));
      expect(html, contains('MH12BB2333'));
      expect(html, contains('TOTAL AMOUNT'));
      expect(html, contains('₹10'));
      expect(html, contains('Advance Paid:'));
      expect(html, contains('₹50'));
      expect(html, contains('Advance Adjusted:'));
      expect(html, contains('-₹50'));
      expect(html, contains('REFUND HANDED BACK:'));
      expect(html, contains('₹40'));
      expect(html, contains('REFUND METHOD:'));
      expect(html, contains('CASH'));
      expect(html, contains('SETTLED & EXITED'));
    });
  });
}
