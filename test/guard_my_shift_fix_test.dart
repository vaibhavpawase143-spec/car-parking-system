import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/shift_service.dart';

void main() {
  group('Guard My Shift & Shift Matching Unit Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final guardA = GuardModel(
      uid: 'guard_abc_123',
      name: 'Ramesh Patil',
      email: 'ramesh@parking.com',
      mobile: '9876543210',
      role: 'guard',
      isActive: true,
      currentShift: 'Shift 1',
    );

    final guardB = GuardModel(
      uid: 'guard_xyz_789',
      name: 'Suresh Kumar',
      email: 'suresh@parking.com',
      mobile: '9876543211',
      role: 'guard',
      isActive: true,
      currentShift: 'Shift 2',
    );

    test('1. Shift matches Guard by exact guardUid', () {
      final shift = ShiftModel(
        shiftId: 'shift_1',
        guardId: 'guard_abc_123',
        guardUid: 'guard_abc_123',
        guardName: 'Ramesh Patil',
        guardEmail: 'ramesh@parking.com',
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 7)),
        status: 'ASSIGNED',
      );

      expect(ShiftService.matchesGuard(shift, guardA.uid, guardA.email, guardA.name), isTrue);
      expect(ShiftService.matchesGuard(shift, guardB.uid, guardB.email, guardB.name), isFalse);
    });

    test('2. Shift matches Guard by guardEmail case-insensitively', () {
      final shift = ShiftModel(
        shiftId: 'shift_2',
        guardId: 'legacy_doc_id_999',
        guardName: 'Ramesh Patil',
        guardEmail: 'RAMESH@PARKING.COM',
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ACTIVE',
      );

      expect(ShiftService.matchesGuard(shift, guardA.uid, guardA.email, guardA.name), isTrue);
      expect(ShiftService.matchesGuard(shift, guardB.uid, guardB.email, guardB.name), isFalse);
    });

    test('3. Shift matches Guard by guardName fallback', () {
      final shift = ShiftModel(
        shiftId: 'shift_3',
        guardId: 'doc_id_only',
        guardName: 'Ramesh Patil',
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 5)),
        status: 'ASSIGNED',
      );

      expect(ShiftService.matchesGuard(shift, guardA.uid, guardA.email, guardA.name), isTrue);
      expect(ShiftService.matchesGuard(shift, guardB.uid, guardB.email, guardB.name), isFalse);
    });

    test('4. Active shift detection: time within [startTime, endTime] is evaluated as active', () {
      final activeShift = ShiftModel(
        shiftId: 'shift_active',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ASSIGNED',
      );

      expect(activeShift.isActive, isTrue);
      expect(activeShift.isUpcoming, isFalse);
      expect(activeShift.isCompleted, isFalse);
      expect(activeShift.isCancelled, isFalse);
    });

    test('5. Upcoming shift detection: time before startTime is evaluated as upcoming', () {
      final upcomingShift = ShiftModel(
        shiftId: 'shift_upcoming',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: today,
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 10)),
        status: 'ASSIGNED',
      );

      expect(upcomingShift.isUpcoming, isTrue);
      expect(upcomingShift.isActive, isFalse);
      expect(upcomingShift.isCompleted, isFalse);
      expect(upcomingShift.isCancelled, isFalse);
    });

    test('6. Completed shift detection: time after endTime or explicit COMPLETED status', () {
      final completedByTime = ShiftModel(
        shiftId: 'shift_completed_1',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: today.subtract(const Duration(days: 1)),
        startTime: now.subtract(const Duration(hours: 20)),
        endTime: now.subtract(const Duration(hours: 12)),
        status: 'ASSIGNED',
      );

      expect(completedByTime.isCompleted, isTrue);
      expect(completedByTime.isActive, isFalse);
      expect(completedByTime.isUpcoming, isFalse);

      final completedByStatus = ShiftModel(
        shiftId: 'shift_completed_2',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'COMPLETED',
      );

      expect(completedByStatus.isCompleted, isTrue);
      expect(completedByStatus.isActive, isFalse);
    });

    test('7. Cancelled shift is excluded from active, upcoming, and completed flows', () {
      final cancelledShift = ShiftModel(
        shiftId: 'shift_cancelled',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 7)),
        status: 'CANCELLED',
      );

      expect(cancelledShift.isCancelled, isTrue);
      expect(cancelledShift.isActive, isFalse);
      expect(cancelledShift.isUpcoming, isFalse);
      expect(cancelledShift.isCompleted, isFalse);
    });

    test('8. Guard shift history filtering isolates completed shifts belonging to target guard', () {
      final allShifts = [
        // Guard A completed
        ShiftModel(
          shiftId: 's1',
          guardId: guardA.uid,
          guardName: guardA.name,
          shiftDate: today.subtract(const Duration(days: 2)),
          startTime: now.subtract(const Duration(days: 2, hours: 8)),
          endTime: now.subtract(const Duration(days: 2)),
          status: 'COMPLETED',
        ),
        // Guard A active
        ShiftModel(
          shiftId: 's2',
          guardId: guardA.uid,
          guardName: guardA.name,
          shiftDate: today,
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 6)),
          status: 'ACTIVE',
        ),
        // Guard B completed (must not appear in Guard A history)
        ShiftModel(
          shiftId: 's3',
          guardId: guardB.uid,
          guardName: guardB.name,
          shiftDate: today.subtract(const Duration(days: 1)),
          startTime: now.subtract(const Duration(days: 1, hours: 8)),
          endTime: now.subtract(const Duration(days: 1)),
          status: 'COMPLETED',
        ),
      ];

      final guardAShifts = allShifts.where((s) => ShiftService.matchesGuard(s, guardA.uid, guardA.email, guardA.name)).toList();
      final guardACompleted = guardAShifts.where((s) => s.isCompleted).toList();
      final guardAActive = guardAShifts.where((s) => s.isActive).toList();

      expect(guardAShifts.length, 2);
      expect(guardACompleted.length, 1);
      expect(guardACompleted.first.shiftId, 's1');
      expect(guardAActive.length, 1);
      expect(guardAActive.first.shiftId, 's2');
    });
  });
}
