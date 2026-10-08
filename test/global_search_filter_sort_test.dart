import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/notification_model.dart';
import 'package:car_parking_system/models/audit_log_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  group('1. SEARCH NORMALIZATION & VEHICLE MATCHER TESTS', () {
    test('Vehicle number search normalizes uppercase, spaces, and hyphens', () {
      final input1 = 'mh 12 ab-1234';
      final norm1 = input1.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      expect(norm1, 'MH12AB1234');

      final target = 'MH-12-AB-1234';
      final targetNorm = target.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      expect(targetNorm.contains(norm1), isTrue);
    });

    test('Partial last digits vehicle search works safely', () {
      final record = ParkingRecord(
        id: 'rec_1',
        ticketNumber: '1004',
        vehicleNumber: 'MH 14 DE 5678',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime.now(),
        entryGuardUid: 'g1',
        entryGuardName: 'Ramesh',
        entryShift: 'Morning',
      );

      final query = '5678';
      final cleanQuery = query.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      final cleanVeh = record.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

      expect(cleanVeh.endsWith(cleanQuery), isTrue);
    });
  });

  group('2. ACTIVE PARKING — FILTER, SEARCH & NUMERIC SORT TESTS', () {
    final now = DateTime(2026, 9, 28, 12, 0);

    final recA = ParkingRecord(
      id: 'a',
      ticketNumber: '1001',
      vehicleNumber: 'MH 12 AA 1111',
      vehicleType: VehicleType.twoWheeler,
      entryTime: now.subtract(const Duration(hours: 5)), // Parked 5 hours
      entryGuardUid: 'g1',
      entryGuardName: 'Ramesh',
      entryShift: 'Morning',
      advanceAmount: 50.0,
      advancePaymentMethod: 'CASH',
    );

    final recB = ParkingRecord(
      id: 'b',
      ticketNumber: '1002',
      vehicleNumber: 'MH 14 ZZ 9999',
      vehicleType: VehicleType.fourWheeler,
      entryTime: now.subtract(const Duration(hours: 1)), // Parked 1 hour
      entryGuardUid: 'g2',
      entryGuardName: 'Suresh',
      entryShift: 'Morning',
      advanceAmount: 0.0,
    );

    final recC = ParkingRecord(
      id: 'c',
      ticketNumber: '1003',
      vehicleNumber: 'MH 12 BB 2222',
      vehicleType: VehicleType.fourWheeler,
      entryTime: now.subtract(const Duration(hours: 10)), // Parked 10 hours
      entryGuardUid: 'g1',
      entryGuardName: 'Ramesh',
      entryShift: 'Morning',
      advanceAmount: 100.0,
      advancePaymentMethod: 'UPI',
    );

    final allRecords = [recA, recB, recC];

    test('Filter by Two-Wheeler only', () {
      final filtered = allRecords.where((r) => r.vehicleType == VehicleType.twoWheeler).toList();
      expect(filtered.length, 1);
      expect(filtered.first.vehicleNumber, 'MH 12 AA 1111');
    });

    test('Filter by Four-Wheeler only', () {
      final filtered = allRecords.where((r) => r.vehicleType == VehicleType.fourWheeler).toList();
      expect(filtered.length, 2);
    });

    test('Filter by With Advance only', () {
      final filtered = allRecords.where((r) => r.advanceAmount > 0).toList();
      expect(filtered.length, 2);
      expect(filtered.any((r) => r.ticketNumber == '1002'), isFalse);
    });

    test('Sort by Longest Parked (Numeric DateTime)', () {
      final sorted = List<ParkingRecord>.from(allRecords);
      sorted.sort((a, b) => a.entryTime.compareTo(b.entryTime)); // Oldest entry = longest parked
      expect(sorted.first.ticketNumber, '1003'); // 10 hours
      expect(sorted.last.ticketNumber, '1002');  // 1 hour
    });

    test('Sort by Shortest Parked (Numeric DateTime)', () {
      final sorted = List<ParkingRecord>.from(allRecords);
      sorted.sort((a, b) => b.entryTime.compareTo(a.entryTime)); // Newest entry = shortest parked
      expect(sorted.first.ticketNumber, '1002'); // 1 hour
      expect(sorted.last.ticketNumber, '1003');  // 10 hours
    });

    test('Sort by Vehicle Number A-Z and Z-A', () {
      final sortedAZ = List<ParkingRecord>.from(allRecords);
      sortedAZ.sort((a, b) => a.vehicleNumber.compareTo(b.vehicleNumber));
      expect(sortedAZ.first.vehicleNumber, 'MH 12 AA 1111');
      expect(sortedAZ.last.vehicleNumber, 'MH 14 ZZ 9999');

      final sortedZA = List<ParkingRecord>.from(allRecords);
      sortedZA.sort((a, b) => b.vehicleNumber.compareTo(a.vehicleNumber));
      expect(sortedZA.first.vehicleNumber, 'MH 14 ZZ 9999');
      expect(sortedZA.last.vehicleNumber, 'MH 12 AA 1111');
    });

    test('Unified Pipeline: Search "MH 12" + Filter "Four-Wheeler" + Sort "Longest Parked"', () {
      final q = 'mh 12';
      final qNorm = q.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

      // 1. Search
      var result = allRecords.where((r) {
        final vehNorm = r.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        return vehNorm.contains(qNorm) || r.ticketNumber.contains(q);
      }).toList();
      expect(result.length, 2); // recA and recC

      // 2. Filter: 4-Wheeler
      result = result.where((r) => r.vehicleType == VehicleType.fourWheeler).toList();
      expect(result.length, 1);
      expect(result.first.ticketNumber, '1003');

      // 3. Sort: Longest parked
      result.sort((a, b) => a.entryTime.compareTo(b.entryTime));
      expect(result.first.id, 'c');
    });
  });

  group('3. PAYMENT TRANSACTIONS — AUTHORIZATION, FILTER, SORT & FORMULAS', () {
    final txn1 = PaymentTransactionModel(
      id: 'TXN-001',
      ticketId: '1001',
      vehicleNumber: 'MH 12 AA 1111',
      paymentMethod: 'CASH',
      paymentType: 'ADVANCE',
      amount: 40.0,
      createdAt: DateTime(2026, 9, 28, 9, 0),
      guardUid: 'guard_1',
      guardName: 'Ramesh',
      shift: 'Morning',
    );

    final txn2 = PaymentTransactionModel(
      id: 'TXN-002',
      ticketId: '1002',
      vehicleNumber: 'MH 12 BB 2222',
      paymentMethod: 'UPI',
      paymentType: 'FINAL',
      amount: 120.0,
      createdAt: DateTime(2026, 9, 28, 10, 0),
      guardUid: 'guard_1',
      guardName: 'Ramesh',
      shift: 'Morning',
    );

    final txn3 = PaymentTransactionModel(
      id: 'TXN-003',
      ticketId: '1003',
      vehicleNumber: 'MH 14 CC 3333',
      paymentMethod: 'CASH',
      paymentType: 'REFUND',
      amount: 20.0,
      createdAt: DateTime(2026, 9, 28, 11, 0),
      guardUid: 'guard_2',
      guardName: 'Suresh',
      shift: 'Morning',
    );

    final allTxns = [txn1, txn2, txn3];

    test('Guard isolation: guard_1 only sees guard_1 transactions', () {
      final authorized = allTxns.where((t) => t.guardUid == 'guard_1').toList();
      expect(authorized.length, 2);
      expect(authorized.any((t) => t.guardUid == 'guard_2'), isFalse);
    });

    test('Authoritative Payment Ledger Formulas: Cash and UPI', () {
      // guard_1 has Cash Advance 40, UPI Final 120
      double cashAdvance = 0, cashFinal = 0, cashRefund = 0;
      double upiAdvance = 0, upiFinal = 0, upiRefund = 0;

      for (final t in allTxns.where((t) => t.guardUid == 'guard_1')) {
        if (t.isCash) {
          if (t.isAdvance) cashAdvance += t.amount;
          if (t.isFinal) cashFinal += t.amount;
          if (t.isRefund) cashRefund += t.amount;
        } else if (t.isUpi) {
          if (t.isAdvance) upiAdvance += t.amount;
          if (t.isFinal) upiFinal += t.amount;
          if (t.isRefund) upiRefund += t.amount;
        }
      }

      final netCash = cashAdvance + cashFinal - cashRefund;
      final netUpi = upiAdvance + upiFinal - upiRefund;
      final total = netCash + netUpi;

      expect(netCash, 40.0);
      expect(netUpi, 120.0);
      expect(total, 160.0);
    });

    test('Sort by Numeric Amount (Highest to Lowest, Lowest to Highest)', () {
      final sortedHigh = List<PaymentTransactionModel>.from(allTxns);
      sortedHigh.sort((a, b) => b.amount.compareTo(a.amount));
      expect(sortedHigh[0].amount, 120.0);
      expect(sortedHigh[1].amount, 40.0);
      expect(sortedHigh[2].amount, 20.0);

      final sortedLow = List<PaymentTransactionModel>.from(allTxns);
      sortedLow.sort((a, b) => a.amount.compareTo(b.amount));
      expect(sortedLow[0].amount, 20.0);
      expect(sortedLow[2].amount, 120.0);
    });
  });

  group('4. FINANCIAL RESPONSIBILITY — CASH & UPI INDEPENDENCE', () {
    final g1 = GuardFinancialRecord(
      guard: const GuardModel(uid: 'g1', name: 'Ramesh Pawar', email: 'ramesh@park.in', mobile: '9876543210', currentShift: 'Shift-A'),
      responsibility: const GuardFinancialResponsibility(
        guardUid: 'g1',
        guardName: 'Ramesh Pawar',
        totalCashCollected: 300,
        cashHandedOver: 150,
        cashWithdrawn: 0,
        totalUpiCollected: 100,
        upiHandedOver: 0,
        upiWithdrawn: 100,
      ),
      lastActivity: DateTime(2026, 9, 28, 10, 0),
    );

    final g2 = GuardFinancialRecord(
      guard: const GuardModel(uid: 'g2', name: 'Anil Jadhav', email: 'anil@park.in', mobile: '9876543211', currentShift: 'Shift-B'),
      responsibility: const GuardFinancialResponsibility(
        guardUid: 'g2',
        guardName: 'Anil Jadhav',
        totalCashCollected: 1000,
        cashHandedOver: 200,
        cashWithdrawn: 0,
        totalUpiCollected: 500,
        upiHandedOver: 100,
        upiWithdrawn: 0,
      ),
      lastActivity: DateTime(2026, 9, 28, 11, 0),
    );

    final records = [g1, g2];

    test('Cash and UPI outstanding amounts are strictly independent', () {
      // g1: Cash = 300 - 150 - 0 = 150
      // g1: UPI = 100 - 0 - 100 = 0
      expect(g1.responsibility.outstandingCash, 150.0);
      expect(g1.responsibility.outstandingUpi, 0.0);

      // g2: Cash = 1000 - 200 - 0 = 800
      // g2: UPI = 500 - 100 - 0 = 400
      expect(g2.responsibility.outstandingCash, 800.0);
      expect(g2.responsibility.outstandingUpi, 400.0);
    });

    test('Sort Cash by Highest Outstanding', () {
      final sorted = List<GuardFinancialRecord>.from(records);
      sorted.sort((a, b) => b.responsibility.outstandingCash.compareTo(a.responsibility.outstandingCash));
      expect(sorted.first.guard.name, 'Anil Jadhav'); // 800
      expect(sorted.last.guard.name, 'Ramesh Pawar'); // 150
    });

    test('Sort by Guard Name A-Z', () {
      final sorted = List<GuardFinancialRecord>.from(records);
      sorted.sort((a, b) => a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase()));
      expect(sorted.first.guard.name, 'Anil Jadhav');
      expect(sorted.last.guard.name, 'Ramesh Pawar');
    });
  });

  group('5. HANDOVER & WITHDRAWAL LEDGERS', () {
    final h1 = HandoverModel(
      handoverId: 'HO-101',
      fromGuardId: 'g1',
      fromGuardName: 'Ramesh',
      toGuardId: 'g2',
      toGuardName: 'Suresh',
      shiftId: 'SHIFT-01',
      amount: 500.0,
      type: 'CASH',
      createdAt: DateTime(2026, 9, 28, 8, 0),
      status: 'PENDING',
    );

    final h2 = HandoverModel(
      handoverId: 'HO-102',
      fromGuardId: 'g2',
      fromGuardName: 'Suresh',
      toGuardId: 'g1',
      toGuardName: 'Ramesh',
      shiftId: 'SHIFT-02',
      amount: 1200.0,
      type: 'UPI',
      createdAt: DateTime(2026, 9, 28, 9, 0),
      status: 'ACCEPTED',
    );

    final handovers = [h1, h2];

    test('Search handover by ID, Guard, Shift', () {
      final byId = handovers.where((h) => h.handoverId.contains('HO-101')).toList();
      expect(byId.length, 1);
      expect(byId.first.fromGuardName, 'Ramesh');

      final byShift = handovers.where((h) => h.shiftId.contains('SHIFT-02')).toList();
      expect(byShift.length, 1);
      expect(byShift.first.type, 'UPI');
    });

    test('Filter handovers by status and type', () {
      final pending = handovers.where((h) => h.status == 'PENDING').toList();
      expect(pending.length, 1);
      expect(pending.first.amount, 500.0);

      final upiOnly = handovers.where((h) => h.type == 'UPI').toList();
      expect(upiOnly.length, 1);
      expect(upiOnly.first.status, 'ACCEPTED');
    });

    test('Sort handovers by Amount and DateTime', () {
      final sortedAmt = List<HandoverModel>.from(handovers);
      sortedAmt.sort((a, b) => b.amount.compareTo(a.amount));
      expect(sortedAmt.first.handoverId, 'HO-102'); // 1200 > 500

      final sortedDate = List<HandoverModel>.from(handovers);
      sortedDate.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sortedDate.first.handoverId, 'HO-102'); // 9:00 > 8:00
    });
  });

  group('6. ADMIN SHIFTS & GUARD DIRECTORY', () {
    final shift1 = ShiftModel(
      shiftId: 's1',
      guardId: 'g1',
      guardUid: 'g1',
      guardName: 'Ramesh Pawar',
      guardEmail: 'ramesh@park.in',
      shiftDate: DateTime(2026, 9, 28),
      startTime: DateTime(2026, 9, 28, 8, 0),
      endTime: DateTime(2026, 9, 28, 16, 0),
      status: 'COMPLETED',
      durationHours: 8,
      createdAt: DateTime(2026, 9, 27),
    );

    final shift2 = ShiftModel(
      shiftId: 's2',
      guardId: 'g2',
      guardUid: 'g2',
      guardName: 'Anil Jadhav',
      guardEmail: 'anil@park.in',
      shiftDate: DateTime(2026, 9, 28),
      startTime: DateTime(2026, 9, 28, 16, 0),
      endTime: DateTime(2026, 9, 29, 2, 0),
      status: 'ASSIGNED',
      durationHours: 10,
      createdAt: DateTime(2026, 9, 27),
    );

    final shifts = [shift1, shift2];

    test('Search shift by guard name or shift id', () {
      final found = shifts.where((s) => s.guardName.toLowerCase().contains('anil') || s.shiftId == 's2').toList();
      expect(found.length, 1);
      expect(found.first.durationHours, 10);
    });

    test('Sort shift by Start Time Newest first', () {
      final sorted = List<ShiftModel>.from(shifts);
      sorted.sort((a, b) => b.startTime.compareTo(a.startTime));
      expect(sorted.first.shiftId, 's2'); // 16:00 is newer than 8:00
    });

    test('Sort shift by Duration (numeric)', () {
      final sorted = List<ShiftModel>.from(shifts);
      sorted.sort((a, b) => b.durationHours.compareTo(a.durationHours));
      expect(sorted.first.durationHours, 10);
      expect(sorted.last.durationHours, 8);
    });
  });

  group('7. NOTIFICATIONS & AUDIT LOGS', () {
    final notif1 = NotificationModel(
      notificationId: 'n1',
      recipientUserId: 'g1',
      title: 'Shift Started',
      message: 'Guard Ramesh checked into Morning shift',
      type: 'shift',
      createdAt: DateTime(2026, 9, 28, 8, 5),
      isRead: true,
    );

    final notif2 = NotificationModel(
      notificationId: 'n2',
      recipientUserId: 'admin',
      title: 'Full Cash Handover Request',
      message: 'Suresh requested full cash handover of ₹500',
      type: 'handover',
      createdAt: DateTime(2026, 9, 28, 12, 10),
      isRead: false,
    );

    final notifs = [notif1, notif2];

    test('Filter notifications by Category and Read/Unread', () {
      final handoverNotifs = notifs.where((n) => n.type == 'handover').toList();
      expect(handoverNotifs.length, 1);
      expect(handoverNotifs.first.notificationId, 'n2');

      final unread = notifs.where((n) => !n.isRead).toList();
      expect(unread.length, 1);
      expect(unread.first.notificationId, 'n2');
    });

    test('Sort notifications Newest First', () {
      final sorted = List<NotificationModel>.from(notifs);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.first.notificationId, 'n2');
      expect(sorted.last.notificationId, 'n1');
    });

    final log1 = AuditLogModel(
      id: 'l1',
      adminName: 'Admin Super',
      adminUid: 'admin_1',
      action: 'ADMIN_WITHDRAWAL_CASH',
      targetEntity: 'FinancialResponsibility',
      targetId: 'g1',
      details: {'amount': 300},
      timestamp: DateTime(2026, 9, 28, 11, 30),
    );

    final log2 = AuditLogModel(
      id: 'l2',
      adminName: 'Admin Super',
      adminUid: 'admin_1',
      action: 'VEHICLE_EXIT',
      targetEntity: 'ParkingRecord',
      targetId: 'rec_1001',
      details: {'fee': 40},
      timestamp: DateTime(2026, 9, 28, 12, 0),
    );

    final logs = [log1, log2];

    test('Search audit logs by Actor, Action, Entity, EntityId', () {
      final withdrawalLogs = logs.where((l) => l.action.contains('WITHDRAWAL') || l.targetId == 'g1').toList();
      expect(withdrawalLogs.length, 1);
      expect(withdrawalLogs.first.adminName, 'Admin Super');
    });

    test('Sort audit logs Newest First using actual DateTime', () {
      final sorted = List<AuditLogModel>.from(logs);
      sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      expect(sorted.first.id, 'l2');
      expect(sorted.last.id, 'l1');
    });
  });
}
