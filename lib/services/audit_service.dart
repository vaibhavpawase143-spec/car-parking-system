import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/audit_log_model.dart';

/// Service responsible for recording and querying immutable administrative audit logs.
class AuditService {
  static final AuditService instance = AuditService();

  final FirebaseFirestore? _customFirestore;

  AuditService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Convenience logger method.
  Future<void> log({
    required String action,
    required String targetEntity,
    required String targetId,
    String? adminUid,
    String? adminName,
    Map<String, dynamic> details = const {},
  }) async {
    await logAction(
      adminUid: adminUid ?? 'admin',
      adminName: adminName ?? 'System Admin',
      action: action,
      targetEntity: targetEntity,
      targetId: targetId,
      details: details,
    );
  }

  /// Records an audit log event in the `audit_logs` Firestore collection.
  Future<void> logAction({
    required String adminUid,
    required String adminName,
    required String action,
    required String targetEntity,
    required String targetId,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      final docRef = _firestore.collection('audit_logs').doc();
      final log = AuditLogModel(
        id: docRef.id,
        adminUid: adminUid,
        adminName: adminName,
        action: action,
        targetEntity: targetEntity,
        targetId: targetId,
        details: details,
        timestamp: DateTime.now(),
      );
      await docRef.set(log.toFirestore());
      debugPrint('[AuditService] Logged action: $action on $targetEntity ($targetId) by $adminName');
    } catch (e) {
      debugPrint('[AuditService] Warning: Failed to record audit log: $e');
    }
  }

  /// Real-time stream of audit logs ordered by timestamp descending.
  Stream<List<AuditLogModel>> watchRecentLogs({int limit = 50}) {
    try {
      return _firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => AuditLogModel.fromFirestore(doc)).toList();
      }).handleError((e) {
        debugPrint('[AuditService] Error streaming audit logs: $e');
        return <AuditLogModel>[];
      });
    } catch (_) {
      return Stream.value(<AuditLogModel>[]);
    }
  }
}
