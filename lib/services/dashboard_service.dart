import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/parking_record_model.dart';
import '../models/vehicle_type.dart';

/// Holds real capacity numbers for both vehicle categories.
class CapacityData {
  final int carTotal;
  final int carOccupied;
  final int twoWheelerTotal;
  final int twoWheelerOccupied;

  const CapacityData({
    required this.carTotal,
    required this.carOccupied,
    required this.twoWheelerTotal,
    required this.twoWheelerOccupied,
  });

  int get carAvailable => (carTotal - carOccupied).clamp(0, carTotal);
  int get twoWheelerAvailable => (twoWheelerTotal - twoWheelerOccupied).clamp(0, twoWheelerTotal);

  bool isBlocked(VehicleType type) {
    switch (type) {
      case VehicleType.fourWheeler:
        return carAvailable <= 0;
      case VehicleType.twoWheeler:
        return twoWheelerAvailable <= 0;
    }
  }
}

/// Holds today's operational counts and collection metrics.
class DashboardMetrics {
  final int todayEntries;
  final int todayExits;
  final double todayCollection;
  final double cashCollection;
  final double upiCollection;

  const DashboardMetrics({
    required this.todayEntries,
    required this.todayExits,
    required this.todayCollection,
    required this.cashCollection,
    required this.upiCollection,
  });

  double get todayCash => cashCollection;
  double get todayUpi => upiCollection;

  static const DashboardMetrics zero = DashboardMetrics(
    todayEntries: 0,
    todayExits: 0,
    todayCollection: 0.0,
    cashCollection: 0.0,
    upiCollection: 0.0,
  );
}

/// DashboardService streams real Firestore parking data for capacity,
/// operational statistics, and recent activity.
class DashboardService {
  final FirebaseFirestore? _injectedFirestore;

  DashboardService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

