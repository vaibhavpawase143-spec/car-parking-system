import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a permanent auditable financial responsibility event
/// (Keep With Me retention, Handover transfer, or Admin withdrawal).
class ResponsibilityEventModel {
  final String id;
  final String guardId;
  final String guardName;
  final String? guardEmail;
  final String shiftId;
  final String type; // 'CASH' or 'UPI'
  final String action; // 'KEEP_WITH_ME', 'HANDOVER_OUT', 'HANDOVER_IN', 'WITHDRAWAL', 'HANDOVER_REJECTED', 'HANDOVER_CANCELLED'
  final String status; // 'Carried Forward', 'Transferred', 'Settled', 'Pending', etc.
  final double amount;
  final DateTime createdAt;
  final String? targetGuardId;
  final String? targetGuardName;
  final String? adminUid;
  final String? adminName;
  final String? notes;

  const ResponsibilityEventModel({
    required this.id,
    required this.guardId,
    required this.guardName,
    this.guardEmail,
    required this.shiftId,
    required this.type,
    required this.action,
    this.status = 'Carried Forward',
    required this.amount,
    required this.createdAt,
    this.targetGuardId,
    this.targetGuardName,
    this.adminUid,
    this.adminName,
    this.notes,
  });

  bool get isCash => type.toUpperCase() == 'CASH';
  bool get isUpi => type.toUpperCase() == 'UPI';
  bool get isKeepWithMe => action.toUpperCase() == 'KEEP_WITH_ME';
  bool get isHandoverOut => action.toUpperCase() == 'HANDOVER_OUT';
  bool get isHandoverIn => action.toUpperCase() == 'HANDOVER_IN';
  bool get isHandoverRejected => action.toUpperCase() == 'HANDOVER_REJECTED';
  bool get isHandoverCancelled => action.toUpperCase() == 'HANDOVER_CANCELLED';
  bool get isWithdrawal => action.toUpperCase() == 'WITHDRAWAL';

  String get paymentType => type;
  DateTime get timestamp => createdAt;

  factory ResponsibilityEventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ResponsibilityEventModel.fromMap(data, doc.id);
  }

  factory ResponsibilityEventModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    final act = (data['action'] as String? ?? 'KEEP_WITH_ME').toUpperCase().trim();
    String defaultStatus = 'Carried Forward';
    if (act == 'HANDOVER_OUT' || act == 'HANDOVER_IN') defaultStatus = 'Transferred';
    if (act == 'WITHDRAWAL') defaultStatus = 'Settled';
    if (act == 'HANDOVER_REJECTED') defaultStatus = 'Rejected';
    if (act == 'HANDOVER_CANCELLED') defaultStatus = 'Cancelled';

    return ResponsibilityEventModel(
      id: id,
      guardId: (data['guardId'] as String? ?? '').trim(),
      guardName: (data['guardName'] as String? ?? 'Guard').trim(),
      guardEmail: data['guardEmail'] as String?,
      shiftId: (data['shiftId'] as String? ?? '').trim(),
      type: (data['type'] as String? ?? 'CASH').toUpperCase().trim(),
      action: act,
      status: (data['status'] as String? ?? defaultStatus).trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(data['createdAt']),
      targetGuardId: data['targetGuardId'] as String?,
      targetGuardName: data['targetGuardName'] as String?,
      adminUid: data['adminUid'] as String?,
      adminName: data['adminName'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'guardId': guardId,
      'guardName': guardName,
      if (guardEmail != null) 'guardEmail': guardEmail,
      'shiftId': shiftId,
      'type': type,
      'action': action,
      'status': status,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      if (targetGuardId != null) 'targetGuardId': targetGuardId,
      if (targetGuardName != null) 'targetGuardName': targetGuardName,
      if (adminUid != null) 'adminUid': adminUid,
      if (adminName != null) 'adminName': adminName,
      if (notes != null) 'notes': notes,
    };
  }
}
