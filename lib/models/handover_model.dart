import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a financial responsibility handover between guards.
enum HandoverStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  String get value => name.toUpperCase();

  static HandoverStatus fromString(String val) {
    switch (val.trim().toUpperCase()) {
      case 'ACCEPTED':
        return HandoverStatus.accepted;
      case 'REJECTED':
        return HandoverStatus.rejected;
      case 'CANCELLED':
        return HandoverStatus.cancelled;
      default:
        return HandoverStatus.pending;
    }
  }
}

/// Represents an authoritative financial responsibility handover record.
class HandoverModel {
  final String handoverId;
  final String fromGuardId;
  final String fromGuardName;
  final String? fromGuardEmail;
  final String toGuardId;
  final String toGuardName;
  final String? toGuardEmail;
  final String shiftId;
  final String? toShiftId;
  final double amount;
  final String type; // 'CASH' or 'UPI'
  final String action; // 'HANDOVER'
  final DateTime createdAt;
  final String status; // 'PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED'
  final double? sourceBalanceBefore;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final DateTime? cancelledAt;
  final String? notes;

  const HandoverModel({
    required this.handoverId,
    required this.fromGuardId,
    required this.fromGuardName,
    this.fromGuardEmail,
    required this.toGuardId,
    required this.toGuardName,
    this.toGuardEmail,
    required this.shiftId,
    this.toShiftId,
    required this.amount,
    required this.type,
    this.action = 'HANDOVER',
    required this.createdAt,
    this.status = 'PENDING',
    this.sourceBalanceBefore,
    this.acceptedAt,
    this.acceptedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.cancelledAt,
    this.notes,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isCash => type.toUpperCase() == 'CASH';
  bool get isUpi => type.toUpperCase() == 'UPI';

  String get fromShiftId => shiftId;

  factory HandoverModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HandoverModel.fromMap(data, doc.id);
  }

  factory HandoverModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    return HandoverModel(
      handoverId: id,
      fromGuardId: (data['fromGuardId'] as String? ?? '').trim(),
      fromGuardName: (data['fromGuardName'] as String? ?? 'Guard').trim(),
      fromGuardEmail: data['fromGuardEmail'] as String?,
      toGuardId: (data['toGuardId'] as String? ?? '').trim(),
      toGuardName: (data['toGuardName'] as String? ?? 'Guard').trim(),
      toGuardEmail: data['toGuardEmail'] as String?,
      shiftId: (data['shiftId'] as String? ?? (data['fromShiftId'] as String? ?? '')).trim(),
      toShiftId: data['toShiftId'] as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: (data['type'] as String? ?? 'CASH').toUpperCase().trim(),
      action: (data['action'] as String? ?? 'HANDOVER').trim(),
      createdAt: parseDate(data['createdAt']),
      status: (data['status'] as String? ?? 'PENDING').toUpperCase().trim(),
      sourceBalanceBefore: (data['sourceBalanceBefore'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble(),
      acceptedAt: data['acceptedAt'] != null ? parseDate(data['acceptedAt']) : null,
      acceptedBy: data['acceptedBy'] as String?,
      rejectedAt: data['rejectedAt'] != null ? parseDate(data['rejectedAt']) : null,
      rejectedBy: data['rejectedBy'] as String?,
      cancelledAt: data['cancelledAt'] != null ? parseDate(data['cancelledAt']) : null,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'handoverId': handoverId,
      'fromGuardId': fromGuardId,
      'fromGuardName': fromGuardName,
      if (fromGuardEmail != null) 'fromGuardEmail': fromGuardEmail,
      'toGuardId': toGuardId,
      'toGuardName': toGuardName,
      if (toGuardEmail != null) 'toGuardEmail': toGuardEmail,
      'shiftId': shiftId,
      'fromShiftId': shiftId,
      if (toShiftId != null) 'toShiftId': toShiftId,
      'amount': amount,
      'type': type,
      'action': action,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      if (sourceBalanceBefore != null) 'sourceBalanceBefore': sourceBalanceBefore,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (notes != null) 'notes': notes,
    };
  }

  HandoverModel copyWith({
    String? handoverId,
    String? fromGuardId,
    String? fromGuardName,
    String? fromGuardEmail,
    String? toGuardId,
    String? toGuardName,
    String? toGuardEmail,
    String? shiftId,
    String? toShiftId,
    double? amount,
    String? type,
    String? action,
    DateTime? createdAt,
    String? status,
    double? sourceBalanceBefore,
    DateTime? acceptedAt,
    String? acceptedBy,
    DateTime? rejectedAt,
    String? rejectedBy,
    DateTime? cancelledAt,
    String? notes,
  }) {
    return HandoverModel(
      handoverId: handoverId ?? this.handoverId,
      fromGuardId: fromGuardId ?? this.fromGuardId,
      fromGuardName: fromGuardName ?? this.fromGuardName,
      fromGuardEmail: fromGuardEmail ?? this.fromGuardEmail,
      toGuardId: toGuardId ?? this.toGuardId,
      toGuardName: toGuardName ?? this.toGuardName,
      toGuardEmail: toGuardEmail ?? this.toGuardEmail,
      shiftId: shiftId ?? this.shiftId,
      toShiftId: toShiftId ?? this.toShiftId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sourceBalanceBefore: sourceBalanceBefore ?? this.sourceBalanceBefore,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      notes: notes ?? this.notes,
    );
  }
}
