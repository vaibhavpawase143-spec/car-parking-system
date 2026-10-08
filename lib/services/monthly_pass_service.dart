import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_pass_model.dart';
import '../models/parking_record_model.dart';
import '../models/vehicle_type.dart';

class MonthlyPassOverlapException implements Exception {
  final String message;
  const MonthlyPassOverlapException([this.message = 'This vehicle already has a Monthly Pass for this period.']);

  @override
  String toString() => message;
}

class VehiclePassCheckResult {
  final MonthlyPassModel? validPass;
  final MonthlyPassModel? upcomingPass;
  final MonthlyPassModel? expiredPass;

  const VehiclePassCheckResult({
    this.validPass,
    this.upcomingPass,
    this.expiredPass,
  });

  bool get hasValidPass => validPass != null;
  bool get isUpcoming => upcomingPass != null && validPass == null;
  bool get isExpired => expiredPass != null && validPass == null && upcomingPass == null;

  /// Checks if the valid pass matches a specific vehicle type
  bool isValidForType(VehicleType type) {
    return hasValidPass && validPass!.vehicleType == type;
  }
}

class MonthlyPassDashboardStats {
  final int activePasses;
  final int expiringSoonPasses;
  final int expiredPasses;
  final double passCollection;

  const MonthlyPassDashboardStats({
    required this.activePasses,
    required this.expiringSoonPasses,
    required this.expiredPasses,
    required this.passCollection,
  });

  static const zero = MonthlyPassDashboardStats(
    activePasses: 0,
    expiringSoonPasses: 0,
    expiredPasses: 0,
    passCollection: 0.0,
  );
}

/// Service managing Monthly Passes in 'monthly_passes' collection.
/// Monthly Pass price is strictly ₹600 FIXED paid in advance.
class MonthlyPassService {
  final FirebaseFirestore? _injectedFirestore;

  MonthlyPassService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  static final MonthlyPassService instance = MonthlyPassService();

