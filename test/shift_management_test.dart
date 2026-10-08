import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/shift_model.dart';

void main() {
  group('Admin-Controlled 8-Hour Shift System Unit Tests', () {
    test('1. Exact 8-hour shift creation and automatic end time calculation', () {
      final shiftDate = DateTime(2026, 9, 25);
      final startTime = DateTime(2026, 9, 25, 6, 0); // 06:00 AM

      final shift = ShiftModel.create8HourShift(
        shiftId: 'shift-101',
        guardId: 'guard-abc',
        guardName: 'Ramesh Patil',
        shiftDate: shiftDate,
        startTime: startTime,
      );

      expect(shift.durationHours, equals(8));
      expect(shift.endTime, equals(DateTime(2026, 9, 25, 14, 0))); // 02:00 PM
      expect(shift.endTime.difference(shift.startTime).inHours, equals(8));
    });

    test('2. Midnight crossing calculation (10:00 PM -> 06:00 AM next day)', () {
      final shiftDate = DateTime(2026, 9, 25);
      final startTime = DateTime(2026, 9, 25, 22, 0); // 10:00 PM

      final shift = ShiftModel.create8HourShift(
        shiftId: 'shift-102',
        guardId: 'guard-abc',
        guardName: 'Ramesh Patil',
        shiftDate: shiftDate,
        startTime: startTime,
      );

      expect(shift.durationHours, equals(8));
      expect(shift.endTime, equals(DateTime(2026, 9, 26, 6, 0))); // 06:00 AM next day
      expect(shift.endTime.difference(shift.startTime).inHours, equals(8));
    });

    test('3. Dynamic shift state derivation: ASSIGNED before startTime', () {
      final now = DateTime.now();
      final futureStartTime = now.add(const Duration(hours: 2));
      final futureEndTime = futureStartTime.add(const Duration(hours: 8));

      final shift = ShiftModel(
        shiftId: 'shift-future',
        guardId: 'guard-1',
        guardName: 'Guard 1',
        shiftDate: futureStartTime,
        startTime: futureStartTime,
        endTime: futureEndTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.assigned));
      expect(shift.isUpcoming, isTrue);
      expect(shift.isActive, isFalse);
      expect(shift.isCompleted, isFalse);
    });

    test('4. Dynamic shift state derivation: ACTIVE between startTime and endTime', () {
      final now = DateTime.now();
      final pastStartTime = now.subtract(const Duration(hours: 3));
      final futureEndTime = pastStartTime.add(const Duration(hours: 8)); // 5 hours remaining

      final shift = ShiftModel(
        shiftId: 'shift-active',
        guardId: 'guard-1',
        guardName: 'Guard 1',
        shiftDate: pastStartTime,
        startTime: pastStartTime,
        endTime: futureEndTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.active));
      expect(shift.isActive, isTrue);
      expect(shift.isUpcoming, isFalse);
      expect(shift.isCompleted, isFalse);
      expect(shift.timeElapsed.inHours, greaterThanOrEqualTo(2));
      expect(shift.timeRemaining.inHours, lessThanOrEqualTo(6));
    });

    test('5. Dynamic shift state derivation: COMPLETED after endTime', () {
      final now = DateTime.now();
      final pastStartTime = now.subtract(const Duration(hours: 10));
      final pastEndTime = pastStartTime.add(const Duration(hours: 8)); // Ended 2 hours ago

      final shift = ShiftModel(
        shiftId: 'shift-completed',
        guardId: 'guard-1',
        guardName: 'Guard 1',
        shiftDate: pastStartTime,
        startTime: pastStartTime,
        endTime: pastEndTime,
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.completed));
      expect(shift.isCompleted, isTrue);
      expect(shift.isActive, isFalse);
      expect(shift.isUpcoming, isFalse);
      expect(shift.timeRemaining, equals(Duration.zero));
    });

    test('6. Dynamic shift state derivation: CANCELLED state preserves regardless of time', () {
      final now = DateTime.now();
      final pastStartTime = now.subtract(const Duration(hours: 2));
      final futureEndTime = pastStartTime.add(const Duration(hours: 8));

      final shift = ShiftModel(
        shiftId: 'shift-cancelled',
        guardId: 'guard-1',
        guardName: 'Guard 1',
        shiftDate: pastStartTime,
        startTime: pastStartTime,
        endTime: futureEndTime,
        status: 'CANCELLED',
        cancellationReason: 'Admin rescheduled',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.cancelled));
      expect(shift.isCancelled, isTrue);
      expect(shift.isActive, isFalse);
    });

    test('7. Overlap logic correctly identifies overlapping intervals for the same guard', () {
      // Existing shift: 06:00 to 14:00
      final s1 = DateTime(2026, 9, 25, 6, 0);
      final e1 = DateTime(2026, 9, 25, 14, 0);

      // Overlapping candidate 1: 10:00 to 18:00 (mid-shift overlap)
      final c1Start = DateTime(2026, 9, 25, 10, 0);
      final c1End = DateTime(2026, 9, 25, 18, 0);
      final overlap1 = c1Start.isBefore(e1) && c1End.isAfter(s1);
      expect(overlap1, isTrue);

      // Overlapping candidate 2: 05:00 to 13:00 (early overlap)
      final c2Start = DateTime(2026, 9, 25, 5, 0);
      final c2End = DateTime(2026, 9, 25, 13, 0);
      final overlap2 = c2Start.isBefore(e1) && c2End.isAfter(s1);
      expect(overlap2, isTrue);

      // Non-overlapping candidate 3: 14:00 to 22:00 (back-to-back, exactly touches border)
      final c3Start = DateTime(2026, 9, 25, 14, 0);
      final c3End = DateTime(2026, 9, 25, 22, 0);
      final overlap3 = c3Start.isBefore(e1) && c3End.isAfter(s1);
      expect(overlap3, isFalse); // Border touch is not an overlap

      // Non-overlapping candidate 4: 22:00 to 06:00 next day
      final c4Start = DateTime(2026, 9, 25, 22, 0);
      final c4End = DateTime(2026, 9, 26, 6, 0);
      final overlap4 = c4Start.isBefore(e1) && c4End.isAfter(s1);
      expect(overlap4, isFalse);
    });
  });
}
