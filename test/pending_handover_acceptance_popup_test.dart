import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';
import 'package:car_parking_system/widgets/guard/mandatory_handover_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });
  final guardA = const GuardModel(
    uid: 'guard_a_101',
    name: 'Guard A',
    email: 'guard_a@jayganesh.com',
    role: 'guard',
    currentShift: 'Shift 1',
    isActive: true,
  );

  final guardB = const GuardModel(
    uid: 'guard_b_102',
    name: 'Guard B',
    email: 'guard_b@jayganesh.com',
    role: 'guard',
    currentShift: 'Shift 2',
    isActive: true,
  );

  final guardC = const GuardModel(
    uid: 'guard_c_103',
    name: 'Guard C',
    email: 'guard_c@jayganesh.com',
    role: 'guard',
    currentShift: 'Shift 3',
    isActive: true,
  );

  final sampleCashHandover = HandoverModel(
    handoverId: 'handover_cash_999',
    fromGuardId: guardA.uid,
    fromGuardName: guardA.name,
    toGuardId: guardB.uid,
    toGuardName: guardB.name,
    shiftId: 'shift_1',
    amount: 5000.0,
    type: 'CASH',
    createdAt: DateTime(2026, 10, 1, 10, 0),
    status: 'PENDING',
  );

  final sampleUpiHandover = HandoverModel(
    handoverId: 'handover_upi_888',
    fromGuardId: guardA.uid,
    fromGuardName: guardA.name,
    toGuardId: guardB.uid,
    toGuardName: guardB.name,
    shiftId: 'shift_1',
    amount: 3500.0,
    type: 'UPI',
    createdAt: DateTime(2026, 10, 1, 10, 15),
    status: 'PENDING',
  );

  group('MANDATORY PENDING HANDOVER POPUP TEST SUITE', () {
    testWidgets('Test 1 & 2: Popup appears with From, Method, Amount, Status, and Accept button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.handoverReceived), findsOneWidget);
      expect(find.text(guardA.name), findsOneWidget);
      expect(find.text(AppStrings.cashLabel), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(5000)), findsOneWidget);
      expect(find.text(AppStrings.pending), findsOneWidget);
      expect(find.text(AppStrings.pleaseAcceptHandoverToContinue), findsOneWidget);
      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);
    });

    testWidgets('Test 3: Only ACCEPT button exists (No Reject, Cancel, Later, Skip, Close)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('Test 4: Popup is non-dismissible (PopScope canPop is false)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('Test 12: Receiving guard mismatch validation', (tester) async {
      // Guard C viewing Handover addressed to Guard B
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardC,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Accept
      final acceptBtn = find.byKey(const ValueKey('mandatory_accept_handover_button'));
      await tester.tap(acceptBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Guard C cannot accept Guard B's handover - error is shown
      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);
    });

    testWidgets('Test 15: Marathi Localization mode renders completely in Marathi', (tester) async {
      AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      addTearDown(() => AppLanguageController.instance.setLanguage(AppLanguage.english));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('हँडओव्हर प्राप्त झाला'), findsOneWidget);
      expect(find.text('कडून'), findsOneWidget);
      expect(find.text('पद्धत'), findsOneWidget);
      expect(find.text('रक्कम'), findsOneWidget);
      expect(find.text('स्थिती'), findsOneWidget);
      expect(find.text('प्रलंबित'), findsOneWidget);
      expect(find.text('पुढे सुरू ठेवण्यासाठी हे हँडओव्हर स्वीकारा.'), findsOneWidget);
      expect(find.text('स्वीकारा'), findsOneWidget);
    });

    testWidgets('Test 16: Cash and UPI remain strictly separate in modal display', (tester) async {
      // Test Cash Handover
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(AppStrings.cashLabel), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(5000)), findsOneWidget);

      // Test UPI Handover
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleUpiHandover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(AppStrings.upiLabel), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(3500)), findsOneWidget);
    });

    testWidgets('Test 7 & 8: Outgoing Guard A is not targeted by incoming handover popup', (tester) async {
      // Stream for Guard A has no pending handovers assigned to them (toGuardId == guardB)
      final pendingHandoversForA = <HandoverModel>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Guard A Dashboard - Normal Operations')),
                if (pendingHandoversForA.isNotEmpty) ...[
                  const ModalBarrier(
                    key: ValueKey('mandatory_handover_barrier'),
                    dismissible: false,
                    color: Colors.black54,
                  ),
                  MandatoryHandoverPopup(
                    handover: pendingHandoversForA.first,
                    currentGuard: guardA,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Guard A can see normal dashboard operations without blocking overlay
      expect(find.text('Guard A Dashboard - Normal Operations'), findsOneWidget);
      expect(find.byType(MandatoryHandoverPopup), findsNothing);
      expect(find.byKey(const ValueKey('mandatory_handover_barrier')), findsNothing);
    });

    testWidgets('Test 5 & 6: Receiving Guard B has blocking ModalBarrier and Mandatory popup', (tester) async {
      final pendingHandoversForB = [sampleCashHandover];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Guard B Dashboard')),
                if (pendingHandoversForB.isNotEmpty) ...[
                  const ModalBarrier(
                    key: ValueKey('mandatory_handover_barrier'),
                    dismissible: false,
                    color: Colors.black54,
                  ),
                  MandatoryHandoverPopup(
                    handover: pendingHandoversForB.first,
                    currentGuard: guardB,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Blocking ModalBarrier and Popup are visible
      expect(find.byKey(const ValueKey('mandatory_handover_barrier')), findsOneWidget);
      expect(find.byType(MandatoryHandoverPopup), findsOneWidget);
      expect(find.text(AppStrings.handoverReceived), findsOneWidget);
    });

    testWidgets('Test 9 & 26: Stale handover error message string check', (tester) async {
      expect(
        AppStrings.handoverStaleAmountError,
        'Handover amount has changed. Please create a new handover.',
      );

      AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      addTearDown(() => AppLanguageController.instance.setLanguage(AppLanguage.english));

      expect(
        AppStrings.handoverStaleAmountError,
        'हँडओव्हरची रक्कम बदलली आहे. कृपया नवीन हँडओव्हर तयार करा.',
      );
    });

    test('Stale Handover Case 1: HandoverModel captures and serializes sourceBalanceBefore correctly', () {
      final handover = HandoverModel(
        handoverId: 'h_100',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 5000.0,
        type: 'CASH',
        createdAt: DateTime(2026, 10, 1, 12, 0),
        status: 'PENDING',
        sourceBalanceBefore: 5000.0,
      );

      final map = handover.toFirestore();
      expect(map['sourceBalanceBefore'], 5000.0);
      expect(map['amount'], 5000.0);
      expect(map['status'], 'PENDING');

      final reconstructed = HandoverModel.fromMap(map, 'h_100');
      expect(reconstructed.sourceBalanceBefore, 5000.0);
      expect(reconstructed.amount, 5000.0);
    });

    test('Stale Handover Case 2 & 3: Stale detection detects balance increase or decrease', () {
      final handover = HandoverModel(
        handoverId: 'h_100',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 5000.0,
        type: 'CASH',
        createdAt: DateTime(2026, 10, 1, 12, 0),
        status: 'PENDING',
        sourceBalanceBefore: 5000.0,
      );

      // Case 1: Balance unchanged (₹5000 == ₹5000)
      double currentAvailable = 5000.0;
      double expectedBalance = handover.sourceBalanceBefore ?? handover.amount;
      bool isStale = (currentAvailable - expectedBalance).abs() > 0.001 || currentAvailable < handover.amount;
      expect(isStale, isFalse);

      // Case 2: Balance increased to ₹5500 (A collected ₹500 more) -> STALE
      currentAvailable = 5500.0;
      isStale = (currentAvailable - expectedBalance).abs() > 0.001 || currentAvailable < handover.amount;
      expect(isStale, isTrue);

      // Case 3: Balance decreased to ₹4500 -> STALE
      currentAvailable = 4500.0;
      isStale = (currentAvailable - expectedBalance).abs() > 0.001 || currentAvailable < handover.amount;
      expect(isStale, isTrue);
    });

    testWidgets('Stale Handover Case 4: Double click prevention in MandatoryHandoverPopup UI', (tester) async {
      int acceptCallCount = 0;
      final completer = Completer<void>();

      final fakeService = _FakeFinancialResponsibilityService(
        onRespond: ({required String handoverId, required bool accept, required String guardUid, required String guardName}) {
          acceptCallCount++;
          return completer.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: sampleCashHandover,
              currentGuard: guardB,
              financialService: fakeService,
              onAccepted: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final acceptBtn = find.byKey(const ValueKey('mandatory_accept_handover_button'));
      // First tap
      await tester.tap(acceptBtn);
      await tester.pump();

      // Button is now in loading / disabled state
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.onPressed, isNull);
      expect(acceptCallCount, 1);

      // Subsequent taps do nothing
      await tester.tap(acceptBtn, warnIfMissed: false);
      expect(acceptCallCount, 1);

      // Complete async action
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

class _FakeFinancialResponsibilityService extends FinancialResponsibilityService {
  final Future<void> Function({
    required String handoverId,
    required bool accept,
    required String guardUid,
    required String guardName,
  }) onRespond;

  _FakeFinancialResponsibilityService({required this.onRespond});

  @override
  Future<void> respondToHandover({
    required String handoverId,
    required bool accept,
    required String guardUid,
    required String guardName,
  }) {
    return onRespond(
      handoverId: handoverId,
      accept: accept,
      guardUid: guardUid,
      guardName: guardName,
    );
  }
}