  /// Real-time stream of parking capacity calculated from active Firestore records and dynamic settings.
  Stream<CapacityData> watchCapacity() {
    late StreamController<CapacityData> controller;
    StreamSubscription? recordsSub;
    StreamSubscription? settingsSub;

    int carOccupied = 0;
    int bikeOccupied = 0;
    int carCapacity = AppConstants.getCarTotalCapacity();
    int bikeCapacity = AppConstants.getTwoWheelerTotalCapacity();

    void emit() {
      if (!controller.isClosed) {
        controller.add(CapacityData(
          carTotal: carCapacity,
          carOccupied: carOccupied,
          twoWheelerTotal: bikeCapacity,
          twoWheelerOccupied: bikeOccupied,
        ));
      }
    }

    controller = StreamController<CapacityData>.broadcast(
      onListen: () {
        carCapacity = AppConstants.getCarTotalCapacity();
        bikeCapacity = AppConstants.getTwoWheelerTotalCapacity();
        emit();

        try {
          recordsSub = _firestore
              .collection('parking_records')
              .where('status', isEqualTo: 'ACTIVE')
              .snapshots()
              .listen((snapshot) {
            int cOcc = 0;
            int bOcc = 0;
            for (final doc in snapshot.docs) {
              final type = doc.data()['vehicleType'] as String? ?? 'fourWheeler';
              if (type == 'twoWheeler') {
                bOcc++;
              } else {
                cOcc++;
              }
            }
            carOccupied = cOcc;
            bikeOccupied = bOcc;
            emit();
          }, onError: (e) {
            debugPrint('[DashboardService] Error listening to active parking: $e');
          });
        } catch (_) {}

        try {
          settingsSub = _firestore
              .collection('settings')
              .doc('system_config')
              .snapshots()
              .listen((doc) {
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              carCapacity = (data['carTotalCapacity'] as num?)?.toInt() ?? AppConstants.defaultCarTotalCapacity;
              bikeCapacity = (data['twoWheelerTotalCapacity'] as num?)?.toInt() ?? AppConstants.defaultTwoWheelerTotalCapacity;
              emit();
            }
          }, onError: (e) {
            debugPrint('[DashboardService] Error listening to settings: $e');
          });
        } catch (_) {}
      },
      onCancel: () async {
        await recordsSub?.cancel();
        await settingsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Real-time stream of today's operational metrics (entries, exits, collections).
  /// - Authoritative financial collection is computed from [payment_transactions]
  ///   where createdAt >= todayStartTimestamp:
  ///     * ADVANCE = add amount
  ///     * FINAL = add amount
  ///     * REFUND = subtract amount
  ///     * Cash and UPI breakdowns are segregated by transaction paymentMethod.
  /// - Today's entries are counted from [parking_records] where entryTime >= todayStartTimestamp.
  /// - Today's exits are counted from [parking_records] where exitTime >= todayStartTimestamp,
  ///   correctly accounting for both same-day and multi-day parking stays.
  Stream<DashboardMetrics> watchTodayMetrics() {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStartTimestamp = Timestamp.fromDate(todayStart);

      late StreamController<DashboardMetrics> controller;
      StreamSubscription? entriesSub;
      StreamSubscription? exitsSub;
      StreamSubscription? txnsSub;

      int entries = 0;
      int exits = 0;
      double rawCash = 0.0;
      double rawUpi = 0.0;

      void notify() {
        if (!controller.isClosed) {
          final netTotal = (rawCash + rawUpi) < 0 ? 0.0 : (rawCash + rawUpi);
          final netCash = rawCash < 0 ? 0.0 : rawCash;
          final netUpi = rawUpi < 0 ? 0.0 : rawUpi;

          controller.add(DashboardMetrics(
            todayEntries: entries,
            todayExits: exits,
            todayCollection: netTotal,
            cashCollection: netCash,
            upiCollection: netUpi,
          ));
        }
      }

      controller = StreamController<DashboardMetrics>.broadcast(
        onListen: () {
          // Immediate baseline emission so UI displays zero/cached immediately
          notify();

          // 1. Live stream of today's entries
          try {
            entriesSub = _firestore
                .collection('parking_records')
                .where('entryTime', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                entries = snapshot.docs.length;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to today entries: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to today entries: $e');
          }

          // 2. Live stream of today's exits (works for same-day AND multi-day parking stays)
          try {
            exitsSub = _firestore
                .collection('parking_records')
                .where('exitTime', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                exits = snapshot.docs.length;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to today exits: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to today exits: $e');
          }

          // 3. Live stream of today's authoritative payment transactions
          try {
            txnsSub = _firestore
                .collection('payment_transactions')
                .where('createdAt', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                double c = 0.0;
                double u = 0.0;

                for (final doc in snapshot.docs) {
                  final data = doc.data();
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final paymentType = (data['paymentType'] as String? ?? '').toUpperCase();
                  final paymentMethod = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
                  final isUpi = paymentMethod == 'upi';

                  if (paymentType == 'ADVANCE' || paymentType == 'FINAL') {
                    if (isUpi) {
                      u += amount;
                    } else {
                      c += amount;
                    }
                  } else if (paymentType == 'REFUND') {
                    if (isUpi) {
                      u -= amount;
                    } else {
                      c -= amount;
                    }
                  }
                }

                rawCash = c;
                rawUpi = u;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to payment transactions: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to payment transactions: $e');
          }
        },
        onCancel: () async {
          await entriesSub?.cancel();
          await exitsSub?.cancel();
          await txnsSub?.cancel();
        },
      );

      return controller.stream;
    } catch (_) {
      return Stream.value(DashboardMetrics.zero);
    }
  }

  /// Real-time stream of today's operational metrics scoped to a specific guard.
  /// - Only parking payment transactions matching [guardUid] (or [guardName]) are included in collection metrics.
  /// - Authoritative financial collection is computed from [payment_transactions]
  ///   where createdAt >= todayStartTimestamp:
  ///     * ADVANCE = add amount
  ///     * FINAL = add amount
  ///     * REFUND = subtract amount
  ///     * Cash and UPI breakdowns are segregated by transaction paymentMethod.
  Stream<DashboardMetrics> watchGuardTodayMetrics(String guardUid, {String? guardName}) {
    try {
      final cleanUid = guardUid.trim();
      final cleanName = (guardName ?? '').trim().toLowerCase();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStartTimestamp = Timestamp.fromDate(todayStart);

      late StreamController<DashboardMetrics> controller;
      StreamSubscription? entriesSub;
      StreamSubscription? exitsSub;
      StreamSubscription? txnsSub;

      int entries = 0;
      int exits = 0;
      double rawCash = 0.0;
      double rawUpi = 0.0;

      void notify() {
        if (!controller.isClosed) {
          final netTotal = (rawCash + rawUpi) < 0 ? 0.0 : (rawCash + rawUpi);
          final netCash = rawCash < 0 ? 0.0 : rawCash;
          final netUpi = rawUpi < 0 ? 0.0 : rawUpi;

          controller.add(DashboardMetrics(
            todayEntries: entries,
            todayExits: exits,
            todayCollection: netTotal,
            cashCollection: netCash,
            upiCollection: netUpi,
          ));
        }
      }

      controller = StreamController<DashboardMetrics>.broadcast(
        onListen: () {
          // Immediate baseline emission so UI displays zero/cached immediately
          notify();

          // 1. Live stream of today's entries
          try {
            entriesSub = _firestore
                .collection('parking_records')
                .where('entryTime', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                entries = snapshot.docs.length;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to today entries: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to today entries: $e');
          }

          // 2. Live stream of today's exits
          try {
            exitsSub = _firestore
                .collection('parking_records')
                .where('exitTime', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                exits = snapshot.docs.length;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to today exits: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to today exits: $e');
          }

          // 3. Live stream of today's payment transactions filtered strictly by guardUid / guardName
          try {
            txnsSub = _firestore
                .collection('payment_transactions')
                .where('createdAt', isGreaterThanOrEqualTo: todayStartTimestamp)
                .snapshots()
                .listen(
              (snapshot) {
                double c = 0.0;
                double u = 0.0;

                for (final doc in snapshot.docs) {
                  final data = doc.data();
                  final docGuardUid = (data['guardUid'] as String? ?? data['collectorGuardUid'] as String? ?? '').trim();
                  final docGuardName = (data['guardName'] as String? ?? '').trim().toLowerCase();

                  if (cleanUid.isNotEmpty) {
                    if (docGuardUid.isNotEmpty) {
                      if (docGuardUid != cleanUid) continue;
                    } else if (cleanName.isNotEmpty && docGuardName == cleanName) {
                      // Fallback name match when UID is missing
                    } else {
                      continue;
                    }
                  } else if (cleanName.isNotEmpty) {
                    if (docGuardName != cleanName) continue;
                  }

                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final paymentType = (data['paymentType'] as String? ?? '').toUpperCase();
                  final paymentMethod = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
                  final isUpi = paymentMethod == 'upi';

                  if (paymentType == 'ADVANCE' || paymentType == 'FINAL') {
                    if (isUpi) {
                      u += amount;
                    } else {
                      c += amount;
                    }
                  } else if (paymentType == 'REFUND') {
                    if (isUpi) {
                      u -= amount;
                    } else {
                      c -= amount;
                    }
                  }
                }

                rawCash = c;
                rawUpi = u;
                notify();
              },
              onError: (e) {
                debugPrint('[DashboardService] Error listening to guard payment transactions: $e');
              },
            );
          } catch (e) {
            debugPrint('[DashboardService] Failed to subscribe to guard payment transactions: $e');
          }
        },
        onCancel: () async {
          await entriesSub?.cancel();
          await exitsSub?.cancel();
          await txnsSub?.cancel();
        },
      );

      return controller.stream;
    } catch (_) {
      return Stream.value(DashboardMetrics.zero);
    }
  }

  /// Real-time stream of recent parking activity (latest 5 records).
  Stream<List<ParkingRecord>> watchRecentActivity({int limit = 5}) {
    try {
      return _firestore
          .collection('parking_records')
          .snapshots()
          .map((snapshot) {
        final records = snapshot.docs.map((doc) => ParkingRecord.fromFirestore(doc)).toList();
        records.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        return records.take(limit).toList();
      }).handleError((_) {
        return <ParkingRecord>[];
      });
    } catch (_) {
      return Stream.value(<ParkingRecord>[]);
    }
  }
}
