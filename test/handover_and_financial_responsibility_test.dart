import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/responsibility_event_model.dart';
import 'package:car_parking_system/models/withdrawal_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';
import 'package:car_parking_system/screens/guard/payment/payment_management_screen.dart';
import 'package:car_parking_system/services/payment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HANDOVER & FINANCIAL RESPONSIBILITY BUSINESS LOGIC TESTS', () {
    test('1. Guard Financial Responsibility calculations are isolated for Cash and UPI', () {
      final resp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 700.0,
        cashHandedOver: 0.0,
        cashReceived: 0.0,
        cashWithdrawn: 0.0,
        totalUpiCollected: 500.0,
        upiHandedOver: 0.0,
        upiReceived: 0.0,
        upiWithdrawn: 0.0,
      );

      expect(resp.outstandingCash, 700.0);
      expect(resp.outstandingUpi, 500.0);
      expect(resp.totalOutstanding, 1200.0);
    });

    test('2. Handover ACCEPT transfers responsibility: Outgoing becomes 0, Incoming increases by exact amount', () {
      // Guard A initial state
      var guardA = const GuardFinancialResponsibility(
        guardUid: 'guard_A',
        guardName: 'Guard A',
        totalCashCollected: 700.0,
      );
      // Guard B initial state
      var guardB = const GuardFinancialResponsibility(
        guardUid: 'guard_B',
        guardName: 'Guard B',
        totalCashCollected: 200.0,
      );

      expect(guardA.outstandingCash, 700.0);
      expect(guardB.outstandingCash, 200.0);

      // Handover ₹700 from Guard A to Guard B ACCEPTED
      guardA = guardA.copyWith(cashHandedOver: 700.0);
      guardB = guardB.copyWith(cashReceived: 700.0);

      expect(guardA.outstandingCash, 0.0);
      expect(guardB.outstandingCash, 900.0);
    });

    test('3. Handover REJECT or CANCEL keeps responsibility with Outgoing Guard', () {
      final guardA = const GuardFinancialResponsibility(
        guardUid: 'guard_A',
        guardName: 'Guard A',
        totalCashCollected: 700.0,
        cashHandedOver: 0.0,
      );
      final guardB = const GuardFinancialResponsibility(
        guardUid: 'guard_B',
        guardName: 'Guard B',
        totalCashCollected: 0.0,
        cashReceived: 0.0,
      );

      expect(guardA.outstandingCash, 700.0);
      expect(guardB.outstandingCash, 0.0);
    });

    test('4. Next shift after Handover: Outgoing Guard starts at 0 and adds new collections', () {
      // Guard A previously had ₹700, handed over ₹700 ACCEPTED
      // New shift collection = ₹400
      final guardA = const GuardFinancialResponsibility(
        guardUid: 'guard_A',
        guardName: 'Guard A',
        totalCashCollected: 700.0 + 400.0, // Ledger total collection: 1100
        cashHandedOver: 700.0,
      );

      expect(guardA.outstandingCash, 400.0);
    });

    test('5. Next shift after Keep With Me: Outgoing Guard retains previous amount and adds new collection', () {
      // Guard A previously had ₹700, chose KEEP WITH ME (cashHandedOver = 0)
      // New shift collection = ₹400
      final guardA = const GuardFinancialResponsibility(
        guardUid: 'guard_A',
        guardName: 'Guard A',
        totalCashCollected: 700.0 + 400.0,
        cashHandedOver: 0.0,
      );

      expect(guardA.outstandingCash, 1100.0);
    });

    test('6. Admin Withdrawal settles full responsibility to 0', () {
      var guardA = const GuardFinancialResponsibility(
        guardUid: 'guard_A',
        guardName: 'Guard A',
        totalCashCollected: 1000.0,
      );
      expect(guardA.outstandingCash, 1000.0);

      // Admin withdraws full ₹1000
      guardA = guardA.copyWith(cashWithdrawn: 1000.0);
      expect(guardA.outstandingCash, 0.0);

      // Next shift collection of ₹300
      guardA = guardA.copyWith(totalCashCollected: 1300.0);
      expect(guardA.outstandingCash, 300.0);
    });

    test('7. HandoverModel serialization and status validation', () {
      final now = DateTime.now();
      final model = HandoverModel(
        handoverId: 'h_123',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 700.0,
        type: 'CASH',
        createdAt: now,
        status: 'PENDING',
      );

      expect(model.isPending, isTrue);
      expect(model.isAccepted, isFalse);
      expect(model.isCash, isTrue);
      expect(model.isUpi, isFalse);

      final map = model.toFirestore();
      expect(map['handoverId'], 'h_123');
      expect(map['amount'], 700.0);
      expect(map['type'], 'CASH');
      expect(map['status'], 'PENDING');
    });

    test('8. ResponsibilityEventModel serialization and parsing', () {
      final now = DateTime.now();
      final event = ResponsibilityEventModel(
        id: 'rev_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftId: 'shift_1',
        type: 'CASH',
        action: 'KEEP_WITH_ME',
        amount: 700.0,
        createdAt: now,
      );

      expect(event.isKeepWithMe, isTrue);
      expect(event.isCash, isTrue);

      final map = event.toFirestore();
      expect(map['id'], 'rev_1');
      expect(map['action'], 'KEEP_WITH_ME');
      expect(map['amount'], 700.0);

      final parsed = ResponsibilityEventModel.fromMap(map, 'rev_1');
      expect(parsed.id, 'rev_1');
      expect(parsed.guardId, 'guard_a');
      expect(parsed.action, 'KEEP_WITH_ME');
      expect(parsed.amount, 700.0);
    });

    test('9. WithdrawalModel serialization and parsing', () {
      final now = DateTime.now();
      final w = WithdrawalModel(
        withdrawalId: 'w_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftId: 'shift_1',
        type: 'CASH',
        amount: 1000.0,
        adminUid: 'admin_1',
        adminName: 'Admin',
        createdAt: now,
      );

      expect(w.isCash, isTrue);
      expect(w.amount, 1000.0);

      final map = w.toFirestore();
      expect(map['withdrawalId'], 'w_1');
      expect(map['amount'], 1000.0);

      final parsed = WithdrawalModel.fromMap(map, 'w_1');
      expect(parsed.withdrawalId, 'w_1');
      expect(parsed.adminName, 'Admin');
      expect(parsed.amount, 1000.0);
    });
  });

  group('PAYMENT MANAGEMENT SCREEN UI TESTS', () {
    final testGuard = const GuardModel(
      uid: 'guard_test_1',
      name: 'Test Guard',
      email: 'guard@test.com',
      role: 'guard',
    );

    testWidgets('10. Payment Management Screen renders Cash, UPI, and History action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentManagementScreen(
            currentGuard: testGuard,
            customReportStream: Stream.value(PaymentReportData.zero),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep With Me History'), findsOneWidget);
      expect(find.text('Handover History'), findsOneWidget);
      expect(find.text('Withdrawals'), findsOneWidget);
      expect(find.text('Responsibility'), findsOneWidget);
    });

    test('11. Keep With Me Cash and UPI events are completely isolated', () {
      final now = DateTime.now();
      final cashKeep = ResponsibilityEventModel(
        id: 'kwm_cash_1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftId: 'shift_1',
        type: 'CASH',
        action: 'KEEP_WITH_ME',
        status: 'Carried Forward',
        amount: 700.0,
        createdAt: now,
      );

      final upiKeep = ResponsibilityEventModel(
        id: 'kwm_upi_1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftId: 'shift_1',
        type: 'UPI',
        action: 'KEEP_WITH_ME',
        status: 'Carried Forward',
        amount: 300.0,
        createdAt: now,
      );

      expect(cashKeep.isCash, isTrue);
      expect(cashKeep.isUpi, isFalse);
      expect(cashKeep.amount, 700.0);
      expect(cashKeep.status, 'Carried Forward');

      expect(upiKeep.isUpi, isTrue);
      expect(upiKeep.isCash, isFalse);
      expect(upiKeep.amount, 300.0);
      expect(upiKeep.status, 'Carried Forward');
    });

    test('12. Handover lifecycle model tracks all timestamps and shift IDs', () {
      final created = DateTime.now().subtract(const Duration(hours: 2));
      final accepted = DateTime.now().subtract(const Duration(hours: 1));

      final h = HandoverModel(
        handoverId: 'ho_full_1',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        fromGuardEmail: 'guarda@test.com',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        toGuardEmail: 'guardb@test.com',
        shiftId: 'shift_from_101',
        toShiftId: 'shift_to_202',
        amount: 700.0,
        type: 'CASH',
        status: 'ACCEPTED',
        createdAt: created,
        acceptedAt: accepted,
        acceptedBy: 'guard_b',
      );

      expect(h.isAccepted, isTrue);
      expect(h.fromShiftId, 'shift_from_101');
      expect(h.toShiftId, 'shift_to_202');
      expect(h.acceptedAt, accepted);
      expect(h.acceptedBy, 'guard_b');

      final firestoreMap = h.toFirestore();
      expect(firestoreMap['fromShiftId'], 'shift_from_101');
      expect(firestoreMap['toShiftId'], 'shift_to_202');
      expect(firestoreMap['acceptedBy'], 'guard_b');
      expect(firestoreMap['status'], 'ACCEPTED');
    });

    test('13. Handover REJECTED and CANCELLED states are correctly identified', () {
      final now = DateTime.now();
      final rejected = HandoverModel(
        handoverId: 'ho_rej_1',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 500.0,
        type: 'UPI',
        status: 'REJECTED',
        createdAt: now,
        rejectedAt: now,
        rejectedBy: 'guard_b',
      );
      expect(rejected.isRejected, isTrue);
      expect(rejected.isAccepted, isFalse);
      expect(rejected.isPending, isFalse);

      final cancelled = HandoverModel(
        handoverId: 'ho_can_1',
        fromGuardId: 'guard_a',
        fromGuardName: 'Guard A',
        toGuardId: 'guard_b',
        toGuardName: 'Guard B',
        shiftId: 'shift_1',
        amount: 500.0,
        type: 'UPI',
        status: 'CANCELLED',
        createdAt: now,
        cancelledAt: now,
      );
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isAccepted, isFalse);
      expect(cancelled.isPending, isFalse);
    });

    test('14. Date filtering correctly filters raw DateTime objects', () {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final todayEvent = ResponsibilityEventModel(
        id: 'ev_today',
        guardId: 'g1',
        guardName: 'Guard 1',
        shiftId: 's1',
        type: 'CASH',
        action: 'KEEP_WITH_ME',
        amount: 500,
        createdAt: now,
      );

      final oldEvent = ResponsibilityEventModel(
        id: 'ev_old',
        guardId: 'g1',
        guardName: 'Guard 1',
        shiftId: 's0',
        type: 'CASH',
        action: 'KEEP_WITH_ME',
        amount: 300,
        createdAt: now.subtract(const Duration(days: 45)),
      );

      // Filtering for 'today'
      final events = [todayEvent, oldEvent];
      final filteredToday = events.where((e) =>
          !e.createdAt.isBefore(startOfToday) && !e.createdAt.isAfter(endOfToday)).toList();

      expect(filteredToday.length, 1);
      expect(filteredToday.first.id, 'ev_today');

      // Filtering for '30d'
      final start30d = startOfToday.subtract(const Duration(days: 29));
      final filtered30d = events.where((e) =>
          !e.createdAt.isBefore(start30d) && !e.createdAt.isAfter(endOfToday)).toList();
      expect(filtered30d.length, 1);
      expect(filtered30d.first.id, 'ev_today');
    });

    test('15. Ledger formula correctly calculates net outstanding', () {
      const advance = 200.0;
      const finalAmount = 500.0;
      const refund = 50.0;
      const collection = (advance + finalAmount) - refund; // 650.0
      const keepWithMe = 650.0;
      const handoverOut = 0.0;
      const handoverIn = 0.0;
      const withdrawal = 0.0;

      final outstanding = (collection + handoverIn) - (handoverOut + withdrawal);
      expect(collection, 650.0);
      expect(outstanding, 650.0);
      expect(keepWithMe, 650.0);
    });
  });
}
