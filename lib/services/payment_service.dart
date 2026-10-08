import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/payment_transaction_model.dart';

/// Holds structured aggregation data for the Payment Management report.
class PaymentReportData {
  final double todayTotalCollection;
  final double expectedCash;
  final double collectedCash;
  final int cashTransactionsCount;
  final double expectedUpi;
  final double collectedUpi;
  final int upiTransactionsCount;
  final List<PaymentTransactionModel> transactions;

  const PaymentReportData({
    required this.todayTotalCollection,
    required this.expectedCash,
    required this.collectedCash,
    required this.cashTransactionsCount,
    required this.expectedUpi,
    required this.collectedUpi,
    required this.upiTransactionsCount,
    required this.transactions,
  });

  static const PaymentReportData zero = PaymentReportData(
    todayTotalCollection: 0.0,
    expectedCash: 0.0,
    collectedCash: 0.0,
    cashTransactionsCount: 0,
    expectedUpi: 0.0,
    collectedUpi: 0.0,
    upiTransactionsCount: 0,
    transactions: [],
  );
}

/// Service that streams authoritative payment transactions and calculates
/// Cash, UPI, and Total collections identically to the Guard Dashboard.
class PaymentService {
  final FirebaseFirestore? _customFirestore;

  PaymentService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of today's payment transactions and calculated report.
  Stream<PaymentReportData> watchTodayPaymentReport({String? guardUid}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return watchPaymentReport(guardUid: guardUid, startDate: todayStart);
  }

  /// Real-time stream of payment transactions and calculated report for any date range/period.
  Stream<PaymentReportData> watchPaymentReport({
    String? guardUid,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final db = _firestore;
    if (db == null) {
      return Stream.value(PaymentReportData.zero);
    }
    Query<Map<String, dynamic>> query = db.collection('payment_transactions');
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots().map((snapshot) {
      double cashExpected = 0.0;
      double cashNet = 0.0;
      int cashCount = 0;

      double upiExpected = 0.0;
      double upiNet = 0.0;
      int upiCount = 0;

      final List<PaymentTransactionModel> list = [];

      for (final doc in snapshot.docs) {
        try {
          final txn = PaymentTransactionModel.fromFirestore(doc);

          // Optional guard identity filtering if specified
          if (guardUid != null && guardUid.trim().isNotEmpty) {
            if (txn.guardUid.isNotEmpty && txn.guardUid != guardUid.trim()) {
              // Different guard
              continue;
            }
          }

          list.add(txn);

          final isUpi = txn.isUpi;
          final isRefund = txn.isRefund;
          final isAdvanceOrFinal = txn.isAdvance || txn.isFinal;

          if (isUpi) {
            upiCount++;
            if (isAdvanceOrFinal) {
              upiExpected += txn.amount;
              upiNet += txn.amount;
            } else if (isRefund) {
              upiNet -= txn.amount;
            }
          } else {
            // Cash
            cashCount++;
            if (isAdvanceOrFinal) {
              cashExpected += txn.amount;
              cashNet += txn.amount;
            } else if (isRefund) {
              cashNet -= txn.amount;
            }
          }
        } catch (e) {
          debugPrint('[PaymentService] Error parsing transaction ${doc.id}: $e');
        }
      }

      // Sort newest transactions first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final finalCash = cashNet < 0 ? 0.0 : cashNet;
      final finalUpi = upiNet < 0 ? 0.0 : upiNet;
      final total = (finalCash + finalUpi) < 0 ? 0.0 : (finalCash + finalUpi);

      return PaymentReportData(
        todayTotalCollection: total,
        expectedCash: cashExpected,
        collectedCash: finalCash,
        cashTransactionsCount: cashCount,
        expectedUpi: upiExpected,
        collectedUpi: finalUpi,
        upiTransactionsCount: upiCount,
        transactions: list,
      );
    });
  }
}
