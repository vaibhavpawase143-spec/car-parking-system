import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/shift_model.dart';

void main() {
  group('Admin Guard Management — Authoritative Shift Display Consistency Tests', () {
    test('1. ShiftModel.effectiveStatus & isActive correctly report false for ended/expired shifts', () {
      final now = DateTime.now();
      // Shift from 4 hours ago to 2 hours ago (ended in past)
      final expiredShift = ShiftModel(
        shiftId: 'shift_expired_1',
        guardId: 'guard_a',
        guardName: 'Guard A',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.subtract(const Duration(hours: 2)),
        status: 'ACTIVE', // raw Firestore string status might be 'ACTIVE' before cron runs
      );

      expect(expiredShift.isActive, isFalse, reason: 'Expired shift past endTime must have isActive == false');
      expect(expiredShift.effectiveStatus, ShiftStatus.completed);
      expect(expiredShift.isCompleted, isTrue);
    });

    test('2. ShiftModel.effectiveStatus & isActive correctly report true for currently ongoing shift', () {
      final now = DateTime.now();
      // Shift from 1 hour ago to 3 hours in future
      final ongoingShift = ShiftModel(
        shiftId: 'shift_ongoing_1',
        guardId: 'guard_b',
        guardName: 'Guard B',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 3)),
        status: 'ACTIVE',
      );

      expect(ongoingShift.isActive, isTrue);
      expect(ongoingShift.effectiveStatus, ShiftStatus.active);
      expect(ongoingShift.isCompleted, isFalse);
    });

    test('3. AppStrings.noShift returns localized "No Active Shift"', () {
      expect(AppStrings.noShift, 'No Active Shift');
    });

    test('4. Guard with expired shift (past end time) resolves activeShift as null', () {
      final now = DateTime.now();

      final expiredShift = ShiftModel(
        shiftId: 'shift_a_expired',
        guardId: 'guard_a_uid',
        guardUid: 'guard_a_uid',
        guardName: 'Guard A',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.subtract(const Duration(hours: 1)),
        status: 'ACTIVE',
      );

      // We verify the pure state resolution logic used in Guard Management
      final guardShifts = [expiredShift];
      ShiftModel? activeShift;
      for (final s in guardShifts) {
        if (s.isCancelled) continue;
        if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
        if (s.isActive) {
          activeShift = s;
          break;
        }
      }

      expect(activeShift, isNull, reason: 'Expired shift must not be resolved as active shift');
    });

    test('5. Guard with NO shift (Guard B & Guard C) resolves activeShift as null and displays "No Active Shift"', () {
      final List<ShiftModel> guardShifts = [];
      ShiftModel? activeShift;
      for (final s in guardShifts) {
        if (s.isCancelled) continue;
        if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
        if (s.isActive) {
          activeShift = s;
          break;
        }
      }

      ShiftModel? eligibleAssignedShift;
      if (activeShift == null) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowEnd = todayStart.add(const Duration(days: 2));
        for (final s in guardShifts) {
          final sStatus = s.status.toUpperCase().trim();
          if ((sStatus == 'ASSIGNED' || s.effectiveStatus == ShiftStatus.assigned) &&
              s.actualStartTime == null &&
              sStatus != 'COMPLETED' &&
              sStatus != 'CANCELLED' &&
              !s.isCancelled &&
              s.isUpcoming) {
            if (s.startTime.isBefore(tomorrowEnd)) {
              eligibleAssignedShift = s;
              break;
            }
          }
        }
      }

      expect(activeShift, isNull);
      expect(eligibleAssignedShift, isNull);

      final displayText = activeShift != null
          ? '${AppStrings.currentShift}: ${activeShift.durationHours}-Hour (${activeShift.startTime} - ${activeShift.endTime})'
          : (eligibleAssignedShift != null
              ? 'Scheduled: ${eligibleAssignedShift.durationHours}-Hour (${eligibleAssignedShift.startTime} - ${eligibleAssignedShift.endTime})'
              : AppStrings.noShift);

      expect(displayText, 'No Active Shift');
      expect(displayText, isNot(contains('Shift 1')));
    });

    test('6. Guard with active shift correctly renders Active Shift and End Shift button eligibility', () {
      final now = DateTime.now();
      final activeShiftModel = ShiftModel(
        shiftId: 'shift_b_active',
        guardId: 'guard_b_uid',
        guardUid: 'guard_b_uid',
        guardName: 'Guard B',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 7)),
        durationHours: 8,
        status: 'ACTIVE',
      );

      final List<ShiftModel> guardShifts = [activeShiftModel];
      ShiftModel? activeShift;
      for (final s in guardShifts) {
        if (s.isCancelled) continue;
        if (s.isCompleted || s.status.toUpperCase() == 'COMPLETED' || s.actualEndTime != null) continue;
        if (s.isActive) {
          activeShift = s;
          break;
        }
      }

      expect(activeShift, isNotNull);
      expect(activeShift!.shiftId, 'shift_b_active');
      expect(activeShift.isActive, isTrue);
    });
  });
}
