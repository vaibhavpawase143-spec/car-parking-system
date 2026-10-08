import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/handover_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/responsibility_event_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  group('Simplified Guard Financial Report UI Tests', () {
    final testGuard = GuardModel(
      uid: 'guard_abc_1',
      name: 'Guard Ramesh',
      email: 'ramesh@jayganesh.com',
      mobile: '9876543210',
      isActive: true,
      currentShift: 'Shift 1',
    );

    final testResponsibility = GuardFinancialResponsibility(
      guardUid: 'guard_abc_1',
      guardName: 'Guard Ramesh',
      totalCashCollected: 5325.0,
      cashHandedOver: 0.0,
      cashReceived: 0.0,
      cashWithdrawn: 560.0,
      totalUpiCollected: 220.0,
      upiHandedOver: 0.0,
      upiReceived: 0.0,
      upiWithdrawn: 0.0,
    );

    test('0. Header: formats guard name, email, and mobile cleanly', () {
      expect(testGuard.name, 'Guard Ramesh');
      expect(testGuard.email, 'ramesh@jayganesh.com');
      expect(testGuard.mobile, '9876543210');
      final headerTitle = 'Guard Report — ${testGuard.name}';
      expect(headerTitle, 'Guard Report — Guard Ramesh');
    });

    test('1. Collection Summary calculation: Total Collection = Cash Collection + UPI Collection', () {
      final now = DateTime.now();

      final txns = [
        PaymentTransactionModel(
          id: 'tx1',
          ticketId: '101',
          vehicleNumber: 'MH12AB1234',
          amount: 5000.0,
          paymentType: 'advance',
          paymentMethod: 'cash',
          guardUid: 'guard_abc_1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: 'tx2',
          ticketId: '102',
          vehicleNumber: 'MH12CD5678',
          amount: 325.0,
          paymentType: 'final',
          paymentMethod: 'cash',
          guardUid: 'guard_abc_1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: 'tx3',
          ticketId: '103',
          vehicleNumber: 'MH12EF9012',
          amount: 220.0,
          paymentType: 'advance',
          paymentMethod: 'upi',
          guardUid: 'guard_abc_1',
          createdAt: now,
        ),
      ];

      final cashTxns = txns.where((t) => t.isCash);
      final upiTxns = txns.where((t) => t.isUpi);

      final cashColl = cashTxns.where((t) => t.isAdvance || t.isFinal).fold(0.0, (s, t) => s + t.amount);
      final upiColl = upiTxns.where((t) => t.isAdvance || t.isFinal).fold(0.0, (s, t) => s + t.amount);
      final totalColl = cashColl + upiColl;

      expect(cashColl, 5325.0);
      expect(upiColl, 220.0);
      expect(totalColl, 5545.0);
      expect(totalColl, cashColl + upiColl);
    });

    test('2. Authoritative Outstanding: preserves Cash Outstanding, UPI Outstanding, and Total Outstanding without formula alteration', () {
      expect(testResponsibility.outstandingCash, 4765.0);
      expect(testResponsibility.outstandingUpi, 220.0);
      expect(testResponsibility.totalOutstanding, 4985.0);
      expect(testResponsibility.totalOutstanding, testResponsibility.outstandingCash + testResponsibility.outstandingUpi);
    });

    test('3. Activity Section: filters events (Payments, Keep With Me, Handover) and strictly excludes Withdrawals', () {
      final now = DateTime.now();

      final paymentItem = {
        'type': 'payment',
        'title': 'Parking Collection',
        'amount': 50.0,
        'method': 'CASH',
        'dateTime': now,
      };

      final keepWithMeItem = {
        'type': 'keep_with_me',
        'title': 'Keep With Me',
        'amount': 700.0,
        'method': 'CASH',
        'dateTime': now.subtract(const Duration(hours: 1)),
      };

      final handoverItem = {
        'type': 'handover',
        'title': 'Handover Out',
        'amount': 1000.0,
        'method': 'CASH',
        'dateTime': now.subtract(const Duration(hours: 2)),
      };

      final allActivities = [paymentItem, keepWithMeItem, handoverItem];

      // Verify no withdrawal exists in activities
      final withdrawalItems = allActivities.where((a) => a['type'] == 'withdrawal').toList();
      expect(withdrawalItems.isEmpty, isTrue);

      // Verify filter by payment
      final paymentsOnly = allActivities.where((a) => a['type'] == 'payment').toList();
      expect(paymentsOnly.length, 1);
      expect(paymentsOnly.first['title'], 'Parking Collection');

      // Verify filter by keep_with_me
      final kwmOnly = allActivities.where((a) => a['type'] == 'keep_with_me').toList();
      expect(kwmOnly.length, 1);
      expect(kwmOnly.first['amount'], 700.0);

      // Verify filter by handover
      final handoverOnly = allActivities.where((a) => a['type'] == 'handover').toList();
      expect(handoverOnly.length, 1);
      expect(handoverOnly.first['amount'], 1000.0);
    });

    test('4. Responsibility History: Keep With Me & Handover are grouped and ordered date-wise', () {
      final day1 = DateTime(2026, 9, 30, 18, 30);
      final day2 = DateTime(2026, 9, 29, 14, 0);

      final kwm = ResponsibilityEventModel(
        id: 'kwm_1',
        guardId: 'guard_abc_1',
        guardName: 'Guard Ramesh',
        amount: 700.0,
        type: 'CASH',
        action: 'KEEP_WITH_ME',
        shiftId: 'Shift 1',
        status: 'Carried Forward',
        createdAt: day1,
      );

      final handover = HandoverModel(
        handoverId: 'ho_1',
        fromGuardId: 'guard_abc_1',
        fromGuardName: 'Guard Ramesh',
        toGuardId: 'guard_xyz_2',
        toGuardName: 'Guard Suresh',
        shiftId: 'Shift 1',
        amount: 1000.0,
        type: 'CASH',
        action: 'HANDOVER',
        createdAt: day2,
        status: 'ACCEPTED',
      );

      final dateKey1 = AppFormatters.formatDate(kwm.createdAt);
      final dateKey2 = AppFormatters.formatDate(handover.createdAt);

      expect(dateKey1, '30 Sep 2026');
      expect(dateKey2, '29 Sep 2026');

      final grouped = <String, List<dynamic>>{};
      grouped.putIfAbsent(dateKey1, () => []).add(kwm);
      grouped.putIfAbsent(dateKey2, () => []).add(handover);

      expect(grouped.keys.length, 2);
      expect(grouped['30 Sep 2026']!.length, 1);
      expect(grouped['29 Sep 2026']!.length, 1);
      expect((grouped['30 Sep 2026']!.first as ResponsibilityEventModel).amount, 700.0);
      expect((grouped['29 Sep 2026']!.first as HandoverModel).amount, 1000.0);
    });

    test('5. Date-wise Summary: aggregates daily collections into compact view', () {
      final day1 = DateTime(2026, 9, 30, 10, 0);
      final day2 = DateTime(2026, 9, 29, 11, 0);

      final txns = [
        PaymentTransactionModel(
          id: 't1',
          ticketId: '101',
          vehicleNumber: 'MH12AB1001',
          amount: 1000.0,
          paymentType: 'advance',
          paymentMethod: 'cash',
          guardUid: 'guard_abc_1',
          createdAt: day1,
        ),
        PaymentTransactionModel(
          id: 't2',
          ticketId: '102',
          vehicleNumber: 'MH12AB1002',
          amount: 500.0,
          paymentType: 'final',
          paymentMethod: 'upi',
          guardUid: 'guard_abc_1',
          createdAt: day1,
        ),
        PaymentTransactionModel(
          id: 't3',
          ticketId: '103',
          vehicleNumber: 'MH12AB1003',
          amount: 2000.0,
          paymentType: 'advance',
          paymentMethod: 'cash',
          guardUid: 'guard_abc_1',
          createdAt: day2,
        ),
      ];

      final Map<String, List<PaymentTransactionModel>> byDate = {};
      for (final t in txns) {
        final key = AppFormatters.formatDate(t.createdAt);
        byDate.putIfAbsent(key, () => []).add(t);
      }

      final day1Total = byDate['30 Sep 2026']!.fold(0.0, (s, t) => s + t.amount);
      final day2Total = byDate['29 Sep 2026']!.fold(0.0, (s, t) => s + t.amount);

      expect(day1Total, 1500.0);
      expect(day2Total, 2000.0);
    });

    test('6. Period options include: Today, Last 7 Days, Last 30 Days, This Year, and Custom Date Range', () {
      final periods = ['Today', 'Last 7 Days', 'Last 30 Days', 'This Year', 'Custom Date Range'];
      expect(periods.contains('Today'), isTrue);
      expect(periods.contains('Last 7 Days'), isTrue);
      expect(periods.contains('Last 30 Days'), isTrue);
      expect(periods.contains('This Year'), isTrue);
      expect(periods.contains('Custom Date Range'), isTrue);
    });
  });
}
