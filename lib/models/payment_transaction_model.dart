import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an authoritative financial transaction from the 'payment_transactions' collection.
class PaymentTransactionModel {
  final String id;
  final String ticketId;
  final String vehicleNumber;
  final double amount;
  final String paymentMethod; // 'cash' or 'upi'
  final String paymentType; // 'ADVANCE', 'FINAL', 'REFUND'
  final String guardUid;
  final String guardName;
  final String shift;
  final DateTime createdAt;

  const PaymentTransactionModel({
    required this.id,
    required this.ticketId,
    required this.vehicleNumber,
    required this.amount,
    required this.paymentMethod,
    required this.paymentType,
    required this.guardUid,
    this.guardName = '',
    this.shift = '',
    required this.createdAt,
  });

  bool get isCash => paymentMethod.trim().toLowerCase() == 'cash';
  bool get isUpi => paymentMethod.trim().toLowerCase() == 'upi';
  bool get isAdvance => paymentType.trim().toUpperCase() == 'ADVANCE';
  bool get isFinal => paymentType.trim().toUpperCase() == 'FINAL';
  bool get isRefund => paymentType.trim().toUpperCase() == 'REFUND';
  bool get isMonthlyPass => paymentType.trim().toUpperCase() == 'MONTHLY_PASS';

  String get transactionId => id;
  DateTime get timestamp => createdAt;

  factory PaymentTransactionModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedDate;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate().toLocal();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else if (rawDate is num) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt()).toLocal();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return PaymentTransactionModel(
      id: id,
      ticketId: (data['ticketId'] as String? ?? '').trim(),
      vehicleNumber: (data['vehicleNumber'] as String? ?? '').trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (data['paymentMethod'] as String? ?? 'cash').trim().toLowerCase(),
      paymentType: (data['paymentType'] as String? ?? 'ADVANCE').trim().toUpperCase(),
      guardUid: (data['guardUid'] as String? ?? '').trim(),
      guardName: (data['guardName'] as String? ?? 'Guard').trim(),
      shift: (data['shift'] as String? ?? '').trim(),
      createdAt: parsedDate,
    );
  }

  factory PaymentTransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PaymentTransactionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketId': ticketId,
      'vehicleNumber': vehicleNumber,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentType': paymentType,
      'guardUid': guardUid,
      'guardName': guardName,
      'shift': shift,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
