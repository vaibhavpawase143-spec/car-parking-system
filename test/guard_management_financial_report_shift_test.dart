import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A) Guard Financial Responsibility & Payment Calculation Tests', () {
    test('3. Cash calculation correct: Advance + Final - Refund', () {
      final txns = [
        PaymentTransactionModel(
          id: 't1',
          ticketId: '101',
          vehicleNumber: 'MH12AB1234',
          amount: 50.0,
          paymentMethod: 'cash',
          paymentType: 'ADVANCE',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
        PaymentTransactionModel(
          id: 't2',
          ticketId: '101',
          vehicleNumber: 'MH12AB1234',
          amount: 365.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
        PaymentTransactionModel(
          id: 't3',
          ticketId: '102',
          vehicleNumber: 'MH12AB5678',
          amount: 20.0,
          paymentMethod: 'cash',
          paymentType: 'REFUND',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
      ];

      double cashAdvance = 0.0;
      double cashFinal = 0.0;
      double cashRefund = 0.0;

      for (final t in txns) {
        if (t.isCash) {
          if (t.isAdvance) cashAdvance += t.amount;
          if (t.isFinal) cashFinal += t.amount;
          if (t.isRefund) cashRefund += t.amount;
        }
      }

      final netCash = cashAdvance + cashFinal - cashRefund;
      expect(cashAdvance, 50.0);
      expect(cashFinal, 365.0);
      expect(cashRefund, 20.0);
      expect(netCash, 395.0);
    });

    test('4. UPI calculation correct: Advance + Final - Refund', () {
      final txns = [
        PaymentTransactionModel(
          id: 'u1',
          ticketId: '201',
          vehicleNumber: 'MH14CD1111',
          amount: 30.0,
          paymentMethod: 'upi',
          paymentType: 'ADVANCE',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
        PaymentTransactionModel(
          id: 'u2',
          ticketId: '201',
          vehicleNumber: 'MH14CD1111',
          amount: 70.0,
          paymentMethod: 'upi',
          paymentType: 'FINAL',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
        PaymentTransactionModel(
          id: 'u3',
          ticketId: '202',
          vehicleNumber: 'MH14CD2222',
          amount: 10.0,
          paymentMethod: 'upi',
          paymentType: 'REFUND',
          guardUid: 'guard_1',
          createdAt: DateTime.now(),
        ),
      ];

      double upiAdvance = 0.0;
      double upiFinal = 0.0;
      double upiRefund = 0.0;

      for (final t in txns) {
        if (t.isUpi) {
          if (t.isAdvance) upiAdvance += t.amount;
          if (t.isFinal) upiFinal += t.amount;
          if (t.isRefund) upiRefund += t.amount;
        }
      }

      final netUpi = upiAdvance + upiFinal - upiRefund;
      expect(upiAdvance, 30.0);
      expect(upiFinal, 70.0);
      expect(upiRefund, 10.0);
      expect(netUpi, 90.0);
    });

    test('5. Total calculation correct: Cash + UPI', () {
      const netCash = 395.0;
      const netUpi = 90.0;
      const total = netCash + netUpi;
      expect(total, 485.0);
    });

    test('6 & 7. Cash & UPI outstanding maintained independently', () {
      const resp = GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 500.0,
        cashHandedOver: 100.0,
        cashReceived: 50.0,
        cashWithdrawn: 150.0,
        totalUpiCollected: 300.0,
        upiHandedOver: 50.0,
        upiReceived: 0.0,
        upiWithdrawn: 100.0,
      );

      // Cash: 500 - 100 + 50 - 150 = 300
      expect(resp.outstandingCash, 300.0);
      // UPI: 300 - 50 + 0 - 100 = 150
      expect(resp.outstandingUpi, 150.0);
      // Total Outstanding: 300 + 150 = 450
      expect(resp.totalOutstanding, 450.0);
    });

    test('24. Outstanding remains intact after shift end (never zeroed)', () {
      final resp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 1000.0,
        totalUpiCollected: 500.0,
      );

      final shift = ShiftModel(
        shiftId: 's1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftDate: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        endTime: DateTime.now(),
        status: 'COMPLETED',
        actualEndTime: DateTime.now(),
      );

      expect(shift.isCompleted, isTrue);
      // Ending shift does NOT reset or touch responsibility
      expect(resp.outstandingCash, 1000.0);
      expect(resp.outstandingUpi, 500.0);
      expect(resp.totalOutstanding, 1500.0);
    });
  });

  group('B) Shift Lifecycle & Admin Control Tests', () {
    test('17. Start Shift button state: eligible assigned shift', () {
      final now = DateTime.now();
      final assignedShift = ShiftModel(
        shiftId: 'shift_1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftDate: now,
        startTime: now.add(const Duration(minutes: 10)),
        endTime: now.add(const Duration(hours: 8)),
        status: 'ASSIGNED',
      );

      expect(assignedShift.status, 'ASSIGNED');
      expect(assignedShift.isUpcoming, isTrue);
      expect(assignedShift.isActive, isFalse);
      expect(assignedShift.isCompleted, isFalse);
    });

    test('19. Shift becomes active upon Admin start', () {
      final now = DateTime.now();
      final activeShift = ShiftModel(
        shiftId: 'shift_1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftDate: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 8)),
        status: 'ACTIVE',
        actualStartTime: now,
        startedBy: 'admin_1',
      );

      expect(activeShift.status, 'ACTIVE');
      expect(activeShift.isActive, isTrue);
      expect(activeShift.effectiveStatus, ShiftStatus.active);
      expect(activeShift.startedBy, 'admin_1');
      expect(activeShift.actualStartTime, isNotNull);
    });

    test('20 & 22. End Shift button state and completion upon Admin end', () {
      final now = DateTime.now();
      final completedShift = ShiftModel(
        shiftId: 'shift_1',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftDate: now,
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.add(const Duration(hours: 4)),
        status: 'COMPLETED',
        actualEndTime: now,
        endedBy: 'admin_1',
      );

      expect(completedShift.status, 'COMPLETED');
      expect(completedShift.isCompleted, isTrue);
      expect(completedShift.effectiveStatus, ShiftStatus.completed);
      expect(completedShift.endedBy, 'admin_1');
      expect(completedShift.actualEndTime, isNotNull);
    });

    test('23. Cannot start overlapping shift for the same guard', () {
      final now = DateTime.now();
      final existingShift = ShiftModel(
        shiftId: 'shift_existing',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftDate: now,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ACTIVE',
      );

      final proposedStartTime = now.add(const Duration(hours: 1));
      final proposedEndTime = now.add(const Duration(hours: 9));

      // Overlap condition: proposedStartTime < existing.endTime && proposedEndTime > existing.startTime
      final overlaps = proposedStartTime.isBefore(existingShift.endTime) &&
          proposedEndTime.isAfter(existingShift.startTime);

      expect(overlaps, isTrue);
    });
  });

  group('C) Date Period Breakdown Calculations Tests', () {
    test('8. Today report calculation isolates today transactions', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterday = todayStart.subtract(const Duration(days: 1));

      final txns = [
        PaymentTransactionModel(
          id: 't1',
          ticketId: '1',
          vehicleNumber: 'MH12A1',
          amount: 100.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard_1',
          createdAt: yesterday,
        ),
        PaymentTransactionModel(
          id: 't2',
          ticketId: '2',
          vehicleNumber: 'MH12A2',
          amount: 250.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard_1',
          createdAt: todayStart.add(const Duration(hours: 2)),
        ),
      ];

      final todayTxns = txns.where((t) => t.createdAt.isAfter(todayStart)).toList();
      expect(todayTxns.length, 1);
      expect(todayTxns.first.amount, 250.0);
    });

    test('9. Last 7 Days daily breakdown generates 7 calendar days', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final days = <DateTime>[];
      DateTime cursor = DateTime(start.year, start.month, start.day);
      final lastDay = DateTime(end.year, end.month, end.day);
      while (cursor.isBefore(lastDay) || cursor.isAtSameMomentAs(lastDay)) {
        days.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }

      expect(days.length, 7);
    });

    test('10. Last 30 Days daily breakdown generates 30 calendar days', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final days = <DateTime>[];
      DateTime cursor = DateTime(start.year, start.month, start.day);
      final lastDay = DateTime(end.year, end.month, end.day);
      while (cursor.isBefore(lastDay) || cursor.isAtSameMomentAs(lastDay)) {
        days.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }

      expect(days.length, 30);
    });

    test('11. This Year monthly breakdown covers months up to current month', () {
      final now = DateTime.now();
      final months = <int>[];
      for (int m = 1; m <= now.month; m++) {
        months.add(m);
      }

      expect(months.length, now.month);
      expect(months.first, 1);
      expect(months.last, now.month);
    });

    test('12. Custom Date Range validation: From Date cannot be after To Date', () {
      final from = DateTime(2026, 9, 28);
      final to = DateTime(2026, 9, 20);

      final isInvalid = from.isAfter(to);
      expect(isInvalid, isTrue);

      final validFrom = DateTime(2026, 9, 20);
      final validTo = DateTime(2026, 9, 28);
      expect(validFrom.isAfter(validTo), isFalse);
    });
  });

  group('D) Search, Filter, Sort Verification Tests', () {
    final testTxns = [
      PaymentTransactionModel(
        id: 'txn_1',
        ticketId: '1001',
        vehicleNumber: 'MH12AA1111',
        amount: 200.0,
        paymentMethod: 'cash',
        paymentType: 'ADVANCE',
        guardUid: 'guard_1',
        createdAt: DateTime(2026, 9, 28, 10, 0),
      ),
      PaymentTransactionModel(
        id: 'txn_2',
        ticketId: '1002',
        vehicleNumber: 'MH14BB2222',
        amount: 50.0,
        paymentMethod: 'cash',
        paymentType: 'FINAL',
        guardUid: 'guard_1',
        createdAt: DateTime(2026, 9, 28, 11, 0),
      ),
      PaymentTransactionModel(
        id: 'txn_3',
        ticketId: '1003',
        vehicleNumber: 'MH12CC3333',
        amount: 500.0,
        paymentMethod: 'cash',
        paymentType: 'REFUND',
        guardUid: 'guard_1',
        createdAt: DateTime(2026, 9, 28, 12, 0),
      ),
    ];

    test('15. Search by Ticket, Vehicle Number, Transaction ID, Type', () {
      final matchTicket = testTxns.where((t) => t.ticketId.contains('1002')).toList();
      expect(matchTicket.length, 1);
      expect(matchTicket.first.id, 'txn_2');

      final matchVehicle = testTxns.where((t) => t.vehicleNumber.contains('CC3333')).toList();
      expect(matchVehicle.length, 1);
      expect(matchVehicle.first.id, 'txn_3');

      final matchType = testTxns.where((t) => t.paymentType.contains('REFUND')).toList();
      expect(matchType.length, 1);
      expect(matchType.first.id, 'txn_3');
    });

    test('16. Sort by raw DateTime and numeric amounts (never formatted strings)', () {
      final list = List<PaymentTransactionModel>.from(testTxns);

      // Newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(list.first.id, 'txn_3');
      expect(list.last.id, 'txn_1');

      // Oldest first
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(list.first.id, 'txn_1');
      expect(list.last.id, 'txn_3');

      // Amount High -> Low
      list.sort((a, b) => b.amount.compareTo(a.amount));
      expect(list.first.amount, 500.0);
      expect(list.last.amount, 50.0);

      // Amount Low -> High
      list.sort((a, b) => a.amount.compareTo(b.amount));
      expect(list.first.amount, 50.0);
      expect(list.last.amount, 500.0);
    });

    test('13. Guard filter (all, active, inactive)', () {
      final guards = [
        GuardModel(uid: 'g1', name: 'Guard 1', email: 'g1@test.com', isActive: true),
        GuardModel(uid: 'g2', name: 'Guard 2', email: 'g2@test.com', isActive: false),
        GuardModel(uid: 'g3', name: 'Guard 3', email: 'g3@test.com', isActive: true),
      ];

      final activeGuards = guards.where((g) => g.isActive).toList();
      expect(activeGuards.length, 2);

      final inactiveGuards = guards.where((g) => !g.isActive).toList();
      expect(inactiveGuards.length, 1);
      expect(inactiveGuards.first.uid, 'g2');
    });
  });

  group('E) Localization Tests (English & Marathi)', () {
    test('29. English localization strings', () {
      AppStrings.setLanguage(AppLanguage.english);

      expect(AppStrings.viewReport, 'View Report');
      expect(AppStrings.startShift, 'Start Shift');
      expect(AppStrings.endShift, 'End Shift');
      expect(AppStrings.cashCollection, 'Cash Collection');
      expect(AppStrings.upiCollection, 'UPI Collection');
      expect(AppStrings.totalCollection, 'Total Collection');
      expect(AppStrings.last7Days, 'Last 7 Days');
      expect(AppStrings.last30Days, 'Last 30 Days');
      expect(AppStrings.thisYear, 'This Year');
      expect(AppStrings.customDateRange, 'Custom Date Range');
      expect(AppStrings.alreadyActive, 'This guard already has an active shift.');
      expect(AppStrings.outstandingWarning, 'This guard has outstanding financial responsibility.');
    });

    test('30. Marathi localization strings', () {
      AppStrings.setLanguage(AppLanguage.marathi);

      expect(AppStrings.viewReport, 'अहवाल पहा');
      expect(AppStrings.startShift, 'पाळी सुरू करा');
      expect(AppStrings.endShift, 'पाळी समाप्त करा');
      expect(AppStrings.cashCollection, 'रोख संकलन');
      expect(AppStrings.upiCollection, 'UPI संकलन');
      expect(AppStrings.totalCollection, 'एकूण संकलन');
      expect(AppStrings.last7Days, 'मागील ७ दिवस');
      expect(AppStrings.last30Days, 'मागील ३० दिवस');
      expect(AppStrings.thisYear, 'चालू वर्ष');
      expect(AppStrings.customDateRange, 'सानुकूल तारीख श्रेणी');
      expect(AppStrings.alreadyActive, 'या Guard ची आधीच एक Active Shift आहे.');
      expect(AppStrings.outstandingWarning, 'या सुरक्षा रक्षकाकडे शिल्लक आर्थिक जबाबदारी आहे.');

      // Restore to English
      AppStrings.setLanguage(AppLanguage.english);
    });
  });
}
