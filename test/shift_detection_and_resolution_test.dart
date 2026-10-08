import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/shift_service.dart';

void main() {
  group('Guard Shift Detection & Resolution Tests', () {
    const testGuardUid = 'firebase_auth_uid_12345';
    const testGuardEmail = 'guard1@carparking.com';
    const testGuardDocId = 'guard_doc_001';

    test('1. Shift matches Guard by exact guardId, guardUid, or guardEmail', () {
      final shiftWithUid = ShiftModel(
        shiftId: 's1',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 7)),
      );
      expect(ShiftService.matchesGuard(shiftWithUid, testGuardUid), isTrue);
      expect(ShiftService.matchesGuard(shiftWithUid, 'other_uid'), isFalse);

      final shiftWithDocIdAndUid = ShiftModel(
        shiftId: 's2',
        guardId: testGuardDocId,
        guardUid: testGuardUid,
        guardEmail: testGuardEmail,
        guardName: 'Guard One',
        shiftDate: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 7)),
      );
      // Matches even if searched by auth UID or email
      expect(ShiftService.matchesGuard(shiftWithDocIdAndUid, testGuardUid), isTrue);
      expect(ShiftService.matchesGuard(shiftWithDocIdAndUid, testGuardDocId), isTrue);
      expect(ShiftService.matchesGuard(shiftWithDocIdAndUid, 'unrelated_id', testGuardEmail), isTrue);
    });

    test('2. Active shift within startTime <= now < endTime is resolved as ACTIVE', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 2));
      final endTime = now.add(const Duration(hours: 6));

      final shift = ShiftModel(
        shiftId: 'active_shift_1',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: startTime,
        endTime: endTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.active));
      expect(shift.isActive, isTrue);
      expect(shift.isUpcoming, isFalse);
      expect(shift.isCompleted, isFalse);
      expect(shift.isCancelled, isFalse);
    });

    test('3. Upcoming assigned shift before startTime is resolved as ASSIGNED', () {
      final now = DateTime.now();
      final startTime = now.add(const Duration(hours: 2));
      final endTime = startTime.add(const Duration(hours: 8));

      final shift = ShiftModel(
        shiftId: 'upcoming_shift_1',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: startTime,
        endTime: endTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.assigned));
      expect(shift.isUpcoming, isTrue);
      expect(shift.isActive, isFalse);
      expect(shift.isCompleted, isFalse);
    });

    test('4. Completed shift after endTime is resolved as COMPLETED', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 9));
      final endTime = startTime.add(const Duration(hours: 8)); // ended 1 hour ago

      final shift = ShiftModel(
        shiftId: 'completed_shift_1',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: startTime,
        endTime: endTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.completed));
      expect(shift.isCompleted, isTrue);
      expect(shift.isActive, isFalse);
      expect(shift.isUpcoming, isFalse);
    });

    test('5. Cancelled shift is always CANCELLED regardless of current time', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 1));
      final endTime = now.add(const Duration(hours: 7));

      final shift = ShiftModel(
        shiftId: 'cancelled_shift_1',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: startTime,
        endTime: endTime,
        status: 'CANCELLED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.cancelled));
      expect(shift.isCancelled, isTrue);
      expect(shift.isActive, isFalse);
    });

    test('6. Midnight-crossing shift (overnight: 10:00 PM to 6:00 AM next day)', () {
      final baseDate = DateTime(2026, 9, 25);
      final startTime = DateTime(2026, 9, 25, 22, 0); // 10:00 PM
      final endTime = DateTime(2026, 9, 26, 6, 0);   // 06:00 AM next day

      final shift = ShiftModel(
        shiftId: 'overnight_shift',
        guardId: testGuardUid,
        guardName: 'Guard One',
        shiftDate: baseDate,
        startTime: startTime,
        endTime: endTime,
        durationHours: 8,
        status: 'ASSIGNED',
      );

      expect(shift.endTime.difference(shift.startTime).inHours, equals(8));
      expect(shift.endTime.day, equals(26));
      expect(shift.startTime.day, equals(25));
    });

    test('7. ShiftModel parses various date/time formats robustly', () {
      final refDate = DateTime(2026, 9, 26, 10, 0);
      final refEnd = DateTime(2026, 9, 26, 18, 0);

      // ISO 8601 Strings
      final fromIso = ShiftModel.fromMap({
        'shiftId': 'iso_1',
        'guardId': testGuardUid,
        'guardName': 'Guard One',
        'shiftDate': '2026-09-26T00:00:00.000Z',
        'startTime': '2026-09-26T10:00:00.000',
        'endTime': '2026-09-26T18:00:00.000',
        'status': 'ASSIGNED',
      }, 'iso_1');
      expect(fromIso.startTime.hour, equals(10));
      expect(fromIso.endTime.hour, equals(18));

      // Milliseconds Epoch Int
      final fromEpoch = ShiftModel.fromMap({
        'shiftId': 'epoch_1',
        'guardId': testGuardUid,
        'guardName': 'Guard One',
        'shiftDate': refDate.millisecondsSinceEpoch,
        'startTime': refDate.millisecondsSinceEpoch,
        'endTime': refEnd.millisecondsSinceEpoch,
        'status': 'ASSIGNED',
      }, 'epoch_1');
      expect(fromEpoch.startTime.millisecondsSinceEpoch, equals(refDate.millisecondsSinceEpoch));
      expect(fromEpoch.endTime.millisecondsSinceEpoch, equals(refEnd.millisecondsSinceEpoch));

      // Firestore Timestamp
      final fromTimestamp = ShiftModel.fromMap({
        'shiftId': 'ts_1',
        'guardId': testGuardUid,
        'guardName': 'Guard One',
        'shiftDate': Timestamp.fromDate(refDate),
        'startTime': Timestamp.fromDate(refDate),
        'endTime': Timestamp.fromDate(refEnd),
        'status': 'ASSIGNED',
      }, 'ts_1');
      expect(fromTimestamp.startTime.year, equals(2026));
      expect(fromTimestamp.startTime.month, equals(9));
      expect(fromTimestamp.startTime.day, equals(26));
    });

    test('8. Missing / null fields fallback safely without throwing format exception', () {
      final safeShift = ShiftModel.fromMap({
        'guardId': testGuardUid,
        // No startTime, endTime, or shiftDate in map
      }, 'empty_doc');

      expect(safeShift.shiftId, equals('empty_doc'));
      expect(safeShift.guardId, equals(testGuardUid));
      expect(safeShift.durationHours, equals(8));
      expect(safeShift.status, equals('ASSIGNED'));
    });
  });
}
