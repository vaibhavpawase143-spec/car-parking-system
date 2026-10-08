import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/guard_model.dart';
import '../models/shift_model.dart';
import '../models/shift_schedule_model.dart';
import 'audit_service.dart';
import 'notification_service.dart';

/// Exception thrown when a shift assignment overlaps with an existing shift for the guard.
class OverlappingShiftException implements Exception {
  final String message;
  const OverlappingShiftException([this.message = 'This guard already has an overlapping shift.']);

  @override
  String toString() => message;
}

/// Exception thrown when attempting to modify an active or completed shift.
class ShiftNotEditableException implements Exception {
  final String message;
  const ShiftNotEditableException([this.message = 'Only upcoming assigned shifts can be edited or cancelled.']);

  @override
  String toString() => message;
}

/// Service managing Admin-controlled 8-hour shifts and Guard My Shift view.
class ShiftService {
  static final ShiftService instance = ShiftService();

  final FirebaseFirestore? _customFirestore;
  final NotificationService? _customNotificationService;

  ShiftService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _customFirestore = firestore,
        _customNotificationService = notificationService;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  NotificationService get _notificationService =>
      _customNotificationService ?? NotificationService(firestore: _customFirestore);

  /// Helper to safely retrieve current Firebase Auth UID even if Firebase is uninitialized.
  static String? get safeCurrentAuthUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid.trim();
    } catch (_) {
      return null;
    }
  }

  /// Helper to safely retrieve current Firebase Auth Email even if Firebase is uninitialized.
  static String? get safeCurrentAuthEmail {
    try {
      return FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Helper to check if a shift belongs to the given guard by UID, doc ID, email, or name.
  static bool matchesGuard(
    ShiftModel shift,
    String targetUid, [
    String? targetEmail,
    String? targetName,
  ]) {
    final cleanTargetUid = targetUid.trim();
    final cleanTargetEmail = targetEmail?.trim().toLowerCase();
    final cleanTargetName = targetName?.trim().toLowerCase();
    final authUid = safeCurrentAuthUid;
    final authEmail = safeCurrentAuthEmail;

    final sGuardId = shift.guardId.trim();
    final sGuardUid = (shift.guardUid ?? '').trim();
    final sGuardEmail = (shift.guardEmail ?? '').trim().toLowerCase();
    final sGuardName = shift.guardName.trim().toLowerCase();

    // 1. Direct Target UID match (handles exact match and case-insensitive fallback)
    if (cleanTargetUid.isNotEmpty) {
      if (sGuardId == cleanTargetUid ||
          sGuardUid == cleanTargetUid ||
          sGuardId.toLowerCase() == cleanTargetUid.toLowerCase() ||
          sGuardUid.toLowerCase() == cleanTargetUid.toLowerCase()) {
        return true;
      }
    }

    // 2. Current Firebase Auth UID match
    if (authUid != null && authUid.isNotEmpty) {
      if (sGuardId == authUid ||
          sGuardUid == authUid ||
          sGuardId.toLowerCase() == authUid.toLowerCase() ||
          sGuardUid.toLowerCase() == authUid.toLowerCase()) {
        return true;
      }
    }

    // 3. Target Email match
    if (cleanTargetEmail != null && cleanTargetEmail.isNotEmpty) {
      if (sGuardId.toLowerCase() == cleanTargetEmail ||
          sGuardUid.toLowerCase() == cleanTargetEmail ||
          sGuardEmail == cleanTargetEmail) {
        return true;
      }
    }

    // 4. Current Firebase Auth Email match
    if (authEmail != null && authEmail.isNotEmpty) {
      if (sGuardId.toLowerCase() == authEmail ||
          sGuardUid.toLowerCase() == authEmail ||
          sGuardEmail == authEmail) {
        return true;
      }
    }

    // 5. Target Guard Name match (fallback for shifts assigned with Guard's display name)
    if (cleanTargetName != null && cleanTargetName.isNotEmpty && cleanTargetName != 'guard') {
      if (sGuardName == cleanTargetName ||
          sGuardId.toLowerCase() == cleanTargetName ||
          sGuardUid.toLowerCase() == cleanTargetName) {
        return true;
      }
    }

    return false;
  }

  /// Determines the single next eligible scheduled Shift across all active guards.
  /// Only the earliest valid upcoming ASSIGNED shift for an active guard without an active shift
  /// is considered the NEXT ELIGIBLE SHIFT.
  static ShiftModel? findNextEligibleShift(
    List<ShiftModel> allShifts,
    List<GuardModel> allGuards, {
    DateTime? now,
  }) {
    // 1. Set of active guards
    final activeGuardIds = <String>{};
    for (final g in allGuards) {
      if (g.isActive) {
        activeGuardIds.add(g.uid.trim());
        if (g.email.isNotEmpty) activeGuardIds.add(g.email.trim().toLowerCase());
      }
    }

    // 2. Identify guards who currently have an active shift
    final referenceNow = now ?? DateTime.now();
    final guardsWithActiveShift = <String>{};
    for (final s in allShifts) {
      if (s.isCancelled || s.actualEndTime != null) continue;
      final st = s.status.toUpperCase().trim();
      final isStillActive = st == 'ACTIVE' && (s.actualStartTime != null || referenceNow.isBefore(s.endTime));
      if (isStillActive || (s.actualStartTime != null && s.actualEndTime == null)) {
        guardsWithActiveShift.add(s.guardId.trim());
        if (s.guardUid != null && s.guardUid!.isNotEmpty) {
          guardsWithActiveShift.add(s.guardUid!.trim());
        }
      }
    }

    // 3. Find candidate ASSIGNED shifts
    final candidates = <ShiftModel>[];
    for (final s in allShifts) {
      if (s.isCancelled) continue;
      final st = s.status.toUpperCase().trim();
      if (st != 'ASSIGNED') continue;
      if (s.actualStartTime != null || s.actualEndTime != null) continue;

      final gId = s.guardId.trim();
      final gUid = (s.guardUid ?? '').trim();
      final gEmail = (s.guardEmail ?? '').trim().toLowerCase();

      // Guard must be active
      final isGuardActive = activeGuardIds.contains(gId) ||
          activeGuardIds.contains(gUid) ||
          (gEmail.isNotEmpty && activeGuardIds.contains(gEmail));
      if (!isGuardActive) continue;

      // Guard must not already have an active shift
      if (guardsWithActiveShift.contains(gId) || (gUid.isNotEmpty && guardsWithActiveShift.contains(gUid))) {
        continue;
      }

      candidates.add(s);
    }

    if (candidates.isEmpty) return null;

    // Earliest upcoming scheduled start time
    candidates.sort((a, b) => a.startTime.compareTo(b.startTime));
    return candidates.first;
  }

  /// Real-time stream of all shifts (ordered by startTime descending) for Admin panel.
  Stream<List<ShiftModel>> watchAllShifts() {
    try {
      return _firestore
          .collection('shifts')
          .snapshots()
          .map((snapshot) {
        final list = <ShiftModel>[];
        for (final d in snapshot.docs) {
          try {
            list.add(ShiftModel.fromFirestore(d));
          } catch (e) {
            debugPrint('[ShiftService] Error parsing shift ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        return list;
      }).handleError((e) {
        debugPrint('[ShiftService] Error watching all shifts: $e');
        return <ShiftModel>[];
      });
    } catch (_) {
      return Stream.value(<ShiftModel>[]);
    }
  }

  /// Real-time stream of today's shifts for Admin and Dashboard.
  Stream<List<ShiftModel>> watchTodayShifts() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return watchAllShifts().map((shifts) {
      return shifts.where((s) {
        final isSameDate = s.shiftDate.year == now.year &&
            s.shiftDate.month == now.month &&
            s.shiftDate.day == now.day;
        final isStartTimeToday = (s.startTime.isAfter(todayStart) || s.startTime.isAtSameMomentAs(todayStart)) &&
            s.startTime.isBefore(todayEnd);
        return isSameDate || isStartTimeToday || s.isActive;
      }).toList();
    });
  }

  /// One-time fetch of all shifts for a specific guard.
  Future<List<ShiftModel>> getGuardShifts(String guardUid, [String? guardEmail, String? guardName]) async {
    try {
      final cleanUid = guardUid.trim();
      final cleanEmail = guardEmail?.trim().toLowerCase();
      final cleanName = guardName?.trim();
      final snapshot = await _firestore.collection('shifts').get();
      final list = <ShiftModel>[];
      for (final d in snapshot.docs) {
        try {
          final s = ShiftModel.fromFirestore(d);
          if (matchesGuard(s, cleanUid, cleanEmail, cleanName)) {
            list.add(s);
          }
        } catch (e) {
          debugPrint('[ShiftService] Error parsing shift ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      return list;
    } catch (e, st) {
      debugPrint('[ShiftService] Exception in getGuardShifts: $e\n$st');
      rethrow;
    }
  }

  /// Real-time stream of a specific guard's assigned shifts.
  /// Uses direct, robust Firestore snapshot mapping without artificial timeouts.
  Stream<List<ShiftModel>> watchGuardShifts(String guardUid, [String? guardEmail, String? guardName]) {
    final cleanUid = guardUid.trim();
    final cleanEmail = guardEmail?.trim().toLowerCase();
    final cleanName = guardName?.trim();

    debugPrint('[SHIFT_RUNTIME_DEBUG] watchGuardShifts called with targetUid=$cleanUid, email=$cleanEmail, name=$cleanName, authUid=$safeCurrentAuthUid');

    try {
      return _firestore
          .collection('shifts')
          .snapshots()
          .map((snapshot) {
        final list = <ShiftModel>[];
        debugPrint('[SHIFT_QUERY_DEBUG] Raw Firestore shifts documents count = ${snapshot.docs.length}');
        for (final d in snapshot.docs) {
          try {
            final s = ShiftModel.fromFirestore(d);
            final isMatch = matchesGuard(s, cleanUid, cleanEmail, cleanName);
            debugPrint('[SHIFT_QUERY_DEBUG] docId=${d.id} | guardId=${s.guardId} | guardUid=${s.guardUid} | guardName=${s.guardName} | status=${s.status} | effStatus=${s.effectiveStatus.name} | start=${s.startTime} | end=${s.endTime} | MATCH=$isMatch');
            if (isMatch) {
              list.add(s);
            }
          } catch (e) {
            debugPrint('[ShiftService] Error parsing shift doc ${d.id}: $e');
          }
        }
        debugPrint('[SHIFT_QUERY_DEBUG] Total matching shifts for guard ($cleanUid) = ${list.length}');
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        return list;
      }).handleError((e, st) {
        debugPrint('[ShiftService] Error watching guard shifts: $e\n$st');
        return <ShiftModel>[];
      });
    } catch (e) {
      debugPrint('[ShiftService] Exception creating watchGuardShifts stream: $e');
      return Stream.value(<ShiftModel>[]);
    }
  }

  /// Real-time stream of the guard's currently ACTIVE shift.
  Stream<ShiftModel?> watchGuardCurrentActiveShift(String guardUid, [String? guardEmail, String? guardName]) {
    final cleanUid = guardUid.trim();
    final cleanEmail = guardEmail?.trim().toLowerCase();
    final cleanName = guardName?.trim();

    return watchGuardShifts(cleanUid, cleanEmail, cleanName).map((shifts) {
      ShiftModel? activeShift;
      for (final s in shifts) {
        if (s.isCancelled) continue;
        if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
        if (s.isActive) {
          activeShift = s;
          break;
        }
      }
      return activeShift;
    }).handleError((e) {
      debugPrint('[ShiftService] Error watching active shift: $e');
      return null;
    });
  }

  /// One-time fetch of the guard's currently ACTIVE shift.
  Future<ShiftModel?> getGuardCurrentActiveShift(String guardUid, [String? guardEmail, String? guardName]) async {
    try {
      final cleanUid = guardUid.trim();
      final cleanEmail = guardEmail?.trim().toLowerCase();
      final cleanName = guardName?.trim();
      final shifts = await getGuardShifts(cleanUid, cleanEmail, cleanName);

      for (final shift in shifts) {
        if (shift.isCancelled) continue;
        if (shift.isCompleted || shift.status.toUpperCase() == 'COMPLETED' || shift.actualEndTime != null) continue;
        if (shift.isActive) {
          return shift;
        }
      }
      return null;
    } catch (e, st) {
      debugPrint('[ShiftService] Exception in getGuardCurrentActiveShift: $e\n$st');
      return null;
    }
  }

  /// Checks if the proposed shift interval overlaps with an existing active/assigned shift for the same guard.
  Future<bool> hasOverlappingShift({
    required String guardId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeShiftId,
  }) async {
    final query = await _firestore.collection('shifts').get();

    for (final doc in query.docs) {
      if (excludeShiftId != null && doc.id == excludeShiftId) continue;
      try {
        final existing = ShiftModel.fromFirestore(doc);
        if (existing.isCancelled) continue;
        if (!matchesGuard(existing, guardId)) continue;

        // Two intervals [S1, E1) and [S2, E2) overlap if S1 < E2 and E1 > S2
        if (startTime.isBefore(existing.endTime) && endTime.isAfter(existing.startTime)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Creates an Admin-assigned shift with configurable duration (8, 9, 10 hours) and strict overlap validation.
  Future<ShiftModel> createShift({
    required String guardId,
    String? guardUid,
    String? guardEmail,
    required String guardName,
    required DateTime shiftDate,
    required DateTime startDateTime,
    int durationHours = ShiftModel.standardDurationHours,
  }) async {
    final endDateTime = startDateTime.add(Duration(hours: durationHours));

    // 1. Check for overlapping shifts for this guard
    final overlaps = await hasOverlappingShift(
      guardId: guardId,
      startTime: startDateTime,
      endTime: endDateTime,
    );

    if (overlaps) {
      throw const OverlappingShiftException('This guard already has an overlapping shift.');
    }

    final docRef = _firestore.collection('shifts').doc();
    final shift = ShiftModel(
      shiftId: docRef.id,
      guardId: guardId,
      guardUid: guardUid ?? guardId,
      guardEmail: guardEmail,
      guardName: guardName,
      shiftDate: DateTime(shiftDate.year, shiftDate.month, shiftDate.day),
      startTime: startDateTime,
      endTime: endDateTime,
      durationHours: durationHours,
      status: 'ASSIGNED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(shift.toFirestore());

    // 2. Audit log
    try {
      await AuditService.instance.log(
        action: 'CREATE_SHIFT',
        targetEntity: 'shift',
        targetId: shift.shiftId,
        details: {
          'guardId': guardId,
          'guardName': guardName,
          'shiftDate': shiftDate.toIso8601String(),
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
          'durationHours': durationHours,
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // 3. Notify the assigned guard
    await _notificationService.createNotification(
      recipientUserId: guardId,
      title: 'New Shift Assigned',
      message: 'You have been assigned a $durationHours-hour shift on ${_formatDate(shiftDate)} from ${_formatTime(startDateTime)} to ${_formatTime(endDateTime)}.',
      type: 'shift',
      relatedEntityId: shift.shiftId,
    );

    return shift;
  }

  /// Updates an upcoming assigned shift (only if it has not started yet).
  Future<void> updateUpcomingShift(
    String shiftId, {
    String? guardId,
    String? guardUid,
    String? guardEmail,
    String? guardName,
    DateTime? shiftDate,
    DateTime? startDateTime,
    int? durationHours,
  }) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Shift record not found.');
    }

    final currentShift = ShiftModel.fromFirestore(snap);
    if (!currentShift.isUpcoming) {
      throw const ShiftNotEditableException('Only upcoming assigned shifts can be edited.');
    }

    final newGuardId = guardId ?? currentShift.guardId;
    final newGuardUid = guardUid ?? currentShift.guardUid;
    final newGuardEmail = guardEmail ?? currentShift.guardEmail;
    final newGuardName = guardName ?? currentShift.guardName;
    final newShiftDate = shiftDate ?? currentShift.shiftDate;
    final newStartTime = startDateTime ?? currentShift.startTime;
    final newDuration = durationHours ?? currentShift.durationHours;
    final newEndTime = newStartTime.add(Duration(hours: newDuration));

    // Overlap validation
    final overlaps = await hasOverlappingShift(
      guardId: newGuardId,
      startTime: newStartTime,
      endTime: newEndTime,
      excludeShiftId: shiftId,
    );

    if (overlaps) {
      throw const OverlappingShiftException('This guard already has an overlapping shift.');
    }

    final updated = currentShift.copyWith(
      guardId: newGuardId,
      guardUid: newGuardUid,
      guardEmail: newGuardEmail,
      guardName: newGuardName,
      shiftDate: newShiftDate,
      startTime: newStartTime,
      endTime: newEndTime,
      durationHours: newDuration,
    );

    await docRef.update(updated.toFirestore());

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'REASSIGN_SHIFT',
        targetEntity: 'shift',
        targetId: shiftId,
        details: {
          'previousGuardId': currentShift.guardId,
          'newGuardId': newGuardId,
          'newGuardName': newGuardName,
          'shiftDate': newShiftDate.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // Notify updated guard
    await _notificationService.createNotification(
      recipientUserId: newGuardId,
      title: 'Shift Updated',
      message: 'Your upcoming shift has been rescheduled to ${_formatDate(newShiftDate)} from ${_formatTime(newStartTime)} to ${_formatTime(newEndTime)}.',
      type: 'shift',
      relatedEntityId: shiftId,
    );
  }

  /// Cancels an upcoming assigned shift.
  Future<void> cancelUpcomingShift(String shiftId, {String? reason}) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Shift record not found.');
    }

    final currentShift = ShiftModel.fromFirestore(snap);
    if (currentShift.isCompleted) {
      throw const ShiftNotEditableException('Completed shifts cannot be cancelled.');
    }

    await docRef.update({
      'status': 'CANCELLED',
      'cancellationReason': reason ?? 'Cancelled by Admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'CANCEL_SHIFT',
        targetEntity: 'shift',
        targetId: shiftId,
        details: {
          'guardId': currentShift.guardId,
          'guardName': currentShift.guardName,
          'reason': reason ?? 'Cancelled by Admin',
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // Notify Guard
    await _notificationService.createNotification(
      recipientUserId: currentShift.guardId,
      title: 'Shift Cancelled',
      message: 'Your shift scheduled for ${_formatDate(currentShift.shiftDate)} (${_formatTime(currentShift.startTime)} - ${_formatTime(currentShift.endTime)}) has been cancelled.',
      type: 'shift',
      relatedEntityId: shiftId,
    );
  }

  /// Starts an assigned shift by Admin (MANUAL START / OVERRIDE).
  /// Enforces rule: Guard cannot have overlapping active shifts.
  Future<void> startShiftByAdmin({
    required String shiftId,
    required String adminUid,
    required String adminName,
  }) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Shift record not found.');
    }

    final targetShift = ShiftModel.fromFirestore(snap);

    // Verify guard does not already have an active shift
    final activeShift = await getGuardCurrentActiveShift(targetShift.guardId, targetShift.guardEmail);
    if (activeShift != null && activeShift.shiftId != shiftId) {
      throw Exception('This guard already has an active shift.');
    }

    final now = DateTime.now();
    await docRef.update({
      'status': 'ACTIVE',
      'actualStartTime': Timestamp.fromDate(now),
      'startedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 1. Notify Guard
    await _notificationService.createNotification(
      recipientUserId: targetShift.guardId,
      title: 'Shift Started',
      message: 'Your shift has been started by Admin ($adminName). Date: ${_formatDate(targetShift.shiftDate)}, Start: ${_formatTime(now)}.',
      type: 'shift',
      relatedEntityId: shiftId,
    );

    // 2. Audit log: ADMIN_MANUAL_START
    await AuditService.instance.logAction(
      adminUid: adminUid,
      adminName: adminName,
      action: 'ADMIN_MANUAL_START',
      targetEntity: 'shift',
      targetId: shiftId,
      details: {
        'shiftId': shiftId,
        'guardUid': targetShift.guardUid ?? targetShift.guardId,
        'guardName': targetShift.guardName,
        'action': 'ADMIN_MANUAL_START',
        'actor': adminUid,
        'actorName': adminName,
        'timestamp': now.toIso8601String(),
        'scheduledStart': targetShift.startTime.toIso8601String(),
        'scheduledEnd': targetShift.endTime.toIso8601String(),
        'actualStart': now.toIso8601String(),
        'actualEnd': null,
      },
    );
  }

  /// Ends an active shift by Admin (MANUAL END / OVERRIDE).
  /// Outstanding financial responsibility remains unchanged and attached to the guard.
  Future<void> endShiftByAdmin({
    required String shiftId,
    required String adminUid,
    required String adminName,
  }) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Shift record not found.');
    }

    final targetShift = ShiftModel.fromFirestore(snap);
    final now = DateTime.now();

    await docRef.update({
      'status': 'COMPLETED',
      'actualEndTime': Timestamp.fromDate(now),
      'endedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 1. Notify Guard
    await _notificationService.createNotification(
      recipientUserId: targetShift.guardId,
      title: 'Shift Ended',
      message: 'Your shift has been ended by Admin ($adminName). Date: ${_formatDate(targetShift.shiftDate)}, End: ${_formatTime(now)}.',
      type: 'shift',
      relatedEntityId: shiftId,
    );

    // 2. Audit log: ADMIN_MANUAL_END
    await AuditService.instance.logAction(
      adminUid: adminUid,
      adminName: adminName,
      action: 'ADMIN_MANUAL_END',
      targetEntity: 'shift',
      targetId: shiftId,
      details: {
        'shiftId': shiftId,
        'guardUid': targetShift.guardUid ?? targetShift.guardId,
        'guardName': targetShift.guardName,
        'action': 'ADMIN_MANUAL_END',
        'actor': adminUid,
        'actorName': adminName,
        'timestamp': now.toIso8601String(),
        'scheduledStart': targetShift.startTime.toIso8601String(),
        'scheduledEnd': targetShift.endTime.toIso8601String(),
        'actualStart': targetShift.actualStartTime?.toIso8601String(),
        'actualEnd': now.toIso8601String(),
      },
    );

    // Trigger next shift auto start check
    await processAutomaticShiftTransitions();
  }

  /// Automatically starts an assigned shift (SYSTEM AUTO START).
  /// Idempotent: safe to run multiple times without duplicating starts.
  Future<bool> startShiftAutomatically(String shiftId) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);

    try {
      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return false;

      final data = snap.data()!;
      final currentStatus = (data['status'] as String? ?? '').toUpperCase().trim();
      if (currentStatus != 'ASSIGNED' || data['actualStartTime'] != null) {
        // Idempotent: already active, completed, or cancelled
        return false;
      }

      final shift = ShiftModel.fromFirestore(snap);
      if (shift.isCancelled) return false;

      // Verify guard is active
      final guardDoc = await _firestore.collection('guards').doc(shift.guardId).get();
      if (guardDoc.exists) {
        final isActive = guardDoc.data()?['isActive'] as bool? ?? true;
        if (!isActive) {
          debugPrint('[ShiftService] Inactive guard cannot auto-start shift $shiftId');
          return false;
        }
      }

      final now = DateTime.now();

      await docRef.update({
        'status': 'ACTIVE',
        'actualStartTime': Timestamp.fromDate(now),
        'startedBy': 'SYSTEM',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log: SYSTEM_AUTO_START
      await AuditService.instance.logAction(
        adminUid: 'SYSTEM',
        adminName: 'SYSTEM',
        action: 'SYSTEM_AUTO_START',
        targetEntity: 'shift',
        targetId: shiftId,
        details: {
          'shiftId': shiftId,
          'guardUid': shift.guardUid ?? shift.guardId,
          'guardName': shift.guardName,
          'action': 'SYSTEM_AUTO_START',
          'actor': 'SYSTEM',
          'timestamp': now.toIso8601String(),
          'scheduledStart': shift.startTime.toIso8601String(),
          'scheduledEnd': shift.endTime.toIso8601String(),
          'actualStart': now.toIso8601String(),
          'actualEnd': null,
        },
      );

      // Notification to Guard
      await _notificationService.createNotification(
        recipientUserId: shift.guardId,
        title: 'Shift Started',
        message: 'Your shift has started. Date: ${_formatDate(shift.shiftDate)}, Start: ${_formatTime(shift.startTime)}, End: ${_formatTime(shift.endTime)}, Duration: ${shift.durationHours} Hours.',
        type: 'shift',
        relatedEntityId: shiftId,
      );

      return true;
    } catch (e) {
      debugPrint('[ShiftService] Error in startShiftAutomatically: $e');
      return false;
    }
  }

  /// Automatically ends an active shift (SYSTEM AUTO END).
  /// Idempotent: safe to run multiple times without duplicating ends.
  Future<bool> endShiftAutomatically(String shiftId) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);

    try {
      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return false;

      final data = snap.data()!;
      final currentStatus = (data['status'] as String? ?? '').toUpperCase().trim();
      if (currentStatus != 'ACTIVE' || data['actualEndTime'] != null) {
        // Idempotent: not active or already completed
        return false;
      }

      final shift = ShiftModel.fromFirestore(snap);
      final now = DateTime.now();

      await docRef.update({
        'status': 'COMPLETED',
        'actualEndTime': Timestamp.fromDate(now),
        'endedBy': 'SYSTEM',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log: SYSTEM_AUTO_END
      await AuditService.instance.logAction(
        adminUid: 'SYSTEM',
        adminName: 'SYSTEM',
        action: 'SYSTEM_AUTO_END',
        targetEntity: 'shift',
        targetId: shiftId,
        details: {
          'shiftId': shiftId,
          'guardUid': shift.guardUid ?? shift.guardId,
          'guardName': shift.guardName,
          'action': 'SYSTEM_AUTO_END',
          'actor': 'SYSTEM',
          'timestamp': now.toIso8601String(),
          'scheduledStart': shift.startTime.toIso8601String(),
          'scheduledEnd': shift.endTime.toIso8601String(),
          'actualStart': shift.actualStartTime?.toIso8601String(),
          'actualEnd': now.toIso8601String(),
        },
      );

      // Notification to Outgoing Guard
      await _notificationService.createNotification(
        recipientUserId: shift.guardId,
        title: 'Shift Ended',
        message: 'Your shift has ended. Date: ${_formatDate(shift.shiftDate)}, Scheduled Start: ${_formatTime(shift.startTime)}, Scheduled End: ${_formatTime(shift.endTime)}, Actual End: ${_formatTime(now)}.',
        type: 'shift',
        relatedEntityId: shiftId,
      );

      // Trigger next shift auto start check
      await processAutomaticShiftTransitions();

      return true;
    } catch (e) {
      debugPrint('[ShiftService] Error in endShiftAutomatically: $e');
      return false;
    }
  }

  /// Processes automatic transitions across all shifts in Firestore.
  /// - Automatically ends ACTIVE shifts whose scheduled end time has arrived.
  /// - Automatically starts eligible ASSIGNED shifts whose scheduled start time has arrived.
  /// - Inactive guard assigned shifts are NOT auto-started, and Admin is notified.
  /// - Idempotent and safe to run on startup, on schedule, or via background daemon.
  Future<Map<String, int>> processAutomaticShiftTransitions({DateTime? testNow}) async {
    final now = testNow ?? DateTime.now();
    int startedCount = 0;
    int endedCount = 0;

    try {
      // 1. Fetch guards to verify active status
      final guardsSnap = await _firestore.collection('guards').get();
      final allGuards = guardsSnap.docs.map((d) {
        try {
          return GuardModel.fromFirestore(d);
        } catch (_) {
          return null;
        }
      }).whereType<GuardModel>().toList();

      final activeGuardsMap = <String, GuardModel>{};
      for (final g in allGuards) {
        if (g.isActive) {
          activeGuardsMap[g.uid] = g;
        }
      }

      // 2. Fetch all shifts
      final shiftsSnap = await _firestore.collection('shifts').get();
      final allShifts = shiftsSnap.docs.map((d) {
        try {
          return ShiftModel.fromFirestore(d);
        } catch (_) {
          return null;
        }
      }).whereType<ShiftModel>().toList();

      // 3. Auto End any active shifts whose scheduled endTime <= now
      for (final shift in allShifts) {
        if (shift.isCancelled) continue;
        final st = shift.status.toUpperCase().trim();
        if (st == 'ACTIVE' && shift.actualEndTime == null) {
          if (now.isAfter(shift.endTime) || now.isAtSameMomentAs(shift.endTime)) {
            final ended = await endShiftAutomatically(shift.shiftId);
            if (ended) endedCount++;
          }
        }
      }

      // 4. Auto Start any eligible assigned shift whose scheduled startTime <= now
      for (final shift in allShifts) {
        if (shift.isCancelled) continue;
        final st = shift.status.toUpperCase().trim();
        if (st == 'ASSIGNED' && shift.actualStartTime == null) {
          if (now.isAfter(shift.startTime) || now.isAtSameMomentAs(shift.startTime)) {
            // Guard validation
            final guard = allGuards.firstWhere(
              (g) => matchesGuard(shift, g.uid, g.email, g.name),
              orElse: () => GuardModel(
                uid: shift.guardId,
                name: shift.guardName,
                email: shift.guardEmail ?? '',
                role: 'guard',
                currentShift: '',
                isActive: false,
                createdAt: DateTime.now(),
              ),
            );

            if (!guard.isActive) {
              // INACTIVE GUARD: DO NOT auto-start!
              // Keep shift in ASSIGNED state.
              // Check if we already alerted admin for this shift to prevent duplicate notifications
              try {
                final existingAlert = await _firestore
                    .collection('notifications')
                    .where('recipientUserId', isEqualTo: 'admin')
                    .where('relatedEntityId', isEqualTo: shift.shiftId)
                    .where('type', isEqualTo: 'shift_alert')
                    .limit(1)
                    .get();

                if (existingAlert.docs.isEmpty) {
                  await _notificationService.createNotification(
                    recipientUserId: 'admin',
                    title: 'Shift Alert',
                    message: 'Next scheduled shift could not be started automatically for Guard ${guard.name}. Guard is inactive.',
                    type: 'shift_alert',
                    relatedEntityId: shift.shiftId,
                  );
                }
              } catch (_) {}
              continue;
            }

            // Check if guard already has an active shift
            final hasActive = allShifts.any((s) =>
                s.shiftId != shift.shiftId &&
                s.status.toUpperCase().trim() == 'ACTIVE' &&
                !s.isCancelled &&
                s.actualEndTime == null &&
                matchesGuard(s, guard.uid, guard.email, guard.name));

            if (!hasActive) {
              final started = await startShiftAutomatically(shift.shiftId);
              if (started) startedCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ShiftService] Error processing automatic transitions: $e');
    }

    return {'started': startedCount, 'ended': endedCount};
  }

  /// Reassigns a future shift to a different Guard with overlap validation,
  /// notification to both guards, audit logging, and schedule exception tracking if recurring.
  Future<void> reassignShiftGuard({
    required String shiftId,
    required String newGuardId,
    String? newGuardUid,
    String? newGuardEmail,
    required String newGuardName,
  }) async {
    final docRef = _firestore.collection('shifts').doc(shiftId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Shift record not found.');
    }

    final currentShift = ShiftModel.fromFirestore(snap);
    if (!currentShift.isUpcoming) {
      throw const ShiftNotEditableException('Only upcoming assigned shifts can be reassigned.');
    }

    // Overlap validation for new guard
    final overlaps = await hasOverlappingShift(
      guardId: newGuardId,
      startTime: currentShift.startTime,
      endTime: currentShift.endTime,
      excludeShiftId: shiftId,
    );

    if (overlaps) {
      throw const OverlappingShiftException('This shift overlaps with an existing shift for this Guard.');
    }

    final oldGuardId = currentShift.guardId;
    final oldGuardName = currentShift.guardName;

    // Update shift record
    final updateData = <String, dynamic>{
      'guardId': newGuardId,
      'guardUid': newGuardUid ?? newGuardId,
      'guardName': newGuardName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newGuardEmail != null) {
      updateData['guardEmail'] = newGuardEmail;
    }
    await docRef.update(updateData);

    // If part of a recurring schedule, record OVERRIDE exception
    if (currentShift.scheduleId != null && currentShift.scheduleId!.isNotEmpty) {
      try {
        final excRef = _firestore.collection('schedule_exceptions').doc();
        final exc = ScheduleExceptionModel(
          exceptionId: excRef.id,
          scheduleId: currentShift.scheduleId!,
          date: currentShift.shiftDate,
          type: 'OVERRIDE',
          overrideGuardId: newGuardId,
          overrideGuardName: newGuardName,
          reason: 'Reassigned from $oldGuardName to $newGuardName',
          createdBy: safeCurrentAuthUid ?? 'Admin',
          createdAt: DateTime.now(),
        );
        await excRef.set(exc.toFirestore());
      } catch (e) {
        debugPrint('[ShiftService] Error creating schedule override exception: $e');
      }
    }

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'REASSIGN_SHIFT',
        targetEntity: 'shift',
        targetId: shiftId,
        details: {
          'previousGuardId': oldGuardId,
          'previousGuardName': oldGuardName,
          'newGuardId': newGuardId,
          'newGuardName': newGuardName,
          'shiftDate': currentShift.shiftDate.toIso8601String(),
          'startTime': currentShift.startTime.toIso8601String(),
          'endTime': currentShift.endTime.toIso8601String(),
          if (currentShift.scheduleId != null) 'scheduleId': currentShift.scheduleId,
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // Notify old guard
    await _notificationService.createNotification(
      recipientUserId: oldGuardId,
      title: 'Shift Reassigned',
      message: 'Your shift on ${_formatDate(currentShift.shiftDate)} has been reassigned to $newGuardName.',
      type: 'shift',
      relatedEntityId: shiftId,
    );

    // Notify new guard
    await _notificationService.createNotification(
      recipientUserId: newGuardId,
      title: 'New Shift Assigned',
      message: 'You have been assigned a shift on ${_formatDate(currentShift.shiftDate)} from ${_formatTime(currentShift.startTime)} to ${_formatTime(currentShift.endTime)}.',
      type: 'shift',
      relatedEntityId: shiftId,
    );
  }

  /// Real-time stream of all recurring shift schedules.
  Stream<List<ShiftScheduleModel>> watchAllSchedules() {
    try {
      return _firestore
          .collection('shift_schedules')
          .snapshots()
          .map((snapshot) {
        final list = <ShiftScheduleModel>[];
        for (final d in snapshot.docs) {
          try {
            list.add(ShiftScheduleModel.fromFirestore(d));
          } catch (e) {
            debugPrint('[ShiftService] Error parsing schedule ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[ShiftService] Error watching schedules: $e');
        return <ShiftScheduleModel>[];
      });
    } catch (_) {
      return Stream.value(<ShiftScheduleModel>[]);
    }
  }

  /// One-time fetch of all recurring shift schedules.
  Future<List<ShiftScheduleModel>> getSchedules() async {
    try {
      final snap = await _firestore.collection('shift_schedules').get();
      final list = <ShiftScheduleModel>[];
      for (final d in snap.docs) {
        try {
          list.add(ShiftScheduleModel.fromFirestore(d));
        } catch (e) {
          debugPrint('[ShiftService] Error parsing schedule ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[ShiftService] Error getting schedules: $e');
      return [];
    }
  }

  /// Stream of exceptions (skips / overrides) for a given schedule.
  Stream<List<ScheduleExceptionModel>> watchScheduleExceptions(String scheduleId) {
    try {
      return _firestore
          .collection('schedule_exceptions')
          .where('scheduleId', isEqualTo: scheduleId)
          .snapshots()
          .map((snapshot) {
        final list = <ScheduleExceptionModel>[];
        for (final d in snapshot.docs) {
          try {
            list.add(ScheduleExceptionModel.fromFirestore(d));
          } catch (e) {
            debugPrint('[ShiftService] Error parsing exception ${d.id}: $e');
          }
        }
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }).handleError((e) {
        debugPrint('[ShiftService] Error watching schedule exceptions: $e');
        return <ScheduleExceptionModel>[];
      });
    } catch (_) {
      return Stream.value(<ScheduleExceptionModel>[]);
    }
  }

  /// Creates a recurring schedule and generates the concrete daily shifts.
  /// Validates date range, selected weekdays, overlap against all existing shifts,
  /// and uses deterministic shift IDs to prevent duplicate creation.
  Future<ShiftScheduleModel> createRecurringSchedule({
    required String guardId,
    String? guardUid,
    String? guardEmail,
    required String guardName,
    required DateTime startDate,
    required DateTime endDate,
    required int startHour,
    required int startMinute,
    int durationHours = ShiftModel.standardDurationHours,
    required List<int> weekdays,
    String? createdBy,
  }) async {
    final cleanStartDate = DateTime(startDate.year, startDate.month, startDate.day);
    final cleanEndDate = DateTime(endDate.year, endDate.month, endDate.day);

    if (cleanEndDate.isBefore(cleanStartDate)) {
      throw ArgumentError('End Date must not be before Start Date.');
    }

    if (weekdays.isEmpty) {
      throw ArgumentError('At least ONE weekday must be selected.');
    }

    // 1. Gather all candidate dates that match the selected weekdays
    final candidateDates = <DateTime>[];
    var curr = cleanStartDate;
    while (!curr.isAfter(cleanEndDate)) {
      if (weekdays.contains(curr.weekday)) {
        candidateDates.add(curr);
      }
      curr = curr.add(const Duration(days: 1));
    }

    if (candidateDates.isEmpty) {
      throw ArgumentError('No matching dates found for selected weekdays in this date range.');
    }

    // 2. Fetch all existing non-cancelled shifts to validate overlap across candidate shifts
    final existingShiftsSnap = await _firestore.collection('shifts').get();
    final existingGuardShifts = existingShiftsSnap.docs
        .map((d) {
          try {
            return ShiftModel.fromFirestore(d);
          } catch (_) {
            return null;
          }
        })
        .where((s) => s != null && !s.isCancelled && matchesGuard(s, guardId, guardEmail))
        .cast<ShiftModel>()
        .toList();

    // Check each candidate date for overlaps
    final shiftsToCreate = <ShiftModel>[];
    final scheduleDocRef = _firestore.collection('shift_schedules').doc();
    final scheduleId = scheduleDocRef.id;

    for (final date in candidateDates) {
      final sTime = DateTime(date.year, date.month, date.day, startHour, startMinute);
      final eTime = sTime.add(Duration(hours: durationHours));

      // Overlap check
      for (final existing in existingGuardShifts) {
        if (sTime.isBefore(existing.endTime) && eTime.isAfter(existing.startTime)) {
          throw const OverlappingShiftException('This shift overlaps with an existing shift for this Guard.');
        }
      }

      // Deterministic shift ID: shift_{scheduleId}_{YYYYMMDD}
      final ymd = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final deterministicShiftId = 'shift_${scheduleId}_$ymd';

      final shift = ShiftModel(
        shiftId: deterministicShiftId,
        scheduleId: scheduleId,
        guardId: guardId,
        guardUid: guardUid ?? guardId,
        guardEmail: guardEmail,
        guardName: guardName,
        shiftDate: date,
        startTime: sTime,
        endTime: eTime,
        durationHours: durationHours,
        status: 'ASSIGNED',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      shiftsToCreate.add(shift);
    }

    final schedule = ShiftScheduleModel(
      scheduleId: scheduleId,
      guardId: guardId,
      guardUid: guardUid,
      guardEmail: guardEmail,
      guardName: guardName,
      startDate: cleanStartDate,
      endDate: cleanEndDate,
      startHour: startHour,
      startMinute: startMinute,
      durationHours: durationHours,
      weekdays: weekdays,
      status: 'ACTIVE',
      createdBy: createdBy ?? safeCurrentAuthUid ?? 'Admin',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Batch commit: schedule + daily shifts (in chunks of 400 if needed)
    final existingDocIds = existingShiftsSnap.docs.map((d) => d.id).toSet();

    // Save schedule document
    await scheduleDocRef.set(schedule.toFirestore());

    // Save daily shifts in batches
    const chunkSize = 400;
    for (var i = 0; i < shiftsToCreate.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize < shiftsToCreate.length) ? i + chunkSize : shiftsToCreate.length;
      for (var j = i; j < end; j++) {
        final shift = shiftsToCreate[j];
        if (!existingDocIds.contains(shift.shiftId)) {
          final sRef = _firestore.collection('shifts').doc(shift.shiftId);
          batch.set(sRef, shift.toFirestore());
        }
      }
      await batch.commit();
    }

    // 4. Audit log
    try {
      await AuditService.instance.log(
        action: 'CREATE_SCHEDULE',
        targetEntity: 'shift_schedule',
        targetId: scheduleId,
        details: {
          'guardId': guardId,
          'guardName': guardName,
          'startDate': cleanStartDate.toIso8601String(),
          'endDate': cleanEndDate.toIso8601String(),
          'durationHours': durationHours,
          'weekdays': weekdays,
          'generatedShiftsCount': shiftsToCreate.length,
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // 5. Notify assigned guard
    await _notificationService.createNotification(
      recipientUserId: guardId,
      title: 'Shift Schedule Assigned',
      message: 'Your recurring shift schedule has been assigned from ${_formatDate(cleanStartDate)} to ${_formatDate(cleanEndDate)} (${schedule.weekdaysFormatted}).',
      type: 'shift',
      relatedEntityId: scheduleId,
    );

    return schedule;
  }

  /// Pauses an active schedule.
  Future<void> pauseSchedule(String scheduleId) async {
    await _firestore.collection('shift_schedules').doc(scheduleId).update({
      'status': 'PAUSED',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await AuditService.instance.log(
        action: 'PAUSE_SCHEDULE',
        targetEntity: 'shift_schedule',
        targetId: scheduleId,
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }
  }

  /// Resumes a paused schedule.
  Future<void> resumeSchedule(String scheduleId) async {
    await _firestore.collection('shift_schedules').doc(scheduleId).update({
      'status': 'ACTIVE',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await AuditService.instance.log(
        action: 'RESUME_SCHEDULE',
        targetEntity: 'shift_schedule',
        targetId: scheduleId,
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }
  }

  /// Cancels a schedule and cancels future unstarted ASSIGNED daily shifts.
  /// Never modifies completed or active shifts.
  Future<void> cancelSchedule(String scheduleId, {String? reason}) async {
    final schedDoc = await _firestore.collection('shift_schedules').doc(scheduleId).get();
    if (!schedDoc.exists) throw Exception('Schedule not found.');

    final schedule = ShiftScheduleModel.fromFirestore(schedDoc);

    await _firestore.collection('shift_schedules').doc(scheduleId).update({
      'status': 'CANCELLED',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Query shifts associated with this schedule
    final shiftsSnap = await _firestore.collection('shifts').where('scheduleId', isEqualTo: scheduleId).get();
    final now = DateTime.now();

    final batch = _firestore.batch();
    int cancelledCount = 0;

    for (final doc in shiftsSnap.docs) {
      try {
        final shift = ShiftModel.fromFirestore(doc);
        // Only cancel future unstarted assigned shifts
        if (shift.status == 'ASSIGNED' && shift.startTime.isAfter(now)) {
          batch.update(doc.reference, {
            'status': 'CANCELLED',
            'cancellationReason': reason ?? 'Schedule cancelled by Admin',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          cancelledCount++;
        }
      } catch (_) {}
    }

    if (cancelledCount > 0) {
      await batch.commit();
    }

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'CANCEL_SCHEDULE',
        targetEntity: 'shift_schedule',
        targetId: scheduleId,
        details: {
          'guardId': schedule.guardId,
          'reason': reason ?? 'Cancelled by Admin',
          'cancelledFutureShifts': cancelledCount,
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // Notify guard
    await _notificationService.createNotification(
      recipientUserId: schedule.guardId,
      title: 'Shift Schedule Cancelled',
      message: 'Your recurring shift schedule (${schedule.weekdaysFormatted}) has been cancelled by Admin.',
      type: 'shift',
      relatedEntityId: scheduleId,
    );
  }

  /// Skips a specific date in a recurring schedule.
  /// Creates a ScheduleExceptionModel and cancels any upcoming unstarted shift on that date.
  Future<void> skipScheduleDate({
    required String scheduleId,
    required DateTime date,
    String? reason,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final schedDoc = await _firestore.collection('shift_schedules').doc(scheduleId).get();
    if (!schedDoc.exists) throw Exception('Schedule not found.');
    final schedule = ShiftScheduleModel.fromFirestore(schedDoc);

    // Create exception record
    final excRef = _firestore.collection('schedule_exceptions').doc();
    final exc = ScheduleExceptionModel(
      exceptionId: excRef.id,
      scheduleId: scheduleId,
      date: cleanDate,
      type: 'SKIP',
      reason: reason ?? 'Date skipped by Admin',
      createdBy: safeCurrentAuthUid ?? 'Admin',
      createdAt: DateTime.now(),
    );
    await excRef.set(exc.toFirestore());

    // Find future shift on that date for this schedule and cancel it
    final shiftsSnap = await _firestore.collection('shifts').where('scheduleId', isEqualTo: scheduleId).get();
    final now = DateTime.now();

    for (final doc in shiftsSnap.docs) {
      try {
        final shift = ShiftModel.fromFirestore(doc);
        final sDate = DateTime(shift.shiftDate.year, shift.shiftDate.month, shift.shiftDate.day);
        if (sDate.isAtSameMomentAs(cleanDate) && shift.status == 'ASSIGNED' && shift.startTime.isAfter(now)) {
          await doc.reference.update({
            'status': 'CANCELLED',
            'cancellationReason': 'Date skipped: ${reason ?? "Admin exception"}',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    }

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'SKIP_SCHEDULE_DATE',
        targetEntity: 'shift_schedule',
        targetId: scheduleId,
        details: {
          'date': cleanDate.toIso8601String(),
          'reason': reason ?? 'Date skipped by Admin',
        },
      );
    } catch (e) {
      debugPrint('[ShiftService] Audit log error: $e');
    }

    // Notify guard
    await _notificationService.createNotification(
      recipientUserId: schedule.guardId,
      title: 'Shift Cancelled (Holiday / Skipped)',
      message: 'Your shift on ${_formatDate(cleanDate)} has been skipped/cancelled.',
      type: 'shift',
      relatedEntityId: scheduleId,
    );
  }

  /// Streams real operational statistics (Entries, Exits, Collection) for a specific shift.
  Stream<ShiftStats> watchShiftStats(ShiftModel shift) {
    late StreamController<ShiftStats> controller;
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

        controller.add(ShiftStats(
          entriesCount: entries,
          exitsCount: exits,
          totalCollection: netTotal,
          cashCollection: netCash,
          upiCollection: netUpi,
        ));
      }
    }

    final startTs = Timestamp.fromDate(shift.startTime);

    controller = StreamController<ShiftStats>.broadcast(
      onListen: () {
        notify();

        try {
          entriesSub = _firestore
              .collection('parking_records')
              .where('entryTime', isGreaterThanOrEqualTo: startTs)
              .snapshots()
              .listen((snap) {
            entries = snap.docs.where((d) {
              final eTime = (d.data()['entryTime'] as Timestamp?)?.toDate();
              if (eTime == null || eTime.isAfter(shift.endTime)) return false;
              final gUid = d.data()['guardUid'] as String? ?? '';
              return gUid.isEmpty || gUid == shift.guardId || (shift.guardUid != null && gUid == shift.guardUid);
            }).length;
            notify();
          });
        } catch (_) {}

        try {
          exitsSub = _firestore
              .collection('parking_records')
              .where('exitTime', isGreaterThanOrEqualTo: startTs)
              .snapshots()
              .listen((snap) {
            exits = snap.docs.where((d) {
              final exTime = (d.data()['exitTime'] as Timestamp?)?.toDate();
              if (exTime == null || exTime.isAfter(shift.endTime)) return false;
              final exUid = d.data()['exitGuardUid'] as String? ?? '';
              return exUid.isEmpty || exUid == shift.guardId || (shift.guardUid != null && exUid == shift.guardUid);
            }).length;
            notify();
          });
        } catch (_) {}

        try {
          txnsSub = _firestore
              .collection('payment_transactions')
              .where('createdAt', isGreaterThanOrEqualTo: startTs)
              .snapshots()
              .listen((snap) {
            double c = 0.0;
            double u = 0.0;

            for (final doc in snap.docs) {
              final data = doc.data();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              if (createdAt != null && createdAt.isAfter(shift.endTime)) continue;

              final collectorUid = data['collectorGuardUid'] as String? ?? '';
              if (collectorUid.isNotEmpty &&
                  collectorUid != shift.guardId &&
                  (shift.guardUid == null || collectorUid != shift.guardUid)) {
                continue;
              }

              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final pType = (data['paymentType'] as String? ?? '').toUpperCase();
              final pMethod = (data['paymentMethod'] as String? ?? 'cash').toLowerCase();
              final isUpi = pMethod == 'upi';

              if (pType == 'ADVANCE' || pType == 'FINAL') {
                if (isUpi) {
                  u += amount;
                } else {
                  c += amount;
                }
              } else if (pType == 'REFUND') {
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
          });
        } catch (_) {}
      },
      onCancel: () {
        entriesSub?.cancel();
        exitsSub?.cancel();
        txnsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// One-time fetch of today's operational and financial metrics for a specific guard.
  Future<Map<String, dynamic>> getGuardPerformanceMetrics(String guardUid, [String? guardEmail]) async {
    final cleanUid = guardUid.trim();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayStartTimestamp = Timestamp.fromDate(todayStart);

    int entries = 0;
    int exits = 0;
    double cash = 0.0;
    double upi = 0.0;

    try {
      final recordsSnap = await _firestore
          .collection('parking_records')
          .where('entryTime', isGreaterThanOrEqualTo: todayStartTimestamp)
          .get();

      for (final doc in recordsSnap.docs) {
        final data = doc.data();
        if (data['entryGuardUid'] == cleanUid) {
          entries++;
        }
        if (data['exitGuardUid'] == cleanUid) {
          exits++;
        }
      }

      final txnsSnap = await _firestore
          .collection('payment_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: todayStartTimestamp)
          .get();

      for (final doc in txnsSnap.docs) {
        final data = doc.data();
        if (data['guardUid'] == cleanUid) {
          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final pType = (data['paymentType'] as String? ?? '').toUpperCase();
          final isUpi = (data['paymentMethod'] as String? ?? 'cash').toLowerCase() == 'upi';

          if (pType == 'ADVANCE' || pType == 'FINAL') {
            if (isUpi) {
              upi += amt;
            } else {
              cash += amt;
            }
          } else if (pType == 'REFUND') {
            if (isUpi) {
              upi -= amt;
            } else {
              cash -= amt;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ShiftService] Error getting guard performance metrics: $e');
    }

    final netCash = cash < 0 ? 0.0 : cash;
    final netUpi = upi < 0 ? 0.0 : upi;
    final netTotal = (netCash + netUpi) < 0 ? 0.0 : (netCash + netUpi);

    return {
      'todayEntries': entries,
      'todayExits': exits,
      'totalCollection': netTotal,
      'cashCollection': netCash,
      'upiCollection': netUpi,
    };
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$min $period';
  }
}
