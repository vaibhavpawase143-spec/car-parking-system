import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/localization/app_strings.dart';
import '../core/utils/formatters.dart';
import '../models/guard_model.dart';
import '../models/handover_model.dart';
import '../models/responsibility_event_model.dart';
import '../models/withdrawal_model.dart';
import 'audit_service.dart';
import 'notification_service.dart';

/// Combines GuardModel with real-time financial responsibility and latest activity.
class GuardFinancialRecord {
  final GuardModel guard;
  final GuardFinancialResponsibility responsibility;
  final DateTime? lastActivity;

  const GuardFinancialRecord({
    required this.guard,
    required this.responsibility,
    this.lastActivity,
  });
}

/// Aggregated real-time financial responsibility metrics for a guard.
class GuardFinancialResponsibility {
  final String guardUid;
  final String guardName;

  final double totalCashCollected;
  final double cashHandedOver;
  final double cashReceived;
  final double cashWithdrawn;

  final double totalUpiCollected;
  final double upiHandedOver;
  final double upiReceived;
  final double upiWithdrawn;

  const GuardFinancialResponsibility({
    required this.guardUid,
    required this.guardName,
    this.totalCashCollected = 0.0,
    this.cashHandedOver = 0.0,
    this.cashReceived = 0.0,
    this.cashWithdrawn = 0.0,
    this.totalUpiCollected = 0.0,
    this.upiHandedOver = 0.0,
    this.upiReceived = 0.0,
    this.upiWithdrawn = 0.0,
  });

  /// Cash currently with this guard:
  /// Collections - Accepted Outgoing Handovers + Accepted Incoming Handovers - Admin Withdrawals
  double get outstandingCash {
    final net = totalCashCollected - cashHandedOver + cashReceived - cashWithdrawn;
    return net < 0 ? 0.0 : net;
  }

  /// UPI currently with this guard:
  /// Collections - Accepted Outgoing Handovers + Accepted Incoming Handovers - Admin Withdrawals
  double get outstandingUpi {
    final net = totalUpiCollected - upiHandedOver + upiReceived - upiWithdrawn;
    return net < 0 ? 0.0 : net;
  }

  double get totalOutstanding => outstandingCash + outstandingUpi;

  GuardFinancialResponsibility copyWith({
    String? guardUid,
    String? guardName,
    double? totalCashCollected,
    double? cashHandedOver,
    double? cashReceived,
    double? cashWithdrawn,
    double? totalUpiCollected,
    double? upiHandedOver,
    double? upiReceived,
    double? upiWithdrawn,
  }) {
    return GuardFinancialResponsibility(
      guardUid: guardUid ?? this.guardUid,
      guardName: guardName ?? this.guardName,
      totalCashCollected: totalCashCollected ?? this.totalCashCollected,
      cashHandedOver: cashHandedOver ?? this.cashHandedOver,
      cashReceived: cashReceived ?? this.cashReceived,
      cashWithdrawn: cashWithdrawn ?? this.cashWithdrawn,
      totalUpiCollected: totalUpiCollected ?? this.totalUpiCollected,
      upiHandedOver: upiHandedOver ?? this.upiHandedOver,
      upiReceived: upiReceived ?? this.upiReceived,
      upiWithdrawn: upiWithdrawn ?? this.upiWithdrawn,
    );
  }

  static const GuardFinancialResponsibility zero = GuardFinancialResponsibility(
    guardUid: '',
    guardName: '',
  );
}

/// Central service managing independent Cash and UPI financial responsibilities,
/// full-amount handovers between guards, Keep-With-Me retention, and Admin full withdrawals.
class FinancialResponsibilityService {
  static final FinancialResponsibilityService instance = FinancialResponsibilityService._internal();

  final FirebaseFirestore? _injectedFirestore;

  FinancialResponsibilityService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FinancialResponsibilityService._internal() : _injectedFirestore = null;

