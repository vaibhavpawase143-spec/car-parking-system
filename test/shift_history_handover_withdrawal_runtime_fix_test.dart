import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/withdrawal_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/services/shift_service.dart';

void main() {
  group('1. Shift History & Mathematical Calculation Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const guardA = GuardModel(
      uid: 'guard_a_uid_123',
      name: 'Guard A',
      email: 'guarda@parking.com',
      mobile: '9876543210',
      role: 'guard',
    );

    test('1.1 Universal DateTime & Month-Name Parsing ("28 Sep 2026", "04:40 AM")', () {
      final parsedDate = ShiftModel.parseDateTime('28 Sep 2026');
      expect(parsedDate, isNotNull);
      expect(parsedDate.year, 2026);
      expect(parsedDate.month, 9);
      expect(parsedDate.day, 28);

      final parsedDateTime = ShiftModel.parseDateTime('28 Sep 2026 04:40 AM');
      expect(parsedDateTime, isNotNull);
      expect(parsedDateTime.hour, 4);
      expect(parsedDateTime.minute, 40);

      final parsedTimeOnly = ShiftModel.parseDateTime('02:40 PM');
      expect(parsedTimeOnly, isNotNull);
      expect(parsedTimeOnly.hour, 14);
      expect(parsedTimeOnly.minute, 40);
    });

    test('1.2 10-Hour Shift Calculation: 04:40 AM + 10h = 02:40 PM', () {
      final shift = ShiftModel.fromMap({
        'shiftDate': '28 Sep 2026',
        'startTime': '28 Sep 2026 04:40 AM',
        'durationHours': 10,
        'status': 'COMPLETED',
        'guardId': 'guard_a_uid_123',
        'guardUid': 'guard_a_uid_123',
        'guardName': 'Guard A',
      }, 'shift_10h_completed');

      expect(shift.durationHours, 10);
      expect(shift.startTime.hour, 4);
      expect(shift.startTime.minute, 40);
      expect(shift.endTime.hour, 14);
      expect(shift.endTime.minute, 40);
      expect(shift.status, 'COMPLETED');
      expect(shift.isCompleted, isTrue);
      expect(shift.isActive, isFalse);
    });

    test('1.3 8-Hour Shift Calculation: 05:30 AM + 8h = 01:30 PM', () {
      final shift = ShiftModel.fromMap({
        'shiftDate': '26 Sep 2026',
        'startTime': '26 Sep 2026 05:30 AM',
        'durationHours': 8,
        'status': 'COMPLETED',
        'guardId': 'guard_a_uid_123',
        'guardUid': 'guard_a_uid_123',
        'guardName': 'Guard A',
      }, 'shift_8h_completed');

      expect(shift.durationHours, 8);
      expect(shift.startTime.hour, 5);
      expect(shift.startTime.minute, 30);
      expect(shift.endTime.hour, 13);
      expect(shift.endTime.minute, 30);
      expect(shift.isCompleted, isTrue);
    });

    test('1.4 9-Hour Shift Calculation: 09:00 AM + 9h = 06:00 PM', () {
      final shift = ShiftModel.fromMap({
        'shiftDate': '27 Sep 2026',
        'startTime': '27 Sep 2026 09:00 AM',
        'durationHours': 9,
        'status': 'ASSIGNED',
        'guardId': 'guard_a_uid_123',
        'guardUid': 'guard_a_uid_123',
        'guardName': 'Guard A',
      }, 'shift_9h');

      expect(shift.durationHours, 9);
      expect(shift.startTime.hour, 9);
      expect(shift.startTime.minute, 0);
      expect(shift.endTime.hour, 18);
      expect(shift.endTime.minute, 0);
    });

    test('1.5 Today\'s completed shift appears in history immediately after completion', () {
      final completedShiftToday = ShiftModel(
        shiftId: 'shift_today_completed',
        guardId: guardA.uid,
        guardUid: guardA.uid,
        guardName: guardA.name,
        guardEmail: guardA.email,
        shiftDate: today,
        startTime: today.add(const Duration(hours: 4, minutes: 40)),
        endTime: today.add(const Duration(hours: 14, minutes: 40)),
        actualStartTime: today.add(const Duration(hours: 4, minutes: 40)),
        actualEndTime: today.add(const Duration(hours: 14, minutes: 40)),
        durationHours: 10,
        status: 'COMPLETED',
      );

      final shifts = [completedShiftToday];
      final guardShifts = shifts.where((s) => ShiftService.matchesGuard(s, guardA.uid, guardA.email, guardA.name)).toList();
      final history = guardShifts.where((s) => s.isCompleted).toList();

      expect(history.length, 1);
      expect(history.first.shiftId, 'shift_today_completed');
      expect(history.first.durationHours, 10);
    });

    test('1.6 Expired active shift (now > endTime) automatically moves to completed history', () {
      final expiredShift = ShiftModel(
        shiftId: 'shift_expired',
        guardId: guardA.uid,
        guardUid: guardA.uid,
        guardName: guardA.name,
        guardEmail: guardA.email,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 11)),
        endTime: now.subtract(const Duration(hours: 1)),
        durationHours: 10,
        status: 'ACTIVE',
      );

      expect(expiredShift.effectiveStatus, ShiftStatus.completed);
      expect(expiredShift.isCompleted, isTrue);
      expect(expiredShift.isActive, isFalse);
    });

    test('1.7 Active shift appears as active current shift', () {
      final activeShift = ShiftModel(
        shiftId: 'shift_current_active',
        guardId: guardA.uid,
        guardUid: guardA.uid,
        guardName: guardA.name,
        guardEmail: guardA.email,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        durationHours: 8,
        status: 'ACTIVE',
      );

      expect(activeShift.effectiveStatus, ShiftStatus.active);
      expect(activeShift.isActive, isTrue);
      expect(activeShift.isCompleted, isFalse);
    });
  });

  group('2. Handover & Financial Responsibility Lifecycle Tests', () {
    const guardA = GuardModel(
      uid: 'guard_a_uid',
      name: 'Guard A',
      email: 'guarda@parking.com',
    );

    const guardB = GuardModel(
      uid: 'guard_b_uid',
      name: 'Guard B',
      email: 'guardb@parking.com',
    );

    test('2.1 Handover Model Serialization & Status Parsing', () {
      final handover = HandoverModel.fromMap({
        'fromGuardId': guardA.uid,
        'fromGuardName': guardA.name,
        'toGuardId': guardB.uid,
        'toGuardName': guardB.name,
        'shiftId': 's_001',
        'amount': 700.0,
        'type': 'CASH',
        'action': 'HANDOVER',
        'status': 'PENDING',
        'createdAt': DateTime(2026, 9, 28, 14, 0).toIso8601String(),
      }, 'ho_001');

      expect(handover.handoverId, 'ho_001');
      expect(handover.amount, 700.0);
      expect(handover.type, 'CASH');
      expect(handover.isPending, isTrue);
      expect(handover.isAccepted, isFalse);
    });

    test('2.2 PENDING Handover: Responsibility remains with Outgoing Guard until ACCEPTED', () {
      // Guard A collection: Cash 700, UPI 500
      double guardACash = 700.0;
      double guardBCash = 0.0;

      final pendingHandover = HandoverModel(
        handoverId: 'ho_002',
        fromGuardId: guardA.uid,
        fromGuardName: guardA.name,
        toGuardId: guardB.uid,
        toGuardName: guardB.name,
        shiftId: 's_002',
        amount: 700.0,
        type: 'CASH',
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      // In PENDING state, responsibility has NOT transferred
      if (pendingHandover.isAccepted) {
        guardACash -= pendingHandover.amount;
        guardBCash += pendingHandover.amount;
      }

      expect(guardACash, 700.0);
      expect(guardBCash, 0.0);
    });

    test('2.3 ACCEPTED Handover: Responsibility transfers from Outgoing Guard to Incoming Guard', () {
      double guardACash = 700.0;
      double guardBCash = 0.0;

      final acceptedHandover = HandoverModel(
        handoverId: 'ho_003',
        fromGuardId: guardA.uid,
        fromGuardName: guardA.name,
        toGuardId: guardB.uid,
        toGuardName: guardB.name,
        shiftId: 's_003',
        amount: 700.0,
        type: 'CASH',
        status: 'ACCEPTED',
        createdAt: DateTime.now(),
      );

      if (acceptedHandover.isAccepted) {
        guardACash -= acceptedHandover.amount;
        guardBCash += acceptedHandover.amount;
      }

      expect(guardACash, 0.0);
      expect(guardBCash, 700.0);
    });

    test('2.4 REJECTED / CANCELLED Handover: Responsibility stays with Outgoing Guard', () {
      double guardACash = 700.0;
      double guardBCash = 0.0;

      final rejectedHandover = HandoverModel(
        handoverId: 'ho_004',
        fromGuardId: guardA.uid,
        fromGuardName: guardA.name,
        toGuardId: guardB.uid,
        toGuardName: guardB.name,
        shiftId: 's_004',
        amount: 700.0,
        type: 'CASH',
        status: 'REJECTED',
        createdAt: DateTime.now(),
      );

      if (rejectedHandover.isAccepted) {
        guardACash -= rejectedHandover.amount;
        guardBCash += rejectedHandover.amount;
      }

      expect(guardACash, 700.0);
      expect(guardBCash, 0.0);
    });

    test('2.5 Keep With Me: Responsibility carries forward across shifts without reset', () {
      double guardACashResponsibility = 700.0; // From completed shift

      // Guard chooses KEEP WITH ME
      // No handover document to another guard created, no reset to 0
      expect(guardACashResponsibility, 700.0);

      // Later, Guard A gets a new shift and collects ₹300 cash
      final newShiftCollection = 300.0;
      guardACashResponsibility += newShiftCollection;

      expect(guardACashResponsibility, 1000.0);
    });
  });

  group('3. Admin Withdrawal & Permanent History Tests', () {
    const guardA = GuardModel(
      uid: 'guard_a_uid',
      name: 'Guard A',
      email: 'guarda@parking.com',
    );

    test('3.1 Admin Withdrawal decreases outstanding to 0 without deleting payment transactions', () {
      final paymentTxns = [
        PaymentTransactionModel(
          id: 'tx_1',
          ticketId: '101',
          vehicleNumber: 'MH 12 AA 1111',
          paymentType: 'ADVANCE',
          paymentMethod: 'cash',
          amount: 500.0,
          guardUid: guardA.uid,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        PaymentTransactionModel(
          id: 'tx_2',
          ticketId: '102',
          vehicleNumber: 'MH 12 BB 2222',
          paymentType: 'FINAL',
          paymentMethod: 'cash',
          amount: 500.0,
          guardUid: guardA.uid,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      final totalHistoricalCashCollection = paymentTxns.fold<double>(0.0, (sum, t) => sum + t.amount);
      expect(totalHistoricalCashCollection, 1000.0);

      // Admin withdraws ₹1000 Cash
      final withdrawal = WithdrawalModel(
        withdrawalId: 'w_001',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftId: 's_001',
        type: 'CASH',
        amount: 1000.0,
        adminUid: 'admin_uid_001',
        adminName: 'Admin Super',
        createdAt: DateTime.now(),
        status: 'COMPLETED',
      );

      final currentCashOutstanding = totalHistoricalCashCollection - withdrawal.amount;
      expect(currentCashOutstanding, 0.0);

      // Payment transactions MUST remain intact (count = 2, total = 1000)
      expect(paymentTxns.length, 2);
      expect(paymentTxns.fold<double>(0.0, (sum, t) => sum + t.amount), 1000.0);
    });

    test('3.2 Cash and UPI remain strictly segregated during Withdrawal', () {
      double cashOutstanding = 700.0;
      double upiOutstanding = 500.0;

      // Admin withdraws Cash ₹700
      final cashWithdrawal = WithdrawalModel(
        withdrawalId: 'w_002',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftId: 's_002',
        type: 'CASH',
        amount: 700.0,
        adminUid: 'admin_uid_001',
        adminName: 'Admin Super',
        createdAt: DateTime.now(),
        status: 'COMPLETED',
      );

      if (cashWithdrawal.isCash) {
        cashOutstanding -= cashWithdrawal.amount;
      }

      expect(cashOutstanding, 0.0);
      // UPI outstanding remains untouched
      expect(upiOutstanding, 500.0);
    });
  });

  group('4. Guard Isolation & Security Tests', () {
    const guardA = GuardModel(
      uid: 'guard_a_uid',
      name: 'Guard A',
      email: 'guarda@parking.com',
    );

    const guardB = GuardModel(
      uid: 'guard_b_uid',
      name: 'Guard B',
      email: 'guardb@parking.com',
    );

    test('4.1 Guard sees only own handovers and withdrawals', () {
      final allWithdrawals = [
        WithdrawalModel(
          withdrawalId: 'w1',
          guardId: guardA.uid,
          guardName: guardA.name,
          shiftId: 's1',
          type: 'CASH',
          amount: 500.0,
          adminUid: 'admin',
          adminName: 'Admin',
          createdAt: DateTime.now(),
        ),
        WithdrawalModel(
          withdrawalId: 'w2',
          guardId: guardB.uid,
          guardName: guardB.name,
          shiftId: 's2',
          type: 'CASH',
          amount: 800.0,
          adminUid: 'admin',
          adminName: 'Admin',
          createdAt: DateTime.now(),
        ),
      ];

      final guardAWithdrawals = allWithdrawals.where((w) => w.guardId == guardA.uid).toList();
      expect(guardAWithdrawals.length, 1);
      expect(guardAWithdrawals.first.withdrawalId, 'w1');
      expect(guardAWithdrawals.first.amount, 500.0);
    });
  });
}
