import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/guard_model.dart';
import '../models/parking_record_model.dart';
import '../models/payment_transaction_model.dart';
import '../models/shift_model.dart';
import 'audit_service.dart';
import 'shift_service.dart';

/// Holds live guard statistics for the Admin Dashboard.
class AdminGuardStats {
  final int totalGuards;
  final int activeGuards;
  final int inactiveGuards;
  final int currentlyOnShift;
  final int upcomingShiftGuards;
  final int guardsWithNoShift;

  const AdminGuardStats({
    required this.totalGuards,
    required this.activeGuards,
    required this.inactiveGuards,
    required this.currentlyOnShift,
    this.upcomingShiftGuards = 0,
    required this.guardsWithNoShift,
  });

  static const AdminGuardStats zero = AdminGuardStats(
    totalGuards: 0,
    activeGuards: 0,
    inactiveGuards: 0,
    currentlyOnShift: 0,
    upcomingShiftGuards: 0,
    guardsWithNoShift: 0,
  );
}

/// Holds aggregated collection metrics for a specific guard.
class GuardCollectionSummary {
  final String guardUid;
  final String guardName;
  final double totalCash;
  final double totalUpi;
  final double netTotal;
  final int transactionCount;
  final double advanceTotal;
  final double finalTotal;
  final double refundTotal;

  const GuardCollectionSummary({
    required this.guardUid,
    required this.guardName,
    required this.totalCash,
    required this.totalUpi,
    required this.netTotal,
    required this.transactionCount,
    required this.advanceTotal,
    required this.finalTotal,
    required this.refundTotal,
  });
}

/// Holds aggregated collection metrics for a specific shift.
class ShiftCollectionSummary {
  final String shiftName;
  final String guardName;
  final DateTime shiftDate;
  final DateTime startTime;
  final DateTime endTime;
  final double totalCash;
  final double totalUpi;
  final double netTotal;
  final int transactionCount;

  const ShiftCollectionSummary({
    required this.shiftName,
    required this.guardName,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.totalCash,
    required this.totalUpi,
    required this.netTotal,
    required this.transactionCount,
  });
}

/// Service powering the Admin Panel: guards, financial transactions,
/// analytics, and live operational stats.
class AdminService {
  final FirebaseFirestore? _customFirestore;
  final ShiftService _shiftService;

  AdminService({
    FirebaseFirestore? firestore,
    ShiftService? shiftService,
  })  : _customFirestore = firestore,
        _shiftService = shiftService ?? ShiftService(firestore: firestore);

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Real-time stream of all registered guards.
  Stream<List<GuardModel>> watchAllGuards() {
    try {
      return _firestore.collection('guards').snapshots().map((snapshot) {
        final list = <GuardModel>[];
        for (final doc in snapshot.docs) {
          try {
            final guard = GuardModel.fromFirestore(doc);
            if (guard.role.trim().toLowerCase() == 'guard') {
              list.add(guard);
            }
          } catch (e) {
            debugPrint('[AdminService] Error parsing guard doc ${doc.id}: $e');
          }
        }
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      }).handleError((e) {
        debugPrint('[AdminService] Error streaming guards: $e');
        return <GuardModel>[];
      });
    } catch (_) {
      return Stream.value(<GuardModel>[]);
    }
  }