  FirebaseFirestore? get _firestore {
    try {
      return _injectedFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final NotificationService _notificationService = NotificationService();
  final AuditService _auditService = AuditService.instance;

  /// Streams the live financial responsibility of a specific guard.
  Stream<GuardFinancialResponsibility> watchGuardResponsibility(String guardUid, [String guardName = 'Guard']) {
    final cleanUid = guardUid.trim();
    final db = _firestore;
    if (cleanUid.isEmpty || db == null) {
      return Stream.value(GuardFinancialResponsibility.zero);
    }

    late StreamController<GuardFinancialResponsibility> controller;
    StreamSubscription? subTxns;
    StreamSubscription? subOutHandovers;
    StreamSubscription? subInHandovers;
    StreamSubscription? subWithdrawals;

    double cashColl = 0.0;
    double upiColl = 0.0;
    double cashOut = 0.0;
    double upiOut = 0.0;
    double cashIn = 0.0;
    double upiIn = 0.0;
    double cashWithdrawn = 0.0;
    double upiWithdrawn = 0.0;

    void notify() {
      if (!controller.isClosed) {
        controller.add(GuardFinancialResponsibility(
          guardUid: cleanUid,
          guardName: guardName,
          totalCashCollected: cashColl < 0 ? 0.0 : cashColl,
          cashHandedOver: cashOut,
          cashReceived: cashIn,
          cashWithdrawn: cashWithdrawn,
          totalUpiCollected: upiColl < 0 ? 0.0 : upiColl,
          upiHandedOver: upiOut,
          upiReceived: upiIn,
          upiWithdrawn: upiWithdrawn,
        ));
      }
    }

    controller = StreamController<GuardFinancialResponsibility>.broadcast(
      onListen: () {
        notify();

        try {
          subTxns = db
              .collection('payment_transactions')
              .where('guardUid', isEqualTo: cleanUid)
              .snapshots()
              .listen((snapshot) {
            double c = 0.0;
            double u = 0.0;
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final method = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
              final pType = (data['paymentType'] as String? ?? 'ADVANCE').toUpperCase();

              if (method == 'cash') {
                if (pType == 'REFUND') {
                  c -= amt;
                } else {
                  c += amt;
                }
              } else if (method == 'upi') {
                if (pType == 'REFUND') {
                  u -= amt;
                } else {
                  u += amt;
                }
              }
            }
            cashColl = c;
            upiColl = u;
            notify();
          }, onError: (e) => debugPrint('[watchGuardResponsibility] txns error: $e'));

          subOutHandovers = db
              .collection('handovers')
              .where('fromGuardId', isEqualTo: cleanUid)
              .where('status', isEqualTo: 'ACCEPTED')
              .snapshots()
              .listen((snapshot) {
            double c = 0.0;
            double u = 0.0;
            for (final doc in snapshot.docs) {
              final d = doc.data();
              final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (d['type'] as String? ?? 'CASH').toUpperCase();
              if (type == 'CASH') c += amt;
              if (type == 'UPI') u += amt;
            }
            cashOut = c;
            upiOut = u;
            notify();
          }, onError: (e) => debugPrint('[watchGuardResponsibility] outHandovers error: $e'));

          subInHandovers = db
              .collection('handovers')
              .where('toGuardId', isEqualTo: cleanUid)
              .where('status', isEqualTo: 'ACCEPTED')
              .snapshots()
              .listen((snapshot) {
            double c = 0.0;
            double u = 0.0;
            for (final doc in snapshot.docs) {
              final d = doc.data();
              final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (d['type'] as String? ?? 'CASH').toUpperCase();
              if (type == 'CASH') c += amt;
              if (type == 'UPI') u += amt;
            }
            cashIn = c;
            upiIn = u;
            notify();
          }, onError: (e) => debugPrint('[watchGuardResponsibility] inHandovers error: $e'));

          subWithdrawals = db
              .collection('withdrawals')
              .where('guardId', isEqualTo: cleanUid)
              .snapshots()
              .listen((snapshot) {
            double c = 0.0;
            double u = 0.0;
            for (final doc in snapshot.docs) {
              final d = doc.data();
              final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (d['type'] as String? ?? 'CASH').toUpperCase();
              if (type == 'CASH') c += amt;
              if (type == 'UPI') u += amt;
            }
            cashWithdrawn = c;
            upiWithdrawn = u;
            notify();
          }, onError: (e) => debugPrint('[watchGuardResponsibility] withdrawals error: $e'));
        } catch (e) {
          debugPrint('[watchGuardResponsibility] setup error: $e');
        }
      },
      onCancel: () async {
        await subTxns?.cancel();
        await subOutHandovers?.cancel();
        await subInHandovers?.cancel();
        await subWithdrawals?.cancel();
      },
    );

    return controller.stream;
  }

  /// Calculates the financial responsibility and last activity timestamp for a guard.
  Future<({GuardFinancialResponsibility resp, DateTime? lastActivity})> calculateGuardResponsibility(
    String guardUid, [String guardName = 'Guard',
  ]) async {
    final cleanUid = guardUid.trim();
    final db = _firestore;
    if (cleanUid.isEmpty || db == null) {
      return (resp: GuardFinancialResponsibility.zero, lastActivity: null);
    }

    DateTime? lastAct;
    double cashColl = 0.0;
    double upiColl = 0.0;

    final txnsFuture = db
        .collection('payment_transactions')
        .where('guardUid', isEqualTo: cleanUid)
        .get();

    final outHandoversFuture = db
        .collection('handovers')
        .where('fromGuardId', isEqualTo: cleanUid)
        .where('status', isEqualTo: 'ACCEPTED')
        .get();

    final inHandoversFuture = db
        .collection('handovers')
        .where('toGuardId', isEqualTo: cleanUid)
        .where('status', isEqualTo: 'ACCEPTED')
        .get();

    final withdrawalsFuture = db
        .collection('withdrawals')
        .where('guardId', isEqualTo: cleanUid)
        .get();

    final queryResults = await Future.wait([
      txnsFuture,
      outHandoversFuture,
      inHandoversFuture,
      withdrawalsFuture,
    ]);

    final txnsSnap = queryResults[0];
    final outHandoversSnap = queryResults[1];
    final inHandoversSnap = queryResults[2];
    final withdrawalsSnap = queryResults[3];

    for (final doc in txnsSnap.docs) {
      final data = doc.data();
      final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final method = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
      final pType = (data['paymentType'] as String? ?? 'ADVANCE').toUpperCase();
      final tStamp = (data['createdAt'] as Timestamp?)?.toDate();
      if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
        lastAct = tStamp;
      }

      if (method == 'cash') {
        if (pType == 'REFUND') {
          cashColl -= amt;
        } else {
          cashColl += amt;
        }
      } else if (method == 'upi') {
        if (pType == 'REFUND') {
          upiColl -= amt;
        } else {
          upiColl += amt;
        }
      }
    }

    double cashOut = 0.0;
    double upiOut = 0.0;
    for (final doc in outHandoversSnap.docs) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (d['type'] as String? ?? 'CASH').toUpperCase();
      final tStamp = (d['createdAt'] as Timestamp?)?.toDate();
      if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
        lastAct = tStamp;
      }
      if (type == 'CASH') cashOut += amt;
      if (type == 'UPI') upiOut += amt;
    }

    double cashIn = 0.0;
    double upiIn = 0.0;
    for (final doc in inHandoversSnap.docs) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (d['type'] as String? ?? 'CASH').toUpperCase();
      final tStamp = (d['createdAt'] as Timestamp?)?.toDate();
      if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
        lastAct = tStamp;
      }
      if (type == 'CASH') cashIn += amt;
      if (type == 'UPI') upiIn += amt;
    }

    double cashWithdrawn = 0.0;
    double upiWithdrawn = 0.0;
    for (final doc in withdrawalsSnap.docs) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (d['type'] as String? ?? 'CASH').toUpperCase();
      final tStamp = (d['createdAt'] as Timestamp?)?.toDate();
      if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
        lastAct = tStamp;
      }
      if (type == 'CASH') cashWithdrawn += amt;
      if (type == 'UPI') upiWithdrawn += amt;
    }

    final resp = GuardFinancialResponsibility(
      guardUid: cleanUid,
      guardName: guardName,
      totalCashCollected: cashColl < 0 ? 0.0 : cashColl,
      cashHandedOver: cashOut,
      cashReceived: cashIn,
      cashWithdrawn: cashWithdrawn,
      totalUpiCollected: upiColl < 0 ? 0.0 : upiColl,
      upiHandedOver: upiOut,
      upiReceived: upiIn,
      upiWithdrawn: upiWithdrawn,
    );

    return (resp: resp, lastActivity: lastAct);
  }

  /// Streams all guards combined with their real-time financial responsibility records.
  /// Optimized for real-time reactivity without cascading network round-trips.
  Stream<List<GuardFinancialRecord>> watchAllGuardsFinancialRecords() {
    final db = _firestore;
    if (db == null) return Stream.value(<GuardFinancialRecord>[]);

    late StreamController<List<GuardFinancialRecord>> controller;
    StreamSubscription? subGuards;
    StreamSubscription? subTxns;
    StreamSubscription? subHandovers;
    StreamSubscription? subWithdrawals;

    List<GuardModel> guards = [];
    List<Map<String, dynamic>> txns = [];
    List<Map<String, dynamic>> handovers = [];
    List<Map<String, dynamic>> withdrawals = [];

    void recalculate() {
      if (controller.isClosed) return;
      try {
        final records = <GuardFinancialRecord>[];
        for (final guard in guards) {
          final cleanUid = guard.uid.trim();
          double cashColl = 0.0;
          double upiColl = 0.0;
          double cashOut = 0.0;
          double upiOut = 0.0;
          double cashIn = 0.0;
          double upiIn = 0.0;
          double cashWithdrawn = 0.0;
          double upiWithdrawn = 0.0;
          DateTime? lastAct;

          // Transactions
          for (final t in txns) {
            final docUid = (t['guardUid'] as String? ?? '').trim();
            if (docUid == cleanUid || docUid.toLowerCase() == cleanUid.toLowerCase()) {
              final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
              final method = (t['paymentMethod'] as String? ?? 'cash').toLowerCase();
              final pType = (t['paymentType'] as String? ?? 'ADVANCE').toUpperCase();
              final tStamp = (t['createdAt'] as Timestamp?)?.toDate();
              if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
                lastAct = tStamp;
              }
              if (method == 'cash') {
                if (pType == 'REFUND') {
                  cashColl -= amt;
                } else {
                  cashColl += amt;
                }
              } else if (method == 'upi') {
                if (pType == 'REFUND') {
                  upiColl -= amt;
                } else {
                  upiColl += amt;
                }
              }
            }
          }

          // Handovers Out (ACCEPTED)
          for (final h in handovers) {
            final fromId = (h['fromGuardId'] as String? ?? '').trim();
            final status = (h['status'] as String? ?? '').toUpperCase();
            if ((fromId == cleanUid || fromId.toLowerCase() == cleanUid.toLowerCase()) && status == 'ACCEPTED') {
              final amt = (h['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (h['type'] as String? ?? 'CASH').toUpperCase();
              final tStamp = (h['createdAt'] as Timestamp?)?.toDate();
              if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
                lastAct = tStamp;
              }
              if (type == 'CASH') cashOut += amt;
              if (type == 'UPI') upiOut += amt;
            }
          }

          // Handovers In (ACCEPTED)
          for (final h in handovers) {
            final toId = (h['toGuardId'] as String? ?? '').trim();
            final status = (h['status'] as String? ?? '').toUpperCase();
            if ((toId == cleanUid || toId.toLowerCase() == cleanUid.toLowerCase()) && status == 'ACCEPTED') {
              final amt = (h['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (h['type'] as String? ?? 'CASH').toUpperCase();
              final tStamp = (h['createdAt'] as Timestamp?)?.toDate();
              if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
                lastAct = tStamp;
              }
              if (type == 'CASH') cashIn += amt;
              if (type == 'UPI') upiIn += amt;
            }
          }

          // Withdrawals
          for (final w in withdrawals) {
            final gId = (w['guardId'] as String? ?? '').trim();
            if (gId == cleanUid || gId.toLowerCase() == cleanUid.toLowerCase()) {
              final amt = (w['amount'] as num?)?.toDouble() ?? 0.0;
              final type = (w['type'] as String? ?? 'CASH').toUpperCase();
              final tStamp = (w['createdAt'] as Timestamp?)?.toDate();
              if (tStamp != null && (lastAct == null || tStamp.isAfter(lastAct))) {
                lastAct = tStamp;
              }
              if (type == 'CASH') cashWithdrawn += amt;
              if (type == 'UPI') upiWithdrawn += amt;
            }
          }

          final resp = GuardFinancialResponsibility(
            guardUid: cleanUid,
            guardName: guard.name,
            totalCashCollected: cashColl < 0 ? 0.0 : cashColl,
            cashHandedOver: cashOut,
            cashReceived: cashIn,
            cashWithdrawn: cashWithdrawn,
            totalUpiCollected: upiColl < 0 ? 0.0 : upiColl,
            upiHandedOver: upiOut,
            upiReceived: upiIn,
            upiWithdrawn: upiWithdrawn,
          );

          records.add(GuardFinancialRecord(
            guard: guard,
            responsibility: resp,
            lastActivity: lastAct,
          ));
        }

        if (!controller.isClosed) {
          controller.add(records);
        }
      } catch (e) {
        debugPrint('[FinancialResponsibilityService] Recalculate error: $e');
      }
    }

    controller = StreamController<List<GuardFinancialRecord>>.broadcast(
      onListen: () {
        subGuards = db.collection('guards').snapshots().listen((snap) {
          guards = snap.docs
              .map((d) => GuardModel.fromFirestore(d))
              .where((g) => g.role.trim().toLowerCase() == 'guard')
              .toList();
          recalculate();
        }, onError: (e) => debugPrint('[Guards sub error]: $e'));

        subTxns = db.collection('payment_transactions').snapshots().listen((snap) {
          txns = snap.docs.map((d) => d.data()).toList();
          recalculate();
        }, onError: (e) => debugPrint('[Txns sub error]: $e'));

        subHandovers = db.collection('handovers').snapshots().listen((snap) {
          handovers = snap.docs.map((d) => d.data()).toList();
          recalculate();
        }, onError: (e) => debugPrint('[Handovers sub error]: $e'));

        subWithdrawals = db.collection('withdrawals').snapshots().listen((snap) {
          withdrawals = snap.docs.map((d) => d.data()).toList();
          recalculate();
        }, onError: (e) => debugPrint('[Withdrawals sub error]: $e'));
      },
      onCancel: () async {
        await subGuards?.cancel();
        await subTxns?.cancel();
        await subHandovers?.cancel();
        await subWithdrawals?.cancel();
      },
    );

    return controller.stream;
  }

  /// Streams pending handovers addressed to the specified receiving guard.
  Stream<List<HandoverModel>> watchPendingHandoversForGuard(String guardUid) {
    final cleanUid = guardUid.trim();
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<HandoverModel>[]);
      return db
          .collection('handovers')
          .where('toGuardId', isEqualTo: cleanUid)
          .where('status', isEqualTo: 'PENDING')
          .snapshots()
          .map((snap) => snap.docs.map((d) => HandoverModel.fromFirestore(d)).toList())
          .handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error watching pending handovers: $e');
        return <HandoverModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchPendingHandovers: $e');
      return Stream.value(<HandoverModel>[]);
    }
  }

  /// Fetches a single authoritative handover document by ID.
  Future<HandoverModel?> getHandover(String handoverId) async {
    final db = _firestore;
    if (db == null) return null;
    try {
      final doc = await db.collection('handovers').doc(handoverId).get();
      if (!doc.exists || doc.data() == null) return null;
      return HandoverModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error fetching handover $handoverId: $e');
      return null;
    }
  }

  /// Streams all handovers for Admin monitoring, optionally filtered by type.
  /// Streams all handovers for Admin monitoring, optionally filtered by type.
  Stream<List<HandoverModel>> watchAllHandovers({String? type}) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<HandoverModel>[]);
      return db
          .collection('handovers')
          .snapshots()
          .map((snap) {
        final list = <HandoverModel>[];
        for (final d in snap.docs) {
          try {
            final h = HandoverModel.fromMap(d.data(), d.id);
            if (type == null || type == 'ALL' || h.type.toUpperCase() == type.toUpperCase()) {
              list.add(h);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing handover ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming handovers: $e');
        return <HandoverModel>[];
      }).asBroadcastStream();
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchAllHandovers: $e');
      return Stream.value(<HandoverModel>[]);
    }
  }

  /// Streams all Admin withdrawals.
  Stream<List<WithdrawalModel>> watchAllWithdrawals({String? type}) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<WithdrawalModel>[]);
      return db
          .collection('withdrawals')
          .snapshots()
          .map((snap) {
        final list = <WithdrawalModel>[];
        for (final d in snap.docs) {
          try {
            final w = WithdrawalModel.fromMap(d.data(), d.id);
            if (type == null || type == 'ALL' || w.type.toUpperCase() == type.toUpperCase()) {
              list.add(w);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing withdrawal ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming withdrawals: $e');
        return <WithdrawalModel>[];
      }).asBroadcastStream();
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchAllWithdrawals: $e');
      return Stream.value(<WithdrawalModel>[]);
    }
  }

  /// Streams Keep With Me events for a specific guard.
  Stream<List<ResponsibilityEventModel>> watchGuardKeepWithMeEvents(String guardUid) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<ResponsibilityEventModel>[]);
      final cleanUid = guardUid.trim();
      return db
          .collection('responsibility_events')
          .snapshots()
          .map((snap) {
        final list = <ResponsibilityEventModel>[];
        for (final d in snap.docs) {
          try {
            final ev = ResponsibilityEventModel.fromMap(d.data(), d.id);
            if ((ev.guardId == cleanUid || ev.guardId.toLowerCase() == cleanUid.toLowerCase()) &&
                ev.action.toUpperCase() == 'KEEP_WITH_ME') {
              list.add(ev);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing event ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming Keep With Me events: $e');
        return <ResponsibilityEventModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchGuardKeepWithMeEvents: $e');
      return Stream.value(<ResponsibilityEventModel>[]);
    }
  }

  /// Streams all Keep With Me events for Admin auditing.
  Stream<List<ResponsibilityEventModel>> watchAllKeepWithMeEvents() {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<ResponsibilityEventModel>[]);
      return db
          .collection('responsibility_events')
          .snapshots()
          .map((snap) {
        final list = <ResponsibilityEventModel>[];
        for (final d in snap.docs) {
          try {
            final ev = ResponsibilityEventModel.fromMap(d.data(), d.id);
            if (ev.action.toUpperCase() == 'KEEP_WITH_ME') {
              list.add(ev);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing event ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming all Keep With Me events: $e');
        return <ResponsibilityEventModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchAllKeepWithMeEvents: $e');
      return Stream.value(<ResponsibilityEventModel>[]);
    }
  }

  /// Initiates a full-amount Handover to the receiving guard.
  Future<HandoverModel> initiateHandover({
    required String fromGuardId,
    required String fromGuardName,
    String? fromGuardEmail,
    required String toGuardId,
    required String toGuardName,
    String? toGuardEmail,
    required String shiftId,
    String? toShiftId,
    required String type, // 'CASH' or 'UPI'
    required double amount,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Handover amount must be strictly greater than zero.');
    }
    final cleanType = type.trim().toUpperCase();
    if (cleanType != 'CASH' && cleanType != 'UPI') {
      throw ArgumentError('Invalid handover type: $type');
    }

    final db = _firestore;
    if (db == null) throw StateError('Firebase is not initialized.');

    final authUser = FirebaseAuth.instance.currentUser;
    final currentGuardUid = authUser?.uid;
    final effectiveFromGuardId = (currentGuardUid != null && currentGuardUid.isNotEmpty)
        ? currentGuardUid
        : fromGuardId.trim();

    final docRef = db.collection('handovers').doc();
    final eventDoc = db.collection('responsibility_events').doc();
    final now = DateTime.now();

    final fromGuardSnap = await calculateGuardResponsibility(effectiveFromGuardId, fromGuardName);
    final currentBalanceAtCreation = cleanType == 'CASH'
        ? fromGuardSnap.resp.outstandingCash
        : fromGuardSnap.resp.outstandingUpi;

    final handover = HandoverModel(
      handoverId: docRef.id,
      fromGuardId: effectiveFromGuardId,
      fromGuardName: fromGuardName.trim(),
      fromGuardEmail: fromGuardEmail ?? authUser?.email,
      toGuardId: toGuardId.trim(),
      toGuardName: toGuardName.trim(),
      toGuardEmail: toGuardEmail,
      shiftId: shiftId.trim(),
      toShiftId: toShiftId?.trim(),
      amount: amount,
      type: cleanType,
      action: 'HANDOVER',
      createdAt: now,
      status: 'PENDING',
      sourceBalanceBefore: currentBalanceAtCreation > 0 ? currentBalanceAtCreation : amount,
      notes: notes,
    );

    final event = ResponsibilityEventModel(
      id: eventDoc.id,
      guardId: effectiveFromGuardId,
      guardName: fromGuardName.trim(),
      guardEmail: fromGuardEmail ?? authUser?.email,
      shiftId: shiftId.trim(),
      type: cleanType,
      action: 'HANDOVER_INITIATED',
      status: 'Pending',
      amount: amount,
      createdAt: now,
      targetGuardId: toGuardId.trim(),
      targetGuardName: toGuardName.trim(),
      notes: notes,
    );

    debugPrint('''
[HANDOVER_DEBUG] INITIATE START:
currentGuardUid: $currentGuardUid
currentGuardId: $fromGuardId
currentGuardName: $fromGuardName
paymentType: $cleanType
amount: $amount
fromGuardUid: $effectiveFromGuardId
toGuardUid: ${toGuardId.trim()}
shiftId: ${shiftId.trim()}
Firestore collection: handovers & responsibility_events
Firestore document/path: handovers/${docRef.id}
exact write operation: WriteBatch.set(handovers/${docRef.id}) + WriteBatch.set(responsibility_events/${eventDoc.id})
''');

    try {
      final batch = db.batch();
      batch.set(docRef, handover.toFirestore());
      batch.set(eventDoc, event.toFirestore());
      await batch.commit();

      debugPrint('''
[HANDOVER_DEBUG] INITIATE SUCCESS:
handoverId: ${docRef.id}
status: PENDING
amount: $amount
type: $cleanType
from: $effectiveFromGuardId ($fromGuardName)
to: ${toGuardId.trim()} ($toGuardName)
''');
    } catch (e, st) {
      String? code;
      String? message;
      if (e is FirebaseException) {
        code = e.code;
        message = e.message;
      }
      debugPrint('''
[HANDOVER_DEBUG] INITIATE FAILED:
currentGuardUid: $currentGuardUid
currentGuardId: $fromGuardId
currentGuardName: $fromGuardName
paymentType: $cleanType
amount: $amount
fromGuardUid: $effectiveFromGuardId
toGuardUid: ${toGuardId.trim()}
shiftId: ${shiftId.trim()}
Firestore collection: handovers
Firestore document/path: handovers/${docRef.id}
FirebaseException code: $code
FirebaseException message: $message
exact write operation: batch.commit()
Error: $e
StackTrace: $st
''');
      rethrow;
    }

    final formattedAmt = AppFormatters.formatCurrency(amount);

    // 1. Notify Receiving Guard (Guard -> Guard)
    try {
      await _notificationService.createNotification(
        recipientUserId: toGuardId.trim(),
        title: 'Incoming $cleanType Handover',
        message: '$fromGuardName has handed over $formattedAmt $cleanType responsibility to you.',
        type: 'handover',
        relatedEntityId: docRef.id,
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Notification to receiving guard failed: $e');
    }

    // 2. Notify Admin (Guard -> Admin)
    try {
      await _notificationService.createNotification(
        recipientUserId: 'admin',
        title: '$cleanType Handover Initiated',
        message: '$fromGuardName handed over $formattedAmt $cleanType to $toGuardName.',
        type: 'handover',
        relatedEntityId: docRef.id,
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Notification to admin failed: $e');
    }

    // 3. Audit Log
    try {
      await _auditService.log(
        action: '${cleanType}_HANDOVER_INITIATED',
        targetEntity: 'handover',
        targetId: docRef.id,
        details: {
          'fromGuard': fromGuardName,
          'toGuard': toGuardName,
          'amount': amount,
          'type': cleanType,
        },
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Audit log failed: $e');
    }

    return handover;
  }

  /// Accepts or Rejects an incoming handover.
  Future<void> respondToHandover({
    required String handoverId,
    required bool accept,
    required String guardUid,
    required String guardName,
  }) async {
    final db = _firestore;
    if (db == null) throw StateError('Firebase is not initialized.');

    final authUser = FirebaseAuth.instance.currentUser;
    final currentGuardUid = authUser?.uid ?? guardUid;

    final docRef = db.collection('handovers').doc(handoverId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Handover record not found.');
    }

    final handover = HandoverModel.fromFirestore(snap);
    if (!handover.isPending) {
      if (accept && handover.status.toUpperCase() == 'ACCEPTED') {
        debugPrint('[FinancialResponsibilityService] Handover $handoverId is already ACCEPTED. Idempotent return.');
        return;
      }
      throw Exception('This handover has already been ${handover.status.toLowerCase()}.');
    }

    if (handover.toGuardId.trim() != guardUid.trim() && handover.toGuardId.trim() != currentGuardUid.trim()) {
      throw Exception('Only the designated receiving guard can accept this handover.');
    }

    final newStatus = accept ? 'ACCEPTED' : 'REJECTED';
    final now = DateTime.now();

    if (accept) {
      final fromGuardSnap = await calculateGuardResponsibility(handover.fromGuardId, handover.fromGuardName);
      final currentAvailable = handover.isCash
          ? fromGuardSnap.resp.outstandingCash
          : fromGuardSnap.resp.outstandingUpi;
      final expectedBalance = handover.sourceBalanceBefore ?? handover.amount;

      // Revalidate: If outgoing Guard responsibility changed after creation or current balance is less than handover amount
      final isStale = (currentAvailable - expectedBalance).abs() > 0.001 || currentAvailable < handover.amount;
      if (isStale) {
        final cancelBatch = db.batch();
        cancelBatch.update(docRef, {
          'status': 'CANCELLED',
          'cancelledAt': Timestamp.fromDate(now),
          'notes': 'Auto-cancelled: Guard responsibility changed prior to acceptance (captured: ₹$expectedBalance, current: ₹$currentAvailable, required: ₹${handover.amount})',
        });

        final cancelEventDoc = db.collection('responsibility_events').doc();
        cancelBatch.set(cancelEventDoc, ResponsibilityEventModel(
          id: cancelEventDoc.id,
          guardId: handover.fromGuardId,
          guardName: handover.fromGuardName,
          shiftId: handover.shiftId,
          type: handover.type,
          action: 'HANDOVER_CANCELLED',
          status: 'Cancelled',
          amount: handover.amount,
          createdAt: now,
          targetGuardId: currentGuardUid,
          targetGuardName: guardName,
          notes: 'Auto-cancelled due to stale responsibility amount change',
        ).toFirestore());

        await cancelBatch.commit();
        throw Exception(AppStrings.handoverStaleAmountError);
      }
    }

    debugPrint('''
[HANDOVER_DEBUG] RESPOND START:
currentGuardUid: $currentGuardUid
guardUid: $guardUid
guardName: $guardName
handoverId: $handoverId
action: $newStatus
fromGuardId: ${handover.fromGuardId}
toGuardId: ${handover.toGuardId}
amount: ${handover.amount}
paymentType: ${handover.type}
Firestore collection: handovers / responsibility_events
Firestore document/path: handovers/$handoverId
exact write operation: WriteBatch.update(handovers/$handoverId) + WriteBatch.set(responsibility_events)
''');

    try {
      final batch = db.batch();
      final Map<String, dynamic> updateFields = {
        'status': newStatus,
      };
      if (accept) {
        updateFields['acceptedAt'] = Timestamp.fromDate(now);
        updateFields['acceptedBy'] = currentGuardUid;
      } else {
        updateFields['rejectedAt'] = Timestamp.fromDate(now);
        updateFields['rejectedBy'] = currentGuardUid;
      }
      batch.update(docRef, updateFields);

      if (accept) {
        // Responsibility event for outgoing guard (responsibility transferred out)
        final outEventDoc = db.collection('responsibility_events').doc();
        batch.set(outEventDoc, ResponsibilityEventModel(
          id: outEventDoc.id,
          guardId: handover.fromGuardId,
          guardName: handover.fromGuardName,
          shiftId: handover.shiftId,
          type: handover.type,
          action: 'HANDOVER_OUT',
          status: 'Transferred',
          amount: handover.amount,
          createdAt: now,
          targetGuardId: currentGuardUid,
          targetGuardName: guardName,
        ).toFirestore());

        // Responsibility event for incoming guard (responsibility received in)
        final inEventDoc = db.collection('responsibility_events').doc();
        batch.set(inEventDoc, ResponsibilityEventModel(
          id: inEventDoc.id,
          guardId: currentGuardUid,
          guardName: guardName,
          shiftId: handover.shiftId,
          type: handover.type,
          action: 'HANDOVER_IN',
          status: 'Transferred',
          amount: handover.amount,
          createdAt: now,
          targetGuardId: handover.fromGuardId,
          targetGuardName: handover.fromGuardName,
        ).toFirestore());
      } else {
        final rejectEventDoc = db.collection('responsibility_events').doc();
        batch.set(rejectEventDoc, ResponsibilityEventModel(
          id: rejectEventDoc.id,
          guardId: handover.fromGuardId,
          guardName: handover.fromGuardName,
          shiftId: handover.shiftId,
          type: handover.type,
          action: 'HANDOVER_REJECTED',
          status: 'Rejected',
          amount: handover.amount,
          createdAt: now,
          targetGuardId: currentGuardUid,
          targetGuardName: guardName,
        ).toFirestore());
      }

      await batch.commit();

      debugPrint('''
[HANDOVER_DEBUG] RESPOND SUCCESS:
handoverId: $handoverId
newStatus: $newStatus
amount: ${handover.amount}
type: ${handover.type}
''');
    } catch (e, st) {
      String? code;
      String? message;
      if (e is FirebaseException) {
        code = e.code;
        message = e.message;
      }
      debugPrint('''
[HANDOVER_DEBUG] RESPOND FAILED:
currentGuardUid: $currentGuardUid
guardUid: $guardUid
handoverId: $handoverId
action: $newStatus
FirebaseException code: $code
FirebaseException message: $message
exact write operation: batch.commit()
Error: $e
StackTrace: $st
''');
      rethrow;
    }

    final formattedAmt = AppFormatters.formatCurrency(handover.amount);

    // Non-blocking notification & audit dispatch after atomic batch commit
    unawaited(Future(() async {
      // 1. Notify Outgoing Guard
      try {
        await _notificationService.createNotification(
          recipientUserId: handover.fromGuardId,
          title: '$newStatus: ${handover.type} Handover',
          message: '$guardName has ${accept ? "accepted" : "rejected"} your ${handover.type} handover of $formattedAmt.',
          type: 'handover',
          relatedEntityId: handoverId,
        );
      } catch (e) {
        debugPrint('[FinancialResponsibilityService] Notify outgoing guard error: $e');
      }

      // 2. Notify Admin
      try {
        await _notificationService.createNotification(
          recipientUserId: 'admin',
          title: '$newStatus: ${handover.type} Handover',
          message: '$guardName $newStatus the ${handover.type} handover of $formattedAmt from ${handover.fromGuardName}.',
          type: 'handover',
          relatedEntityId: handoverId,
        );
      } catch (e) {
        debugPrint('[FinancialResponsibilityService] Notify admin error: $e');
      }

      // 3. Audit Log
      try {
        await _auditService.log(
          action: accept ? '${handover.type}_HANDOVER_ACCEPTED' : '${handover.type}_HANDOVER_REJECTED',
          targetEntity: 'handover',
          targetId: handoverId,
          details: {
            'guardName': guardName,
            'amount': handover.amount,
            'status': newStatus,
          },
        );
      } catch (e) {
        debugPrint('[FinancialResponsibilityService] Audit log error: $e');
      }
    }));
  }

  /// Cancels an outgoing pending handover.
  Future<void> cancelHandover({
    required String handoverId,
    required String guardUid,
    required String guardName,
  }) async {
    final db = _firestore;
    if (db == null) throw StateError('Firebase is not initialized.');

    final authUser = FirebaseAuth.instance.currentUser;
    final currentGuardUid = authUser?.uid ?? guardUid;

    final docRef = db.collection('handovers').doc(handoverId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Handover record not found.');
    }

    final handover = HandoverModel.fromFirestore(snap);
    if (!handover.isPending) {
      throw Exception('Only pending handovers can be cancelled.');
    }

    final now = DateTime.now();

    debugPrint('''
[HANDOVER_DEBUG] CANCEL START:
currentGuardUid: $currentGuardUid
guardUid: $guardUid
handoverId: $handoverId
fromGuardId: ${handover.fromGuardId}
amount: ${handover.amount}
type: ${handover.type}
exact write operation: WriteBatch.update(handovers/$handoverId) + WriteBatch.set(responsibility_events)
''');

    try {
      final batch = db.batch();
      batch.update(docRef, {
        'status': 'CANCELLED',
        'cancelledAt': Timestamp.fromDate(now),
      });

      final cancelEventDoc = db.collection('responsibility_events').doc();
      batch.set(cancelEventDoc, ResponsibilityEventModel(
        id: cancelEventDoc.id,
        guardId: handover.fromGuardId,
        guardName: handover.fromGuardName,
        shiftId: handover.shiftId,
        type: handover.type,
        action: 'HANDOVER_CANCELLED',
        status: 'Cancelled',
        amount: handover.amount,
        createdAt: now,
        targetGuardId: handover.toGuardId,
        targetGuardName: handover.toGuardName,
      ).toFirestore());

      await batch.commit();

      debugPrint('''
[HANDOVER_DEBUG] CANCEL SUCCESS:
handoverId: $handoverId
status: CANCELLED
''');
    } catch (e, st) {
      String? code;
      String? message;
      if (e is FirebaseException) {
        code = e.code;
        message = e.message;
      }
      debugPrint('''
[HANDOVER_DEBUG] CANCEL FAILED:
currentGuardUid: $currentGuardUid
handoverId: $handoverId
FirebaseException code: $code
FirebaseException message: $message
exact write operation: batch.commit()
Error: $e
StackTrace: $st
''');
      rethrow;
    }

    final formattedAmt = AppFormatters.formatCurrency(handover.amount);

    // Notify Receiving Guard
    try {
      await _notificationService.createNotification(
        recipientUserId: handover.toGuardId,
        title: 'Handover Cancelled',
        message: '${handover.fromGuardName} cancelled the $formattedAmt ${handover.type} handover.',
        type: 'handover',
        relatedEntityId: handoverId,
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Notify cancel error: $e');
    }

    // Audit Log
    try {
      await _auditService.log(
        action: '${handover.type}_HANDOVER_CANCELLED',
        targetEntity: 'handover',
        targetId: handoverId,
        details: {
          'guardName': guardName,
          'amount': handover.amount,
        },
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Audit log error: $e');
    }
  }

  /// Records Guard "Keep With Me" retention of the full outstanding amount.
  Future<void> recordKeepWithMe({
    required String guardId,
    required String guardName,
    required String shiftId,
    required String type, // 'CASH' or 'UPI'
    required double amount,
  }) async {
    final cleanType = type.trim().toUpperCase();
    final formattedAmt = AppFormatters.formatCurrency(amount);

    final db = _firestore;
    final authUser = FirebaseAuth.instance.currentUser;
    final effectiveGuardId = authUser?.uid ?? guardId.trim();

    debugPrint('''
[KEEP_WITH_ME_DEBUG] RECORD START:
guardId: $effectiveGuardId
guardName: $guardName
shiftId: $shiftId
type: $cleanType
amount: $amount
status: Carried Forward
''');

    if (db != null) {
      final eventDoc = db.collection('responsibility_events').doc();
      final event = ResponsibilityEventModel(
        id: eventDoc.id,
        guardId: effectiveGuardId,
        guardName: guardName.trim(),
        guardEmail: authUser?.email,
        shiftId: shiftId.trim(),
        type: cleanType,
        action: 'KEEP_WITH_ME',
        status: 'Carried Forward',
        amount: amount,
        createdAt: DateTime.now(),
      );
      await eventDoc.set(event.toFirestore());
      debugPrint('[KEEP_WITH_ME_DEBUG] Stored responsibility_events/${eventDoc.id}');
    }

    // Notify Admin (Guard -> Admin)
    try {
      await _notificationService.createNotification(
        recipientUserId: 'admin',
        title: '$cleanType Kept by Guard',
        message: '$guardName kept $formattedAmt $cleanType responsibility (Carried Forward).',
        type: 'keep_with_me',
        relatedEntityId: effectiveGuardId,
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Notify admin keep with me error: $e');
    }

    // Audit Log
    try {
      await _auditService.log(
        action: '${cleanType}_KEEP_WITH_ME',
        targetEntity: 'guard',
        targetId: effectiveGuardId,
        details: {
          'guardName': guardName,
          'shiftId': shiftId,
          'type': cleanType,
          'amount': amount,
          'status': 'Carried Forward',
        },
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Audit log keep with me error: $e');
    }
  }

  /// Asynchronously fetches the latest authoritative financial responsibility of a guard.
  Future<GuardFinancialResponsibility> getGuardFinancialResponsibility(String guardUid, [String guardName = 'Guard']) async {
    final cleanUid = guardUid.trim();
    final db = _firestore;
    if (db == null) {
      return GuardFinancialResponsibility(guardUid: cleanUid, guardName: guardName);
    }

    try {
      // 1. Transactions
      final txSnap = await db
          .collection('payment_transactions')
          .where('guardUid', isEqualTo: cleanUid)
          .get();
      double cashColl = 0.0;
      double upiColl = 0.0;
      for (final doc in txSnap.docs) {
        final data = doc.data();
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final method = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
        final pType = (data['paymentType'] as String? ?? 'ADVANCE').toUpperCase();

        if (method == 'cash') {
          if (pType == 'REFUND') {
            cashColl -= amt;
          } else {
            cashColl += amt;
          }
        } else if (method == 'upi') {
          if (pType == 'REFUND') {
            upiColl -= amt;
          } else {
            upiColl += amt;
          }
        }
      }

      // 2. Outgoing handovers (accepted)
      final outSnap = await db
          .collection('handovers')
          .where('fromGuardId', isEqualTo: cleanUid)
          .get();
      double cashOut = 0.0;
      double upiOut = 0.0;
      for (final doc in outSnap.docs) {
        final data = doc.data();
        if ((data['status'] as String? ?? '').toUpperCase() == 'ACCEPTED') {
          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final type = (data['type'] as String? ?? 'CASH').toUpperCase();
          if (type == 'CASH') cashOut += amt;
          if (type == 'UPI') upiOut += amt;
        }
      }

      // 3. Incoming handovers (accepted)
      final inSnap = await db
          .collection('handovers')
          .where('toGuardId', isEqualTo: cleanUid)
          .get();
      double cashIn = 0.0;
      double upiIn = 0.0;
      for (final doc in inSnap.docs) {
        final data = doc.data();
        if ((data['status'] as String? ?? '').toUpperCase() == 'ACCEPTED') {
          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final type = (data['type'] as String? ?? 'CASH').toUpperCase();
          if (type == 'CASH') cashIn += amt;
          if (type == 'UPI') upiIn += amt;
        }
      }

      // 4. Withdrawals
      final withSnap = await db
          .collection('withdrawals')
          .where('guardId', isEqualTo: cleanUid)
          .get();
      double cashWithdrawn = 0.0;
      double upiWithdrawn = 0.0;
      for (final doc in withSnap.docs) {
        final data = doc.data();
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = (data['type'] as String? ?? 'CASH').toUpperCase();
        if (type == 'CASH') cashWithdrawn += amt;
        if (type == 'UPI') upiWithdrawn += amt;
      }

      return GuardFinancialResponsibility(
        guardUid: cleanUid,
        guardName: guardName,
        totalCashCollected: cashColl < 0 ? 0.0 : cashColl,
        cashHandedOver: cashOut,
        cashReceived: cashIn,
        cashWithdrawn: cashWithdrawn,
        totalUpiCollected: upiColl < 0 ? 0.0 : upiColl,
        upiHandedOver: upiOut,
        upiReceived: upiIn,
        upiWithdrawn: upiWithdrawn,
      );
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error fetching guard responsibility: $e');
      return GuardFinancialResponsibility(guardUid: cleanUid, guardName: guardName);
    }
  }

  /// Admin executes a specific withdrawal from a guard's current outstanding balance.
  /// Re-validates the latest authoritative outstanding balance from Firestore before committing.
  Future<WithdrawalModel> adminWithdrawSpecific({
    required String guardId,
    required String guardName,
    required String shiftId,
    required String type, // 'CASH' or 'UPI'
    required double amount,
    required String adminUid,
    required String adminName,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError(AppStrings.withdrawalMustBeGreaterThanZero);
    }
    final cleanType = type.trim().toUpperCase();

    final db = _firestore;
    if (db == null) throw StateError('Firebase is not initialized.');

    // 1. Authoritative re-read of current financial responsibility from Firestore
    final currentResp = await getGuardFinancialResponsibility(guardId, guardName);
    final double latestOutstanding = cleanType == 'CASH'
        ? currentResp.outstandingCash
        : currentResp.outstandingUpi;

    if (amount > latestOutstanding) {
      final methodStr = cleanType == 'CASH' ? 'cash' : 'UPI';
      final formattedLatest = AppFormatters.formatCurrency(latestOutstanding);
      throw StateError(AppStrings.withdrawalAmountExceeds(methodStr, formattedLatest));
    }

    final double remainingOutstanding = (latestOutstanding - amount).clamp(0.0, double.infinity);

    final docRef = db.collection('withdrawals').doc();
    final now = DateTime.now();
    final withdrawal = WithdrawalModel(
      withdrawalId: docRef.id,
      guardId: guardId.trim(),
      guardName: guardName.trim(),
      shiftId: shiftId.trim(),
      type: cleanType,
      amount: amount,
      adminUid: adminUid.trim(),
      adminName: adminName.trim(),
      createdAt: now,
      status: 'COMPLETED',
      notes: notes,
      previousOutstanding: latestOutstanding,
      remainingOutstanding: remainingOutstanding,
    );

    final batch = db.batch();
    batch.set(docRef, withdrawal.toFirestore());

    final eventDoc = db.collection('responsibility_events').doc();
    batch.set(eventDoc, ResponsibilityEventModel(
      id: eventDoc.id,
      guardId: guardId.trim(),
      guardName: guardName.trim(),
      shiftId: shiftId.trim(),
      type: cleanType,
      action: 'WITHDRAWAL',
      amount: amount,
      createdAt: now,
      adminUid: adminUid.trim(),
      adminName: adminName.trim(),
      notes: notes,
    ).toFirestore());

    await batch.commit();

    final formattedAmt = AppFormatters.formatCurrency(amount);
    final formattedRem = AppFormatters.formatCurrency(remainingOutstanding);

    // 1. Notify Guard (Admin -> Guard)
    final nowFormatted = AppFormatters.formatDateTime(now);
    await _notificationService.createNotification(
      recipientUserId: guardId,
      title: '$cleanType Withdrawal',
      message: 'Admin withdrew $formattedAmt $cleanType from your responsibility.\nRemaining $cleanType responsibility: $formattedRem\nDate: $nowFormatted',
      type: 'withdrawal',
      relatedEntityId: docRef.id,
    );

    // 2. Audit Log
    await _auditService.log(
      action: '${cleanType}_WITHDRAWAL',
      targetEntity: 'withdrawal',
      targetId: docRef.id,
      adminUid: adminUid,
      adminName: adminName,
      details: {
        'guardId': guardId,
        'guardName': guardName,
        'type': cleanType,
        'amount': amount,
        'previousOutstanding': latestOutstanding,
        'remainingOutstanding': remainingOutstanding,
      },
    );

    return withdrawal;
  }

  /// Admin executes a full withdrawal/settlement of a guard's outstanding money.
  Future<WithdrawalModel> adminWithdrawFull({
    required String guardId,
    required String guardName,
    required String shiftId,
    required String type, // 'CASH' or 'UPI'
    required double amount,
    required String adminUid,
    required String adminName,
    String? notes,
  }) {
    return adminWithdrawSpecific(
      guardId: guardId,
      guardName: guardName,
      shiftId: shiftId,
      type: type,
      amount: amount,
      adminUid: adminUid,
      adminName: adminName,
      notes: notes,
    );
  }

  /// Streams withdrawals for a specific guard (history of Admin withdrawals).
  Stream<List<WithdrawalModel>> watchGuardWithdrawals(String guardUid) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<WithdrawalModel>[]);
      final cleanUid = guardUid.trim();
      return db
          .collection('withdrawals')
          .snapshots()
          .map((snap) {
        final list = <WithdrawalModel>[];
        for (final d in snap.docs) {
          try {
            final w = WithdrawalModel.fromMap(d.data(), d.id);
            if (w.guardId == cleanUid || w.guardId.toLowerCase() == cleanUid.toLowerCase()) {
              list.add(w);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing withdrawal ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming guard withdrawals: $e');
        return <WithdrawalModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchGuardWithdrawals: $e');
      return Stream.value(<WithdrawalModel>[]);
    }
  }

  /// Streams handovers involving a specific guard (either as fromGuard or toGuard).
  Stream<List<HandoverModel>> watchGuardHandovers(String guardUid) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<HandoverModel>[]);
      final cleanUid = guardUid.trim();
      return db
          .collection('handovers')
          .snapshots()
          .map((snap) {
        final list = <HandoverModel>[];
        for (final d in snap.docs) {
          try {
            final h = HandoverModel.fromMap(d.data(), d.id);
            if (h.fromGuardId == cleanUid ||
                h.toGuardId == cleanUid ||
                h.fromGuardId.toLowerCase() == cleanUid.toLowerCase() ||
                h.toGuardId.toLowerCase() == cleanUid.toLowerCase()) {
              list.add(h);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing handover ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming guard handovers: $e');
        return <HandoverModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchGuardHandovers: $e');
      return Stream.value(<HandoverModel>[]);
    }
  }

  /// Streams responsibility history (events) for a specific guard.
  Stream<List<ResponsibilityEventModel>> watchResponsibilityHistory(String guardUid) {
    try {
      final db = _firestore;
      if (db == null) return Stream.value(<ResponsibilityEventModel>[]);
      final cleanUid = guardUid.trim();
      return db
          .collection('responsibility_events')
          .snapshots()
          .map((snap) {
        final list = <ResponsibilityEventModel>[];
        for (final d in snap.docs) {
          try {
            final ev = ResponsibilityEventModel.fromMap(d.data(), d.id);
            if (ev.guardId == cleanUid || ev.guardId.toLowerCase() == cleanUid.toLowerCase()) {
              list.add(ev);
            }
          } catch (e) {
            debugPrint('[FinancialResponsibilityService] Error parsing event ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[FinancialResponsibilityService] Error streaming responsibility history: $e');
        return <ResponsibilityEventModel>[];
      });
    } catch (e) {
      debugPrint('[FinancialResponsibilityService] Error initializing watchResponsibilityHistory: $e');
      return Stream.value(<ResponsibilityEventModel>[]);
    }
  }
}
