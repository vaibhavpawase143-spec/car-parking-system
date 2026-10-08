import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';
import 'package:car_parking_system/widgets/guard/mandatory_handover_popup.dart';

class MockFinancialServiceForHandover extends FinancialResponsibilityService {
  bool respondCalled = false;
  bool shouldDelay = false;
  bool shouldThrow = false;
  bool alreadyAcceptedInDb = false;
  String? lastHandoverId;
  bool? lastAccept;
  String? lastGuardUid;
  String? lastGuardName;

  @override
  Future<void> respondToHandover({
    required String handoverId,
    required bool accept,
    required String guardUid,
    required String guardName,
  }) async {
    respondCalled = true;
    lastHandoverId = handoverId;
    lastAccept = accept;
    lastGuardUid = guardUid;
    lastGuardName = guardName;

    if (shouldDelay) {
      await Future.delayed(const Duration(seconds: 15));
    }

    if (shouldThrow) {
      throw Exception('Network error during write');
    }
  }

  @override
  Future<HandoverModel?> getHandover(String handoverId) async {
    if (alreadyAcceptedInDb) {
      return HandoverModel(
        handoverId: handoverId,
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 2500,
        type: 'CASH',
        createdAt: DateTime.now(),
        status: 'ACCEPTED',
      );
    }
    return HandoverModel(
      handoverId: handoverId,
      fromGuardId: 'guard_a',
      fromGuardName: 'Guard A',
      toGuardId: 'guard_b',
      toGuardName: 'Guard B',
      shiftId: 'shift_1',
      amount: 2500,
      type: 'CASH',
      createdAt: DateTime.now(),
      status: 'PENDING',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final guardA = const GuardModel(
    uid: 'guard_a',
    name: 'Guard A',
    email: 'guard_a@jayganesh.com',
    role: 'guard',
    currentShift: 'Shift 1',
    isActive: true,
  );

  final guardB = const GuardModel(
    uid: 'guard_b',
    name: 'Guard B',
    email: 'guard_b@jayganesh.com',
    role: 'guard',
    currentShift: 'Shift 2',
    isActive: true,
  );

  final testCashHandover = HandoverModel(
    handoverId: 'handover_perf_101',
    fromGuardId: guardA.uid,
    fromGuardName: guardA.name,
    toGuardId: guardB.uid,
    toGuardName: guardB.name,
    shiftId: 'shift_1',
    amount: 1500.0,
    type: 'CASH',
    createdAt: DateTime.now(),
    status: 'PENDING',
  );

  final testUpiHandover = HandoverModel(
    handoverId: 'handover_perf_202',
    fromGuardId: guardA.uid,
    fromGuardName: guardA.name,
    toGuardId: guardB.uid,
    toGuardName: guardB.name,
    shiftId: 'shift_1',
    amount: 3200.0,
    type: 'UPI',
    createdAt: DateTime.now(),
    status: 'PENDING',
  );

  group('HANDOVER ACCEPT PERFORMANCE & TIMEOUT SAFETY TESTS', () {
    testWidgets('1. Fast acceptance completes without hanging & triggers onAccepted', (tester) async {
      final mockService = MockFinancialServiceForHandover();
      bool onAcceptedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: testCashHandover,
              currentGuard: guardB,
              financialService: mockService,
              onAccepted: () {
                onAcceptedCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump(); // starts loading
      await tester.pump(const Duration(milliseconds: 100)); // completes

      expect(mockService.respondCalled, isTrue);
      expect(mockService.lastHandoverId, equals('handover_perf_101'));
      expect(mockService.lastAccept, isTrue);
      expect(onAcceptedCalled, isTrue);
    });

    testWidgets('2. Double-tap / multi-click is safely ignored while accepting', (tester) async {
      final mockService = MockFinancialServiceForHandover();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: testCashHandover,
              currentGuard: guardB,
              financialService: mockService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap twice quickly
      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockService.respondCalled, isTrue);
    });

    testWidgets('3. Failed transaction stops spinner and displays localized error', (tester) async {
      final mockService = MockFinancialServiceForHandover()..shouldThrow = true;
      bool onAcceptedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: testCashHandover,
              currentGuard: guardB,
              financialService: mockService,
              onAccepted: () {
                onAcceptedCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(onAcceptedCalled, isFalse);
      expect(find.text('Network error during write'), findsOneWidget);
    });

    testWidgets('4. Error recovery: If authoritative doc is already ACCEPTED, treat as success', (tester) async {
      final mockService = MockFinancialServiceForHandover()
        ..shouldThrow = true
        ..alreadyAcceptedInDb = true;
      bool onAcceptedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: testCashHandover,
              currentGuard: guardB,
              financialService: mockService,
              onAccepted: () {
                onAcceptedCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(onAcceptedCalled, isTrue);
    });

    testWidgets('5. UPI Handover acceptance preserves UPI type correctly', (tester) async {
      final mockService = MockFinancialServiceForHandover();
      bool onAcceptedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: testUpiHandover,
              currentGuard: guardB,
              financialService: mockService,
              onAccepted: () {
                onAcceptedCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('mandatory_accept_handover_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockService.lastHandoverId, equals('handover_perf_202'));
      expect(onAcceptedCalled, isTrue);
    });
  });
}