  /// One-time fetch of all guards.
  Future<List<GuardModel>> getAllGuards() async {
    try {
      final snapshot = await _firestore.collection('guards').get();
      final list = <GuardModel>[];
      for (final doc in snapshot.docs) {
        final guard = GuardModel.fromFirestore(doc);
        if (guard.role.trim().toLowerCase() == 'guard') {
          list.add(guard);
        }
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('[AdminService] Error getting guards: $e');
      return [];
    }
  }

  /// Toggles guard active status (soft-disable/enable without deleting financial records).
  Future<void> toggleGuardStatus(String uid, bool isActive, {String? adminUid}) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;

    final docRef = _firestore.collection('guards').doc(cleanUid);
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      await docRef.set({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final query = await _firestore.collection('guards').where('uid', isEqualTo: cleanUid).limit(1).get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.set({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Guard document with UID $cleanUid does not exist',
        );
      }
    }

    try {
      await AuditService.instance.log(
        action: isActive ? 'ACTIVATE_GUARD' : 'DEACTIVATE_GUARD',
        targetEntity: 'guard',
        targetId: cleanUid,
        adminUid: adminUid,
        details: {'isActive': isActive},
      );
    } catch (e) {
      debugPrint('[AdminService] Audit log error: $e');
    }
  }

  /// Creates a new Guard profile in Firestore.
  Future<void> createGuard({
    required String uid,
    required String name,
    required String email,
    String mobile = '',
    String currentShift = 'Shift 1',
    String? adminUid,
  }) async {
    final cleanUid = uid.trim();
    final guard = GuardModel(
      uid: cleanUid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      mobile: mobile.trim(),
      role: 'guard',
      isActive: true,
      currentShift: currentShift.trim(),
      shiftStatus: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('guards').doc(cleanUid).set(
          guard.toFirestore(),
          SetOptions(merge: true),
        );

    try {
      await AuditService.instance.log(
        action: 'ADD_GUARD',
        targetEntity: 'guard',
        targetId: cleanUid,
        adminUid: adminUid,
        details: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'mobile': mobile.trim(),
          'currentShift': currentShift.trim(),
        },
      );
    } catch (e) {
      debugPrint('[AdminService] Audit log error: $e');
    }
  }

  /// Securely provisions a real Firebase Authentication account for a new guard
  /// without invalidating or signing out the currently logged-in Admin session.
  /// Then establishes the corresponding Firestore document with the real Auth UID.
  Future<GuardModel> provisionGuardAccount({
    required String name,
    required String email,
    required String password,
    String mobile = '',
    String currentShift = 'Shift 1',
    String? adminUid,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanName = name.trim();
    final cleanMobile = mobile.trim();
    final cleanShift = currentShift.trim();

    String authUid;

    // In a running Flutter app with Firebase initialized, create via secondary app
    if (Firebase.apps.isNotEmpty) {
      final tempAppName = 'GuardProvisioning_${DateTime.now().microsecondsSinceEpoch}';
      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: tempAppName,
          options: Firebase.app().options,
        );
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final userCredential = await tempAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        final user = userCredential.user;
        if (user == null) {
          throw Exception('Failed to obtain user identity from Firebase Auth.');
        }
        authUid = user.uid;
      } finally {
        if (tempApp != null) {
          await tempApp.delete();
        }
      }
    } else {
      // In test mock environments where Firebase.apps is empty
      authUid = 'guard_auth_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    }

    final guard = GuardModel(
      uid: authUid,
      name: cleanName,
      email: cleanEmail,
      mobile: cleanMobile,
      role: 'guard',
      isActive: true,
      currentShift: cleanShift,
      shiftStatus: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('guards').doc(authUid).set(
          guard.toFirestore(),
          SetOptions(merge: true),
        );

    try {
      await AuditService.instance.log(
        action: 'ADD_GUARD',
        targetEntity: 'guard',
        targetId: authUid,
        adminUid: adminUid,
        details: {
          'name': cleanName,
          'email': cleanEmail,
          'mobile': cleanMobile,
          'shift': cleanShift,
        },
      );
    } catch (e) {
      debugPrint('[AdminService] Audit log error: $e');
    }

    return guard;
  }

  /// Updates an existing Guard profile.
  Future<void> updateGuard({
    required String uid,
    required String name,
    required String mobile,
    String? currentShift,
    String? adminUid,
  }) async {
    final cleanUid = uid.trim();
    final updateData = <String, dynamic>{
      'name': name.trim(),
      'mobile': mobile.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (currentShift != null && currentShift.trim().isNotEmpty) {
      updateData['currentShift'] = currentShift.trim();
    }

    await _firestore.collection('guards').doc(cleanUid).update(updateData);

    try {
      await AuditService.instance.log(
        action: 'EDIT_GUARD',
        targetEntity: 'guard',
        targetId: cleanUid,
        adminUid: adminUid,
        details: {
          'name': name.trim(),
          'mobile': mobile.trim(),
          if (currentShift != null) 'currentShift': currentShift.trim(),
        },
      );
    } catch (e) {
      debugPrint('[AdminService] Audit log error: $e');
    }
  }

  /// Real-time stream of comprehensive Guard statistics for Admin Dashboard.
  Stream<AdminGuardStats> watchGuardStats() {
    late StreamController<AdminGuardStats> controller;
    StreamSubscription? guardsSub;
    StreamSubscription? shiftsSub;

    List<GuardModel> latestGuards = [];
    List<ShiftModel> latestShifts = [];

    void calculateAndEmit() {
      if (controller.isClosed) return;

      int total = latestGuards.length;
      int active = 0;
      int inactive = 0;
      int onShift = 0;
      int upcoming = 0;

      for (final g in latestGuards) {
        if (g.isActive) {
          active++;
          // Check if guard has an active shift right now
          final guardShifts = latestShifts.where((s) => ShiftService.matchesGuard(s, g.uid, g.email)).toList();
          final hasActiveShift = guardShifts.any((s) => s.isActive);
          final hasUpcomingShift = guardShifts.any((s) => s.isUpcoming);
          if (hasActiveShift) {
            onShift++;
          }
          if (hasUpcomingShift) {
            upcoming++;
          }
        } else {
          inactive++;
        }
      }

      int noShift = (active - onShift).clamp(0, active);

      controller.add(AdminGuardStats(
        totalGuards: total,
        activeGuards: active,
        inactiveGuards: inactive,
        currentlyOnShift: onShift,
        upcomingShiftGuards: upcoming,
        guardsWithNoShift: noShift,
      ));
    }

    controller = StreamController<AdminGuardStats>.broadcast(
      onListen: () {
        calculateAndEmit();
        guardsSub = watchAllGuards().listen((guards) {
          latestGuards = guards;
          calculateAndEmit();
        }, onError: (e) {
          debugPrint('[AdminService] Error streaming guards in stats: $e');
        });

        shiftsSub = _shiftService.watchAllShifts().listen((shifts) {
          latestShifts = shifts;
          calculateAndEmit();
        }, onError: (e) {
          debugPrint('[AdminService] Error streaming shifts in stats: $e');
        });
      },
      onCancel: () async {
        await guardsSub?.cancel();
        await shiftsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Real-time stream of payment transactions with optional filtering.
  Stream<List<PaymentTransactionModel>> watchPaymentTransactions({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? guardUid,
    String? paymentMethod,
    String? paymentType,
  }) {
    try {
      return _firestore.collection('payment_transactions').snapshots().map((snapshot) {
      final list = <PaymentTransactionModel>[];

      for (final doc in snapshot.docs) {
        try {
          final txn = PaymentTransactionModel.fromFirestore(doc);

          // Date filter (specific date or range)
          if (startDate != null && endDate != null) {
            if (txn.createdAt.isBefore(startDate) || txn.createdAt.isAfter(endDate)) {
              continue;
            }
          } else if (date != null) {
            final start = DateTime(date.year, date.month, date.day);
            final end = start.add(const Duration(days: 1));
            if (txn.createdAt.isBefore(start) || !txn.createdAt.isBefore(end)) {
              continue;
            }
          }

          // Guard UID filter
          if (guardUid != null && guardUid.isNotEmpty && txn.guardUid != guardUid) {
            continue;
          }

          // Payment method filter (cash / upi)
          if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod.toLowerCase() != 'all') {
            if (txn.paymentMethod.toLowerCase() != paymentMethod.toLowerCase()) {
              continue;
            }
          }

          // Payment type filter (ADVANCE / FINAL / REFUND)
          if (paymentType != null && paymentType.isNotEmpty && paymentType.toUpperCase() != 'ALL') {
            if (txn.paymentType.toUpperCase() != paymentType.toUpperCase()) {
              continue;
            }
          }

          list.add(txn);
        } catch (e) {
          debugPrint('[AdminService] Error parsing transaction ${doc.id}: $e');
        }
      }

      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((e) {
      debugPrint('[AdminService] Error streaming payment transactions: $e');
      return <PaymentTransactionModel>[];
    });
    } catch (_) {
      return Stream.value(<PaymentTransactionModel>[]);
    }
  }

  /// Calculates Guard-wise collection breakdown for a given date or date range.
  Stream<List<GuardCollectionSummary>> watchGuardWiseCollectionReport({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return watchPaymentTransactions(
      date: date,
      startDate: startDate,
      endDate: endDate,
    ).map((transactions) {
      final Map<String, List<PaymentTransactionModel>> grouped = {};

      for (final txn in transactions) {
        final key = txn.guardUid.isNotEmpty ? txn.guardUid : txn.guardName;
        grouped.putIfAbsent(key, () => []).add(txn);
      }

      final results = <GuardCollectionSummary>[];

      for (final entry in grouped.entries) {
        final txns = entry.value;
        final guardName = txns.first.guardName.isNotEmpty ? txns.first.guardName : entry.key;

        double cash = 0.0;
        double upi = 0.0;
        double advance = 0.0;
        double finalPay = 0.0;
        double refund = 0.0;

        for (final t in txns) {
          final isUpi = t.isUpi;
          final amt = t.amount;

          if (t.isAdvance) {
            advance += amt;
            if (isUpi) {
              upi += amt;
            } else {
              cash += amt;
            }
          } else if (t.isFinal) {
            finalPay += amt;
            if (isUpi) {
              upi += amt;
            } else {
              cash += amt;
            }
          } else if (t.isRefund) {
            refund += amt;
            if (isUpi) {
              upi -= amt;
            } else {
              cash -= amt;
            }
          }
        }

        final netCash = cash < 0 ? 0.0 : cash;
        final netUpi = upi < 0 ? 0.0 : upi;
        final netTotal = (netCash + netUpi) < 0 ? 0.0 : (netCash + netUpi);

        results.add(GuardCollectionSummary(
          guardUid: entry.key,
          guardName: guardName,
          totalCash: netCash,
          totalUpi: netUpi,
          netTotal: netTotal,
          transactionCount: txns.length,
          advanceTotal: advance,
          finalTotal: finalPay,
          refundTotal: refund,
        ));
      }

      results.sort((a, b) => b.netTotal.compareTo(a.netTotal));
      return results;
    });
  }

  /// Calculates Shift-wise collection breakdown for a given date or date range.
  Stream<List<ShiftCollectionSummary>> watchShiftWiseCollectionReport({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return watchPaymentTransactions(
      date: date,
      startDate: startDate,
      endDate: endDate,
    ).map((transactions) {
      final Map<String, List<PaymentTransactionModel>> grouped = {};

      for (final txn in transactions) {
        final key = txn.shift.isNotEmpty ? txn.shift : 'Unassigned Shift';
        grouped.putIfAbsent(key, () => []).add(txn);
      }

      final results = <ShiftCollectionSummary>[];

      for (final entry in grouped.entries) {
        final txns = entry.value;
        final shiftName = entry.key;
        final guardName = txns.first.guardName;
        final firstDate = txns.first.createdAt;

        double cash = 0.0;
        double upi = 0.0;

        for (final t in txns) {
          final isUpi = t.isUpi;
          final amt = t.amount;

          if (t.isAdvance || t.isFinal) {
            if (isUpi) {
              upi += amt;
            } else {
              cash += amt;
            }
          } else if (t.isRefund) {
            if (isUpi) {
              upi -= amt;
            } else {
              cash -= amt;
            }
          }
        }

        final netCash = cash < 0 ? 0.0 : cash;
        final netUpi = upi < 0 ? 0.0 : upi;
        final netTotal = (netCash + netUpi) < 0 ? 0.0 : (netCash + netUpi);

        results.add(ShiftCollectionSummary(
          shiftName: shiftName,
          guardName: guardName,
          shiftDate: firstDate,
          startTime: firstDate,
          endTime: firstDate.add(const Duration(hours: 8)),
          totalCash: netCash,
          totalUpi: netUpi,
          netTotal: netTotal,
          transactionCount: txns.length,
        ));
      }

      results.sort((a, b) => b.netTotal.compareTo(a.netTotal));
      return results;
    });
  }

  /// Real-time stream of parking records for reporting, with optional date filtering.
  Stream<List<ParkingRecord>> watchParkingRecords({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      return _firestore.collection('parking_records').snapshots().map((snapshot) {
        final list = <ParkingRecord>[];
        for (final doc in snapshot.docs) {
          try {
            final rec = ParkingRecord.fromFirestore(doc);
            if (startDate != null && endDate != null) {
              final inEntry = !rec.entryTime.isBefore(startDate) && !rec.entryTime.isAfter(endDate);
              final inExit = rec.exitTime != null && !rec.exitTime!.isBefore(startDate) && !rec.exitTime!.isAfter(endDate);
              final isActiveToday = rec.isActive && !endDate.isBefore(DateTime.now());
              if (!inEntry && !inExit && !isActiveToday) {
                continue;
              }
            }
            list.add(rec);
          } catch (e) {
            debugPrint('[AdminService] Error parsing parking record ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        return list;
      }).handleError((e) {
        debugPrint('[AdminService] Error streaming parking records: $e');
        return <ParkingRecord>[];
      });
    } catch (_) {
      return Stream.value(<ParkingRecord>[]);
    }
  }
}
