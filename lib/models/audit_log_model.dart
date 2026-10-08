import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an audited administrative action.
class AuditLogModel {
  final String id;
  final String adminUid;
  final String adminName;
  final String action;
  final String targetEntity;
  final String targetId;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.adminUid,
    required this.adminName,
    required this.action,
    required this.targetEntity,
    required this.targetId,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime ts = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    return AuditLogModel(
      id: doc.id,
      adminUid: data['adminUid'] as String? ?? '',
      adminName: data['adminName'] as String? ?? 'Admin',
      action: data['action'] as String? ?? '',
      targetEntity: data['targetEntity'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      details: (data['details'] as Map<String, dynamic>?) ?? {},
      timestamp: ts,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminUid': adminUid,
      'adminName': adminName,
      'action': action,
      'targetEntity': targetEntity,
      'targetId': targetId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
