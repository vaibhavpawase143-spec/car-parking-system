import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an authoritative record of an Admin withdrawal/settlement of a guard's outstanding money.
class WithdrawalModel {
  final String withdrawalId;
  final String guardId;
  final String guardName;
  final String shiftId;
  final String type; // 'CASH' or 'UPI'
  final double amount;
  final String adminUid;
  final String adminName;
  final DateTime createdAt;
  final String status; // 'COMPLETED'
  final String? notes;
  final double? previousOutstanding;
  final double? remainingOutstanding;

  const WithdrawalModel({
    required this.withdrawalId,
    required this.guardId,
    required this.guardName,
    required this.shiftId,
    required this.type,
    required this.amount,
    required this.adminUid,
    required this.adminName,
    required this.createdAt,
    this.status = 'COMPLETED',
    this.notes,
    this.previousOutstanding,
    this.remainingOutstanding,
  });

  bool get isCash => type.toUpperCase() == 'CASH';
  bool get isUpi => type.toUpperCase() == 'UPI';

  factory WithdrawalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WithdrawalModel.fromMap(data, doc.id);
  }

  factory WithdrawalModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    return WithdrawalModel(
      withdrawalId: id,
      guardId: (data['guardId'] as String? ?? '').trim(),
      guardName: (data['guardName'] as String? ?? 'Guard').trim(),
      shiftId: (data['shiftId'] as String? ?? '').trim(),
      type: (data['type'] as String? ?? 'CASH').toUpperCase().trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      adminUid: (data['adminUid'] as String? ?? '').trim(),
      adminName: (data['adminName'] as String? ?? 'Admin').trim(),
      createdAt: parseDate(data['createdAt']),
      status: (data['status'] as String? ?? 'COMPLETED').toUpperCase().trim(),
      notes: data['notes'] as String?,
      previousOutstanding: (data['previousOutstanding'] as num?)?.toDouble(),
      remainingOutstanding: (data['remainingOutstanding'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'withdrawalId': withdrawalId,
      'guardId': guardId,
      'guardName': guardName,
      'shiftId': shiftId,
      'type': type,
      'amount': amount,
      'adminUid': adminUid,
      'adminName': adminName,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      if (notes != null) 'notes': notes,
      if (previousOutstanding != null) 'previousOutstanding': previousOutstanding,
      if (remainingOutstanding != null) 'remainingOutstanding': remainingOutstanding,
    };
  }
}