  FirebaseFirestore? get _firestore {
    try {
      return _injectedFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Generates the next unique pass number: PASS-YYYY-XXXX
  Future<String> generateNextPassNumber() async {
    final now = DateTime.now();
    final year = now.year;
    final db = _firestore;
    if (db == null) {
      final millis = now.millisecondsSinceEpoch.toString();
      final suffix = millis.substring(millis.length - 4);
      return 'PASS-$year-$suffix';
    }
    final counterRef = db.collection('counters').doc('monthly_pass_$year');

    try {
      return await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentSeq = 0;
        if (snapshot.exists && snapshot.data() != null) {
          currentSeq = (snapshot.data()!['currentNumber'] as num?)?.toInt() ?? 0;
        }
        final nextSeq = currentSeq + 1;
        transaction.set(counterRef, {
          'year': year,
          'currentNumber': nextSeq,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final padded = nextSeq.toString().padLeft(3, '0');
        return 'PASS-$year-$padded';
      });
    } catch (e) {
      debugPrint('[MonthlyPassService] Error generating counter, using timestamp fallback: $e');
      final millis = now.millisecondsSinceEpoch.toString();
      final suffix = millis.substring(millis.length - 4);
      return 'PASS-$year-$suffix';
    }
  }

  /// Creates a Monthly Pass and records the full ₹600 payment atomically.
  /// Prevents overlapping passes for the same vehicle.
  Future<MonthlyPassModel> createMonthlyPass({
    required String vehicleNumber,
    required VehicleType vehicleType,
    required String customerName,
    required String customerMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentMethod,
    required String adminUid,
    required String adminName,
  }) async {
    final normalized = AppFormatters.normalizeVehicleNumber(vehicleNumber);
    if (normalized.isEmpty) {
      throw ArgumentError('Vehicle number cannot be empty.');
    }

    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    if (endDay.isBefore(startDay)) {
      throw ArgumentError('End date cannot be before start date.');
    }

    final db = _firestore;
    if (db == null) {
      throw Exception('Firestore is not initialized.');
    }

    // 1. Overlap Check for the same vehicle
    final existingSnapshot = await db
        .collection('monthly_passes')
        .where('normalizedVehicleNumber', isEqualTo: normalized)
        .get();

    for (final doc in existingSnapshot.docs) {
      final existing = MonthlyPassModel.fromFirestore(doc);
      if (existing.status.toUpperCase() == 'CANCELLED') continue;

      final exStart = DateTime(existing.startDate.year, existing.startDate.month, existing.startDate.day);
      final exEnd = DateTime(existing.endDate.year, existing.endDate.month, existing.endDate.day, 23, 59, 59, 999);

      // Overlap condition: not completely before and not completely after
      final isDisjoint = endDay.isBefore(exStart) || startDay.isAfter(exEnd);
      if (!isDisjoint) {
        throw const MonthlyPassOverlapException('This vehicle already has a Monthly Pass for this period.');
      }
    }

    // 2. Generate Pass Number and Document ID
    final passNumber = await generateNextPassNumber();
    final passDocRef = db.collection('monthly_passes').doc();
    final txnDocRef = db.collection('payment_transactions').doc();

    final now = DateTime.now();
    final initialStatus = now.isBefore(startDay) ? 'UPCOMING' : 'ACTIVE';

    final pass = MonthlyPassModel(
      id: passDocRef.id,
      passNumber: passNumber,
      vehicleNumber: vehicleNumber.trim().toUpperCase(),
      normalizedVehicleNumber: normalized,
      vehicleType: vehicleType,
      customerName: customerName.trim(),
      customerMobile: customerMobile.trim(),
      startDate: startDay,
      endDate: endDay,
      amount: MonthlyPassModel.fixedPrice,
      amountPaid: MonthlyPassModel.fixedPrice,
      outstandingAmount: 0.0,
      paymentStatus: 'PAID',
      paymentMethod: paymentMethod.toLowerCase(),
      status: initialStatus,
      createdAt: now,
      createdBy: adminName.isNotEmpty ? adminName : 'Admin',
    );

    // 3. Atomic Batch Commit: Pass Document + Payment Transaction Ledger
    final batch = db.batch();

    final passMap = pass.toFirestore();
    passMap['createdAt'] = FieldValue.serverTimestamp();
    passMap['updatedAt'] = FieldValue.serverTimestamp();
    batch.set(passDocRef, passMap);

    // Payment transaction: Authoritative ledger record
    batch.set(txnDocRef, {
      'ticketId': passNumber,
      'vehicleNumber': normalized,
      'amount': MonthlyPassModel.fixedPrice,
      'paymentMethod': paymentMethod.toLowerCase(),
      'paymentType': 'MONTHLY_PASS',
      'guardUid': adminUid,
      'guardName': adminName.isNotEmpty ? adminName : 'Admin',
      'shift': 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return pass;
  }

  /// Checks if a vehicle has an active, upcoming, or expired pass
  Future<VehiclePassCheckResult> checkVehiclePass(String vehicleNumber, [DateTime? atTime]) async {
    final normalized = AppFormatters.normalizeVehicleNumber(vehicleNumber);
    if (normalized.isEmpty) {
      return const VehiclePassCheckResult();
    }

    final db = _firestore;
    if (db == null) {
      return const VehiclePassCheckResult();
    }

    try {
      final snapshot = await db
          .collection('monthly_passes')
          .where('normalizedVehicleNumber', isEqualTo: normalized)
          .get();

      final check = atTime ?? DateTime.now();

      MonthlyPassModel? active;
      MonthlyPassModel? upcoming;
      MonthlyPassModel? latestExpired;

      for (final doc in snapshot.docs) {
        final pass = MonthlyPassModel.fromFirestore(doc);
        if (pass.status.toUpperCase() == 'CANCELLED') continue;

        if (pass.isValidAt(check)) {
          active = pass;
          break; // Active valid pass takes immediate precedence
        } else if (check.isBefore(pass.startDate)) {
          if (upcoming == null || pass.startDate.isBefore(upcoming.startDate)) {
            upcoming = pass;
          }
        } else if (check.isAfter(pass.endDate)) {
          if (latestExpired == null || pass.endDate.isAfter(latestExpired.endDate)) {
            latestExpired = pass;
          }
        }
      }

      return VehiclePassCheckResult(
        validPass: active,
        upcomingPass: upcoming,
        expiredPass: latestExpired,
      );
    } catch (e) {
      debugPrint('[MonthlyPassService] checkVehiclePass error: $e');
      return const VehiclePassCheckResult();
    }
  }

  /// Live Stream of all Monthly Passes
  Stream<List<MonthlyPassModel>> watchAllPasses() {
    final db = _firestore;
    if (db == null) {
      return Stream.value(<MonthlyPassModel>[]);
    }
    return db.collection('monthly_passes').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => MonthlyPassModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Live Stream of Monthly Pass dashboard statistics
  Stream<MonthlyPassDashboardStats> watchDashboardStats() {
    final db = _firestore;
    if (db == null) {
      return Stream.value(MonthlyPassDashboardStats.zero);
    }
    try {
      return db.collection('monthly_passes').snapshots().map((snapshot) {
        int active = 0;
        int expiringSoon = 0;
        int expired = 0;
        double collection = 0.0;

        for (final doc in snapshot.docs) {
          final pass = MonthlyPassModel.fromFirestore(doc);
          if (pass.status.toUpperCase() == 'CANCELLED') continue;

          final dyn = pass.dynamicStatus;
          if (dyn == 'ACTIVE') {
            active++;
            if (pass.isExpiringSoon) {
              expiringSoon++;
            }
          } else if (dyn == 'EXPIRED') {
            expired++;
          }

          if (pass.paymentStatus == 'PAID') {
            collection += pass.amountPaid;
          }
        }

        return MonthlyPassDashboardStats(
          activePasses: active,
          expiringSoonPasses: expiringSoon,
          expiredPasses: expired,
          passCollection: collection,
        );
      }).handleError((_) => MonthlyPassDashboardStats.zero);
    } catch (_) {
      return Stream.value(MonthlyPassDashboardStats.zero);
    }
  }

  /// Realtime Stream of parking visits for a specific pass vehicle
  /// Reads directly from the authoritative [parking_records] collection.
  Stream<List<ParkingRecord>> watchPassParkingHistory(String vehicleNumber, {String? passId}) {
    final normalized = AppFormatters.normalizeVehicleNumber(vehicleNumber);
    if (normalized.isEmpty) {
      return Stream.value(<ParkingRecord>[]);
    }

    final db = _firestore;
    if (db == null) {
      return Stream.value(<ParkingRecord>[]);
    }

    try {
      return db
          .collection('parking_records')
          .where('vehicleNumber', isEqualTo: normalized)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => ParkingRecord.fromFirestore(doc))
            .where((r) => r.isMonthlyPass || (passId != null && r.monthlyPassId == passId))
            .toList();
        list.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        return list;
      }).handleError((e) {
        debugPrint('[MonthlyPassService] watchPassParkingHistory error: $e');
        return <ParkingRecord>[];
      });
    } catch (e) {
      debugPrint('[MonthlyPassService] watchPassParkingHistory setup error: $e');
      return Stream.value(<ParkingRecord>[]);
    }
  }
}
