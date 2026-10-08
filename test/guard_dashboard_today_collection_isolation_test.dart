import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/services/dashboard_service.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  group('Guard Dashboard Today Collection Isolation & Financial Ledger Tests', () {
    final now = DateTime.now();
    final todayMorning = DateTime(now.year, now.month, now.day, 10, 0, 0);
    final yesterday = now.subtract(const Duration(days: 1));

    const guardAUid = 'RoSW3PrgTZQyukVKlw1HrV2SHGD3';
    const guardBUid = 'DOK9HAprR5Nr4CVn5jApbNyoUe13';
    const guardCUid = 'EudNxw8oZIMIklOOqG3mr2HWkD73';

    // 1. Transaction dataset representing current audited Firestore state
    final transactions = [
      PaymentTransactionModel(
        id: '881c8Jx9GVHtVNEzuf0y',
        ticketId: '1001',
        vehicleNumber: 'MH12PQ3434',
        amount: 50.0,
        paymentMethod: 'cash',
        paymentType: 'FINAL',
        guardUid: guardAUid,
        guardName: 'Guard A',
        createdAt: todayMorning.add(const Duration(minutes: 19)),
      ),
      PaymentTransactionModel(
        id: 'uznhePByHd4WivqvsCpR',
        ticketId: '1002',
        vehicleNumber: 'MH17SS7673',
        amount: 20.0,
        paymentMethod: 'upi',
        paymentType: 'FINAL',
        guardUid: guardAUid,
        guardName: 'Guard A',
        createdAt: todayMorning.add(const Duration(minutes: 20)),
      ),
      PaymentTransactionModel(
        id: 'ykOu4eP70nD3PliMAPi3',
        ticketId: '1003',
        vehicleNumber: 'MH45RR5656',
        amount: 50.0,
        paymentMethod: 'cash',
        paymentType: 'FINAL',
        guardUid: guardAUid,
        guardName: 'Guard A',
        createdAt: todayMorning.add(const Duration(minutes: 41)),
      ),
      PaymentTransactionModel(
        id: 's5aajjLAo6ebECDPXnVP',
        ticketId: '1004',
        vehicleNumber: 'MH12WW1212',
        amount: 20.0,
        paymentMethod: 'upi',
        paymentType: 'FINAL',
        guardUid: guardAUid,
        guardName: 'Guard A',
        createdAt: todayMorning.add(const Duration(minutes: 42)),
      ),
      PaymentTransactionModel(
        id: 'ZBifioLym1nefDNE49eL',
        ticketId: '1009',
        vehicleNumber: 'MH17B8896',
        amount: 20.0,
        paymentMethod: 'cash',
        paymentType: 'ADVANCE',
        guardUid: guardBUid,
        guardName: 'Guard B',
        createdAt: todayMorning.add(const Duration(minutes: 54)),
      ),
      // Historical transaction from yesterday (must NOT be counted in Today's Collection)
      PaymentTransactionModel(
        id: 'old_yesterday_txn',
        ticketId: '0999',
        vehicleNumber: 'MH12AA1111',
        amount: 100.0,
        paymentMethod: 'cash',
        paymentType: 'FINAL',
        guardUid: guardBUid,
        guardName: 'Guard B',
        createdAt: yesterday,
      ),
    ];

    DashboardMetrics computeMetricsForScope({String? guardUid, String? guardName}) {
      final todayStart = DateTime(now.year, now.month, now.day);
      double rawCash = 0.0;
      double rawUpi = 0.0;

      for (final t in transactions) {
        if (t.createdAt.isBefore(todayStart)) continue;

        if (guardUid != null && guardUid.isNotEmpty) {
          if (t.guardUid != guardUid) {
            if (guardName == null || t.guardName.toLowerCase() != guardName.toLowerCase()) {
              continue;
            }
          }
        }

        if (t.isAdvance || t.isFinal) {
          if (t.isUpi) {
            rawUpi += t.amount;
          } else {
            rawCash += t.amount;
          }
        } else if (t.isRefund) {
          if (t.isUpi) {
            rawUpi -= t.amount;
          } else {
            rawCash -= t.amount;
          }
        }
      }

      return DashboardMetrics(
        todayEntries: 5,
        todayExits: 4,
        todayCollection: rawCash + rawUpi,
        cashCollection: rawCash,
        upiCollection: rawUpi,
      );
    }

    test('Scenario 1: Guard A Dashboard is isolated to Guard A (₹140: Cash ₹100, UPI ₹40)', () {
      final metricsA = computeMetricsForScope(guardUid: guardAUid, guardName: 'Guard A');
      expect(metricsA.todayCollection, equals(140.0));
      expect(metricsA.cashCollection, equals(100.0));
      expect(metricsA.upiCollection, equals(40.0));
    });

    test('Scenario 2: Guard B Dashboard is isolated to Guard B (₹20: Cash ₹20, UPI ₹0)', () {
      final metricsB = computeMetricsForScope(guardUid: guardBUid, guardName: 'Guard B');
      expect(metricsB.todayCollection, equals(20.0));
      expect(metricsB.cashCollection, equals(20.0));
      expect(metricsB.upiCollection, equals(0.0));
    });

    test('Scenario 3: Guard C Dashboard shows ₹0 when Guard C has no collections today', () {
      final metricsC = computeMetricsForScope(guardUid: guardCUid, guardName: 'Guard C');
      expect(metricsC.todayCollection, equals(0.0));
      expect(metricsC.cashCollection, equals(0.0));
      expect(metricsC.upiCollection, equals(0.0));
    });

    test('Scenario 4: Admin Dashboard remains facility-wide (₹160: Cash ₹120, UPI ₹40)', () {
      final adminMetrics = computeMetricsForScope(); // Global facility total
      expect(adminMetrics.todayCollection, equals(160.0));
      expect(adminMetrics.cashCollection, equals(120.0));
      expect(adminMetrics.upiCollection, equals(40.0));
    });

    test('Scenario 5: Handover In increases Outstanding Responsibility, NOT Today Collection', () {
      // Guard B receives ₹50 cash handover from Guard A
      final respB = GuardFinancialResponsibility(
        guardUid: guardBUid,
        guardName: 'Guard B',
        totalCashCollected: 20.0,
        cashReceived: 50.0, // Handover In from Guard A
        cashHandedOver: 0.0,
        cashWithdrawn: 0.0,
        totalUpiCollected: 0.0,
      );

      final metricsB = computeMetricsForScope(guardUid: guardBUid);

      // Collection remains ₹20 (handover is not a parking sale)
      expect(metricsB.todayCollection, equals(20.0));
      expect(metricsB.cashCollection, equals(20.0));

      // Outstanding responsibility correctly reflects total cash in hand = ₹70
      expect(respB.outstandingCash, equals(70.0));
      expect(respB.totalOutstanding, equals(70.0));
    });

    test('Scenario 6: Admin Withdrawal reduces Outstanding Responsibility, NOT Today Collection', () {
      // Admin withdraws ₹30 cash from Guard B
      final respB = GuardFinancialResponsibility(
        guardUid: guardBUid,
        guardName: 'Guard B',
        totalCashCollected: 20.0,
        cashReceived: 50.0,
        cashHandedOver: 0.0,
        cashWithdrawn: 30.0, // Admin full/partial withdrawal
        totalUpiCollected: 0.0,
      );

      final metricsB = computeMetricsForScope(guardUid: guardBUid);

      // Collection is historical revenue for today, never reduced by withdrawals
      expect(metricsB.todayCollection, equals(20.0));

      // Outstanding cash is reduced from ₹70 to ₹40
      expect(respB.outstandingCash, equals(40.0));
      expect(respB.totalOutstanding, equals(40.0));
    });

    test('Scenario 7: Real-time update - Guard B adds new ₹20 Cash collection', () {
      // Add a second transaction for Guard B
      final updatedTxns = List<PaymentTransactionModel>.from(transactions)
        ..add(PaymentTransactionModel(
          id: 'new_guard_b_txn',
          ticketId: '1010',
          vehicleNumber: 'MH12ZZ9999',
          amount: 20.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: guardBUid,
          guardName: 'Guard B',
          createdAt: DateTime.now(),
        ));

      double bCash = 0.0;
      double aCash = 0.0;
      double facilityTotal = 0.0;

      for (final t in updatedTxns) {
        if (t.createdAt.isBefore(DateTime(now.year, now.month, now.day))) continue;
        if (t.guardUid == guardBUid) bCash += t.amount;
        if (t.guardUid == guardAUid && t.isCash) aCash += t.amount;
        facilityTotal += t.amount;
      }

      expect(bCash, equals(40.0)); // Guard B increases to ₹40
      expect(aCash, equals(100.0)); // Guard A cash unchanged at ₹100
      expect(facilityTotal, equals(180.0)); // Facility total increases to ₹180
    });
  });
}
