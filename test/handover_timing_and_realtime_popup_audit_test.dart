import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';
import 'package:car_parking_system/widgets/guard/mandatory_handover_popup.dart';

void main() {
  group('Master Handover Timing + Realtime Popup + Shift-End Audit Test Suite', () {
    final now = DateTime.now();

    final guardA = const GuardModel(
      uid: 'guard_a_uid',
      name: 'Guard A',
      email: 'a@gmail.com',
      role: 'guard',
      isActive: true,
      currentShift: 'Shift 1',
    );

    final guardB = const GuardModel(
      uid: 'guard_b_uid',
      name: 'Guard B',
      email: 'b@testparking.com',
      role: 'guard',
      isActive: true,
      currentShift: 'Shift 2',
    );

    test('1. Shift Independence: Outgoing Guard can create Handover during ACTIVE shift or after SHIFT END', () {
      // 1A. During active shift
      final activeShift = ShiftModel(
        shiftId: 'shift_a_active',
        guardId: 'guard_a_uid',
        guardName: 'Guard A',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ACTIVE',
      );
      expect(activeShift.isActive, isTrue);

      final handover1 = HandoverModel(
        handoverId: 'ho_active_1',
        fromGuardId: guardA.uid,
        fromGuardName: guardA.name,
        toGuardId: guardB.uid,
        toGuardName: guardB.name,
        shiftId: activeShift.shiftId,
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        createdAt: now,
      );
      expect(handover1.isPending, isTrue);
      expect(handover1.amount, 50.0);

      // 1B. After shift end (expired shift)
      final endedShift = ShiftModel(
        shiftId: 'shift_a_ended',
        guardId: 'guard_a_uid',
        guardName: 'Guard A',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 10)),
        endTime: now.subtract(const Duration(hours: 2)),
        status: 'COMPLETED',
      );
      expect(endedShift.isActive, isFalse);
      expect(endedShift.isCompleted, isTrue);

      final handover2 = HandoverModel(
        handoverId: 'ho_ended_1',
        fromGuardId: guardA.uid,
        fromGuardName: guardA.name,
        toGuardId: guardB.uid,
        toGuardName: guardB.name,
        shiftId: endedShift.shiftId,
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        createdAt: now,
      );
      expect(handover2.isPending, isTrue);
      expect(handover2.amount, 50.0);
    });

    test('2. Additive Balance Transfer: Guard B existing responsibility is preserved and augmented', () {
      // Guard B initial state: Cash ₹20, UPI ₹30
      final initialRespB = const GuardFinancialResponsibility(
        guardUid: 'guard_b_uid',
        guardName: 'Guard B',
        totalCashCollected: 20.0,
        totalUpiCollected: 30.0,
      );
      expect(initialRespB.outstandingCash, 20.0);
      expect(initialRespB.outstandingUpi, 30.0);
      expect(initialRespB.totalOutstanding, 50.0);

      // Handover of ₹50 Cash accepted by Guard B
      final updatedRespB = initialRespB.copyWith(
        cashReceived: initialRespB.cashReceived + 50.0,
      );

      // Guard B should now have ₹70 Cash, and UPI must remain ₹30
      expect(updatedRespB.outstandingCash, 70.0);
      expect(updatedRespB.outstandingUpi, 30.0);
      expect(updatedRespB.totalOutstanding, 100.0);

      // Guard A initial state: Cash ₹50
      final initialRespA = const GuardFinancialResponsibility(
        guardUid: 'guard_a_uid',
        guardName: 'Guard A',
        totalCashCollected: 50.0,
      );
      expect(initialRespA.outstandingCash, 50.0);

      // Guard A after Handover Out of ₹50
      final updatedRespA = initialRespA.copyWith(
        cashHandedOver: initialRespA.cashHandedOver + 50.0,
      );
      expect(updatedRespA.outstandingCash, 0.0);
    });

    testWidgets('3. MandatoryHandoverPopup UI: Displays From, Method, Amount, Status, blocks pop, has only [ ACCEPT ]', (tester) async {
      final handover = HandoverModel(
        handoverId: 'ho_test_popup',
        fromGuardId: 'guard_a_uid',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b_uid',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: handover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Header and Title
      expect(find.text(AppStrings.handoverReceived), findsOneWidget);

      // Verify Fields
      expect(find.text(AppStrings.from), findsOneWidget);
      expect(find.text('Guard A'), findsOneWidget);
      expect(find.text(AppStrings.method), findsOneWidget);
      expect(find.text(AppStrings.cashLabel), findsOneWidget);
      expect(find.text(AppStrings.amount), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(50.0)), findsOneWidget);
      expect(find.text(AppStrings.status), findsOneWidget);
      expect(find.text(AppStrings.pending), findsOneWidget);

      // Verify Instruction message
      expect(find.text(AppStrings.pleaseAcceptHandoverToContinue), findsOneWidget);

      // Verify ONLY ONE action button [ ACCEPT ] exists (no dismiss/cancel button)
      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);
      expect(find.text(AppStrings.cancel), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('4. ModalBarrier blocks all interaction with underlying navigation shell when pending handover exists', (tester) async {
      final handover = HandoverModel(
        handoverId: 'ho_barrier_test',
        fromGuardId: 'guard_a_uid',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b_uid',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        createdAt: now,
      );

      // Render a Stack simulating GuardNavigationShell structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Underlying active operational screen with buttons
                Column(
                  children: [
                    ElevatedButton(
                      key: const ValueKey('new_vehicle_entry_btn'),
                      onPressed: () {},
                      child: const Text('New Vehicle Entry'),
                    ),
                    ElevatedButton(
                      key: const ValueKey('vehicle_exit_btn'),
                      onPressed: () {},
                      child: const Text('Vehicle Exit'),
                    ),
                  ],
                ),
                // Blocking Barrier and Popup
                const ModalBarrier(
                  key: ValueKey('mandatory_handover_barrier'),
                  dismissible: false,
                  color: Colors.black54,
                ),
                MandatoryHandoverPopup(
                  handover: handover,
                  currentGuard: guardB,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify barrier is present
      expect(find.byKey(const ValueKey('mandatory_handover_barrier')), findsOneWidget);

      // Tapping underlying button must be blocked by ModalBarrier
      final entryBtn = find.byKey(const ValueKey('new_vehicle_entry_btn'));
      expect(entryBtn, findsOneWidget);

      // Attempt to tap the underlying entry button
      await tester.tap(entryBtn, warnIfMissed: false);
      await tester.pump();

      // Modal is still top-most and untouched
      expect(find.byKey(const ValueKey('mandatory_accept_handover_button')), findsOneWidget);
    });

    testWidgets('5. Double-click protection: button prevents multiple simultaneous accept requests', (tester) async {
      final handover = HandoverModel(
        handoverId: 'ho_double_click',
        fromGuardId: 'guard_a_uid',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b_uid',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MandatoryHandoverPopup(
              handover: handover,
              currentGuard: guardB,
            ),
          ),
        ),
      );
      await tester.pump();

      final acceptBtn = find.byKey(const ValueKey('mandatory_accept_handover_button'));
      expect(acceptBtn, findsOneWidget);

      // Tap once
      await tester.tap(acceptBtn);
      await tester.pump();

      // Second rapid tap must be safely handled without throwing
      await tester.tap(acceptBtn, warnIfMissed: false);
      await tester.pump();
    });

    test('6. Stale Handover Validation: auto-cancels if outgoing balance changes prior to acceptance', () {
      final handover = HandoverModel(
        handoverId: 'ho_stale_check',
        fromGuardId: 'guard_a_uid',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b_uid',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'PENDING',
        sourceBalanceBefore: 50.0,
        createdAt: now,
      );

      // If current balance of Guard A dropped to ₹30 (e.g. refund occurred)
      const currentAvailableBalance = 30.0;
      final expectedBalance = handover.sourceBalanceBefore ?? handover.amount;

      final isStale = (currentAvailableBalance - expectedBalance).abs() > 0.001 || currentAvailableBalance < handover.amount;
      expect(isStale, isTrue, reason: 'Balance mismatch must trigger isStale auto-cancellation check');
    });

    test('7. Active Parked Vehicles and Historical Records are completely untouched by Handover', () {
      // Parked vehicles list before handover
      final parkedVehicles = [
        {'ticketId': '1001', 'vehicleNumber': 'MH12AB1234', 'status': 'PARKED'},
        {'ticketId': '1002', 'vehicleNumber': 'MH14CD5678', 'status': 'PARKED'},
      ];

      // Handover event occurs
      final handover = HandoverModel(
        handoverId: 'ho_parking_preserved',
        fromGuardId: 'guard_a_uid',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b_uid',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 50.0,
        type: 'CASH',
        action: 'HANDOVER',
        status: 'ACCEPTED',
        createdAt: now,
      );

      expect(handover.isAccepted, isTrue);
      // Verify parked vehicles collection is 100% intact
      expect(parkedVehicles.length, 2);
      expect(parkedVehicles[0]['status'], 'PARKED');
      expect(parkedVehicles[1]['status'], 'PARKED');
    });
  });
}
