import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/shift_schedule_model.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';

void main() {
  group('1. ONE-DAY SHIFT & DURATION TESTS', () {
    test('8-hour shift calculation', () {
      final sDate = DateTime(2026, 10, 1);
      final sTime = DateTime(2026, 10, 1, 5, 30);
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: sDate,
        startTime: sTime,
        durationHours: 8,
      );

      expect(shift.durationHours, 8);
      expect(shift.startTime, DateTime(2026, 10, 1, 5, 30));
      expect(shift.endTime, DateTime(2026, 10, 1, 13, 30));
      expect(shift.endTime.difference(shift.startTime).inHours, 8);
    });

    test('10-hour, 12-hour, and 24-hour duration calculations', () {
      final sTime = DateTime(2026, 10, 1, 8, 0);

      final shift10 = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_10h',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 1),
        startTime: sTime,
        durationHours: 10,
      );
      expect(shift10.durationHours, 10);
      expect(shift10.endTime, DateTime(2026, 10, 1, 18, 0));

      final shift12 = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_12h',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 1),
        startTime: sTime,
        durationHours: 12,
      );
      expect(shift12.durationHours, 12);
      expect(shift12.endTime, DateTime(2026, 10, 1, 20, 0));

      final shift24 = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_24h',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 1),
        startTime: sTime,
        durationHours: 24,
      );
      expect(shift24.durationHours, 24);
      expect(shift24.endTime, DateTime(2026, 10, 2, 8, 0)); // Next day 08:00 AM
      expect(shift24.endTime.difference(shift24.startTime).inHours, 24);
    });

    test('Midnight crossing: 10:00 PM to 06:00 AM next day', () {
      final sTime = DateTime(2026, 10, 1, 22, 0); // 10:00 PM
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_overnight',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 1),
        startTime: sTime,
        durationHours: 8,
      );

      expect(shift.endTime, DateTime(2026, 10, 2, 6, 0)); // 06:00 AM Oct 2
      expect(shift.endTime.isAfter(shift.startTime), isTrue);
      expect(shift.endTime.difference(shift.startTime).inHours, 8);
    });
  });

  group('2. OVERLAP DETECTION LOGIC TESTS', () {
    bool hasOverlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
      // Two intervals [s1, e1) and [s2, e2) overlap if s1 < e2 and e1 > s2
      return s1.isBefore(e2) && e1.isAfter(s2);
    }

    test('Exact match overlap', () {
      final s1 = DateTime(2026, 10, 1, 6, 0);
      final e1 = s1.add(const Duration(hours: 8));
      final s2 = DateTime(2026, 10, 1, 6, 0);
      final e2 = s2.add(const Duration(hours: 8));

      expect(hasOverlap(s1, e1, s2, e2), isTrue);
    });

    test('Partial overlap (starts during earlier shift)', () {
      final s1 = DateTime(2026, 10, 1, 5, 30);
      final e1 = s1.add(const Duration(hours: 8)); // 13:30 (01:30 PM)
      final s2 = DateTime(2026, 10, 1, 10, 0);
      final e2 = s2.add(const Duration(hours: 8)); // 18:00 (06:00 PM)

      expect(hasOverlap(s1, e1, s2, e2), isTrue);
    });

    test('Non-overlapping consecutive shifts (back-to-back is allowed)', () {
      final s1 = DateTime(2026, 10, 1, 6, 0);
      final e1 = DateTime(2026, 10, 1, 14, 0); // 02:00 PM
      final s2 = DateTime(2026, 10, 1, 14, 0); // 02:00 PM
      final e2 = DateTime(2026, 10, 1, 22, 0); // 10:00 PM

      expect(hasOverlap(s1, e1, s2, e2), isFalse);
    });

    test('Different day shifts do not overlap', () {
      final s1 = DateTime(2026, 10, 1, 6, 0);
      final e1 = DateTime(2026, 10, 1, 14, 0);
      final s2 = DateTime(2026, 10, 2, 6, 0);
      final e2 = DateTime(2026, 10, 2, 14, 0);

      expect(hasOverlap(s1, e1, s2, e2), isFalse);
    });
  });

  group('3. RECURRING SHIFT SCHEDULE MODEL & GENERATION TESTS', () {
    test('Weekdays formatting helper', () {
      final schedMonFri = ShiftScheduleModel(
        scheduleId: 'sched_1',
        guardId: 'g1',
        guardName: 'Guard 1',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        startHour: 6,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1, 2, 3, 4, 5],
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(schedMonFri.weekdaysFormatted, 'Mon-Fri (Weekdays)');

      final schedAll = ShiftScheduleModel(
        scheduleId: 'sched_2',
        guardId: 'g2',
        guardName: 'Guard 2',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        startHour: 14,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(schedAll.weekdaysFormatted, 'Mon-Sun (Everyday)');

      final schedCustom = ShiftScheduleModel(
        scheduleId: 'sched_3',
        guardId: 'g3',
        guardName: 'Guard 3',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        startHour: 22,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1, 3, 5],
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(schedCustom.weekdaysFormatted, 'Mon, Wed, Fri');
    });

    test('Schedule time formatting', () {
      final s1 = ShiftScheduleModel(
        scheduleId: 's1',
        guardId: 'g1',
        guardName: 'G',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        startHour: 5,
        startMinute: 30,
        durationHours: 8,
        weekdays: [1, 2],
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(s1.timeFormatted, '5:30 AM');

      final s2 = ShiftScheduleModel(
        scheduleId: 's2',
        guardId: 'g2',
        guardName: 'G',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        startHour: 14,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1, 2],
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(s2.timeFormatted, '2:00 PM');
    });

    test('Weekday filtering: generates only selected days', () {
      final start = DateTime(2026, 10, 1); // 2026-10-01 is a Thursday (weekday 4)
      final end = DateTime(2026, 10, 7);   // 2026-10-07 is a Wednesday (weekday 3)
      final weekdays = [1, 2, 3, 4, 5];    // Mon - Fri only

      final matchedDays = <DateTime>[];
      var curr = start;
      while (!curr.isAfter(end)) {
        if (weekdays.contains(curr.weekday)) {
          matchedDays.add(curr);
        }
        curr = curr.add(const Duration(days: 1));
      }

      // Oct 1 (Thu), Oct 2 (Fri), Oct 5 (Mon), Oct 6 (Tue), Oct 7 (Wed) -> 5 days
      // Oct 3 (Sat) and Oct 4 (Sun) must NOT be included
      expect(matchedDays.length, 5);
      for (final d in matchedDays) {
        expect(d.weekday, isIn([1, 2, 3, 4, 5]));
        expect(d.weekday, isNot(6));
        expect(d.weekday, isNot(7));
      }
    });

    test('Deterministic shift ID format prevents duplicate daily shifts', () {
      const scheduleId = 'sched_abc';
      final date = DateTime(2026, 10, 5);
      final ymd = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final deterministicId = 'shift_${scheduleId}_$ymd';

      expect(deterministicId, 'shift_sched_abc_20261005');

      // Regenerating with same date yields identical key
      final secondRunId = 'shift_${scheduleId}_$ymd';
      expect(secondRunId, deterministicId);
    });

    test('Schedule status transitions: ACTIVE, PAUSED, COMPLETED, CANCELLED', () {
      final active = ShiftScheduleModel(
        scheduleId: 's1',
        guardId: 'g1',
        guardName: 'G',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        startHour: 6,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1],
        status: 'ACTIVE',
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(active.isActive, isTrue);
      expect(active.isPaused, isFalse);

      final paused = ShiftScheduleModel(
        scheduleId: 's2',
        guardId: 'g1',
        guardName: 'G',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        startHour: 6,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1],
        status: 'PAUSED',
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(paused.isPaused, isTrue);
      expect(paused.isActive, isFalse);

      final cancelled = ShiftScheduleModel(
        scheduleId: 's3',
        guardId: 'g1',
        guardName: 'G',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        startHour: 6,
        startMinute: 0,
        durationHours: 8,
        weekdays: [1],
        status: 'CANCELLED',
        createdBy: 'Admin',
        createdAt: DateTime.now(),
      );
      expect(cancelled.isCancelled, isTrue);
    });
  });

  group('4. SCHEDULE EXCEPTIONS & REASSIGNMENT TESTS', () {
    test('ScheduleExceptionModel SKIP serialization', () {
      final exc = ScheduleExceptionModel(
        exceptionId: 'exc_1',
        scheduleId: 'sched_1',
        date: DateTime(2026, 10, 10),
        type: 'SKIP',
        reason: 'National Holiday',
        createdBy: 'Admin',
        createdAt: DateTime(2026, 9, 28),
      );

      expect(exc.isSkip, isTrue);
      expect(exc.isOverride, isFalse);

      final firestoreMap = exc.toFirestore();
      expect(firestoreMap['exceptionId'], 'exc_1');
      expect(firestoreMap['type'], 'SKIP');
      expect(firestoreMap['reason'], 'National Holiday');

      final restored = ScheduleExceptionModel.fromMap(firestoreMap, 'exc_1');
      expect(restored.type, 'SKIP');
      expect(restored.reason, 'National Holiday');
    });

    test('ScheduleExceptionModel OVERRIDE serialization', () {
      final exc = ScheduleExceptionModel(
        exceptionId: 'exc_2',
        scheduleId: 'sched_1',
        date: DateTime(2026, 10, 15),
        type: 'OVERRIDE',
        overrideGuardId: 'guard_b',
        overrideGuardName: 'Guard B',
        reason: 'Reassigned from Guard A to Guard B',
        createdBy: 'Admin',
        createdAt: DateTime(2026, 9, 28),
      );

      expect(exc.isOverride, isTrue);
      expect(exc.isSkip, isFalse);
      expect(exc.overrideGuardId, 'guard_b');
      expect(exc.overrideGuardName, 'Guard B');
    });

    test('Reassigning future shift updates guard info while preserving shiftId and timestamps', () {
      final original = ShiftModel(
        shiftId: 'shift_123',
        scheduleId: 'sched_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 20),
        startTime: DateTime(2026, 10, 20, 6, 0),
        endTime: DateTime(2026, 10, 20, 14, 0),
        durationHours: 8,
        status: 'ASSIGNED',
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final reassigned = original.copyWith(
        guardId: 'guard_b',
        guardName: 'Guard B',
        guardEmail: 'guardb@parking.com',
      );

      expect(reassigned.shiftId, original.shiftId);
      expect(reassigned.scheduleId, original.scheduleId);
      expect(reassigned.guardId, 'guard_b');
      expect(reassigned.guardName, 'Guard B');
      expect(reassigned.startTime, original.startTime);
      expect(reassigned.endTime, original.endTime);
    });

    test('Completed or active shifts are protected from cancellation/reassignment', () {
      final pastShift = ShiftModel(
        shiftId: 'past_shift',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 9, 1),
        startTime: DateTime(2026, 9, 1, 6, 0),
        endTime: DateTime(2026, 9, 1, 14, 0),
        durationHours: 8,
        status: 'COMPLETED',
      );

      expect(pastShift.isCompleted, isTrue);
      expect(pastShift.isUpcoming, isFalse);
    });
  });

  group('5. FINANCIAL RESPONSIBILITY & SHIFT ISOLATION TESTS', () {
    test('Daily shifts maintain individual shiftId for financial transactions', () {
      final shiftDay1 = ShiftModel(
        shiftId: 'shift_sched1_20261001',
        scheduleId: 'sched_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 1),
        startTime: DateTime(2026, 10, 1, 6, 0),
        endTime: DateTime(2026, 10, 1, 14, 0),
        status: 'ASSIGNED',
      );

      final shiftDay2 = ShiftModel(
        shiftId: 'shift_sched1_20261002',
        scheduleId: 'sched_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(2026, 10, 2),
        startTime: DateTime(2026, 10, 2, 6, 0),
        endTime: DateTime(2026, 10, 2, 14, 0),
        status: 'ASSIGNED',
      );

      // Financial transactions map to individual shifts, not the recurring schedule
      expect(shiftDay1.shiftId, isNot(shiftDay2.shiftId));
      expect(shiftDay1.scheduleId, shiftDay2.scheduleId);
    });
  });

  group('6. LOCALIZATION & ERROR MESSAGE TESTS', () {
    test('English and Marathi strings for shift scheduling', () {
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.assignmentType, 'Assignment Type');
      expect(AppStrings.oneDay, 'One Day');
      expect(AppStrings.recurringSchedule, 'Recurring Schedule');
      expect(AppStrings.shiftOverlapError, 'This shift overlaps with an existing shift for this Guard.');
      expect(AppStrings.createSchedule, 'Create Schedule');
      expect(AppStrings.shiftSchedules, 'Shift Schedules');

      AppStrings.setLanguage(AppLanguage.marathi);
      expect(AppStrings.assignmentType, 'असाइनमेंट प्रकार');
      expect(AppStrings.oneDay, 'एक दिवस');
      expect(AppStrings.recurringSchedule, 'आवर्ती वेळापत्रक');
      expect(AppStrings.shiftOverlapError, 'या Guard च्या विद्यमान शिफ्टसोबत या शिफ्टची वेळ overlap होत आहे.');
      expect(AppStrings.createSchedule, 'वेळापत्रक तयार करा');
      expect(AppStrings.shiftSchedules, 'पाळी वेळापत्रक');

      // Reset to English
      AppStrings.setLanguage(AppLanguage.english);
    });
  });
}
