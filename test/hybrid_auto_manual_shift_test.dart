import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/shift_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HYBRID AUTOMATIC + MANUAL SHIFT MANAGEMENT — Comprehensive Test Suite', () {
    final now = DateTime(2026, 9, 30, 14, 0, 0); // 02:00 PM

    final guardA = GuardModel(
      uid: 'guard_a',
      name: 'Guard A',
      email: 'guarda@parking.com',
      role: 'guard',
      currentShift: 'Shift 1',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final guardB = GuardModel(
      uid: 'guard_b',
      name: 'Guard B',
      email: 'guardb@parking.com',
      role: 'guard',
      currentShift: 'Shift 2',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final guardC = GuardModel(
      uid: 'guard_c',
      name: 'Guard C',
      email: 'guardc@parking.com',
      role: 'guard',
      currentShift: 'Shift 3',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final inactiveGuard = GuardModel(
      uid: 'guard_inactive',
      name: 'Guard Inactive',
      email: 'inactive@parking.com',
      role: 'guard',
      currentShift: '',
      isActive: false,
      createdAt: DateTime(2026, 1, 1),
    );

    test('1. Shift Scheduling & Duration calculation (8h, 9h, 10h, and Overnight)', () {
      final baseDate = DateTime(2026, 9, 30);

      // 8-Hour Shift
      final shift8h = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_8h',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: baseDate,
        startTime: DateTime(2026, 9, 30, 6, 0), // 06:00 AM
        durationHours: 8,
      );
      expect(shift8h.endTime, DateTime(2026, 9, 30, 14, 0)); // 02:00 PM
      expect(shift8h.durationHours, 8);

      // 9-Hour Shift
      final shift9h = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_9h',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: baseDate,
        startTime: DateTime(2026, 9, 30, 9, 0),
        durationHours: 9,
      );
      expect(shift9h.endTime, DateTime(2026, 9, 30, 18, 0));
      expect(shift9h.durationHours, 9);

      // 10-Hour Shift
      final shift10h = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_10h',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: baseDate,
        startTime: DateTime(2026, 9, 30, 4, 40),
        durationHours: 10,
      );
      expect(shift10h.endTime, DateTime(2026, 9, 30, 14, 40));
      expect(shift10h.durationHours, 10);

      // Overnight Shift (10:00 PM -> 06:00 AM next day)
      final shiftOvernight = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_overnight',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: baseDate,
        startTime: DateTime(2026, 9, 30, 22, 0), // 10:00 PM
        durationHours: 8,
      );
      expect(shiftOvernight.endTime, DateTime(2026, 10, 1, 6, 0)); // 06:00 AM next day
      expect(shiftOvernight.endTime.difference(shiftOvernight.startTime).inHours, 8);
    });

    test('2. Next Eligible Shift Logic - Earliest valid upcoming ASSIGNED shift selected', () {
      final shiftA = ShiftModel(
        shiftId: 'shift_a',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 6, 0),
        endTime: DateTime(2026, 9, 30, 14, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 6, 0),
        startedBy: 'SYSTEM',
      );

      final shiftB = ShiftModel(
        shiftId: 'shift_b',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 14, 0), // 02:00 PM
        endTime: DateTime(2026, 9, 30, 22, 0),
        status: 'ASSIGNED',
      );

      final shiftC = ShiftModel(
        shiftId: 'shift_c',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 22, 0), // 10:00 PM
        endTime: DateTime(2026, 10, 1, 6, 0),
        status: 'ASSIGNED',
      );

      final allShifts = [shiftC, shiftA, shiftB];
      final allGuards = [guardA, guardB, guardC];

      final next = ShiftService.findNextEligibleShift(allShifts, allGuards, now: now);
      expect(next, isNotNull);
      expect(next!.shiftId, 'shift_b');
      expect(next.guardId, 'guard_b');
      expect(next.guardName, 'Guard B');
    });

    test('3. Next Eligible Shift excludes Inactive Guards', () {
      final shiftInactive = ShiftModel(
        shiftId: 'shift_inact',
        guardId: inactiveGuard.uid,
        guardName: inactiveGuard.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 14, 0),
        endTime: DateTime(2026, 9, 30, 22, 0),
        status: 'ASSIGNED',
      );

      final shiftC = ShiftModel(
        shiftId: 'shift_c',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 22, 0),
        endTime: DateTime(2026, 10, 1, 6, 0),
        status: 'ASSIGNED',
      );

      final allShifts = [shiftInactive, shiftC];
      final allGuards = [inactiveGuard, guardC];

      final next = ShiftService.findNextEligibleShift(allShifts, allGuards, now: now);
      expect(next, isNotNull);
      // Inactive guard shift must NOT be chosen
      expect(next!.shiftId, 'shift_c');
      expect(next.guardId, 'guard_c');
    });

    test('4. Next Eligible Shift excludes Guards with an already active shift', () {
      final activeShiftB = ShiftModel(
        shiftId: 'shift_b_active',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 10, 0),
        endTime: DateTime(2026, 9, 30, 18, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 10, 0),
      );

      final assignedShiftB = ShiftModel(
        shiftId: 'shift_b_assigned',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 18, 0),
        endTime: DateTime(2026, 10, 1, 2, 0),
        status: 'ASSIGNED',
      );

      final assignedShiftC = ShiftModel(
        shiftId: 'shift_c',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 19, 0),
        endTime: DateTime(2026, 10, 1, 3, 0),
        status: 'ASSIGNED',
      );

      final allShifts = [activeShiftB, assignedShiftB, assignedShiftC];
      final allGuards = [guardB, guardC];

      final next = ShiftService.findNextEligibleShift(allShifts, allGuards, now: now);
      expect(next, isNotNull);
      // Even though shift_b_assigned is earlier (18:00 vs 19:00), Guard B is already active!
      expect(next!.shiftId, 'shift_c');
      expect(next.guardId, 'guard_c');
    });

    test('5. Automatic vs Manual Shift Lifecycle tracking', () {
      final autoStartShift = ShiftModel(
        shiftId: 'shift_auto',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 6, 0),
        endTime: DateTime(2026, 9, 30, 14, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 6, 0),
        startedBy: 'SYSTEM',
      );

      expect(autoStartShift.startedBy, 'SYSTEM');

      final autoEndShift = autoStartShift.copyWith(
        status: 'COMPLETED',
        actualEndTime: DateTime(2026, 9, 30, 14, 0),
        endedBy: 'SYSTEM',
      );

      expect(autoEndShift.status, 'COMPLETED');
      expect(autoEndShift.endedBy, 'SYSTEM');
      expect(autoEndShift.isCompleted, isTrue);

      final manualStartShift = ShiftModel(
        shiftId: 'shift_manual',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 14, 0),
        endTime: DateTime(2026, 9, 30, 22, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 14, 0),
        startedBy: 'admin_uid_123',
      );

      expect(manualStartShift.startedBy, 'admin_uid_123');

      final manualEndShift = manualStartShift.copyWith(
        status: 'COMPLETED',
        actualEndTime: DateTime(2026, 9, 30, 22, 0),
        endedBy: 'admin_uid_123',
      );

      expect(manualEndShift.endedBy, 'admin_uid_123');
      expect(manualEndShift.isCompleted, isTrue);
    });

    test('6. Button Visibility Logic for 3-Guard Shift Scenario', () {
      // Guard A (06:00 - 14:00) -> ACTIVE
      final shiftA = ShiftModel(
        shiftId: 'shift_a',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 6, 0),
        endTime: DateTime(2026, 9, 30, 14, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 6, 0),
        startedBy: 'SYSTEM',
      );

      // Guard B (14:00 - 22:00) -> ASSIGNED (Next Eligible)
      final shiftB = ShiftModel(
        shiftId: 'shift_b',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 14, 0),
        endTime: DateTime(2026, 9, 30, 22, 0),
        status: 'ASSIGNED',
      );

      // Guard C (22:00 - 06:00) -> ASSIGNED (Later Shift)
      final shiftC = ShiftModel(
        shiftId: 'shift_c',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 22, 0),
        endTime: DateTime(2026, 10, 1, 6, 0),
        status: 'ASSIGNED',
      );

      final allShifts = [shiftA, shiftB, shiftC];
      final allGuards = [guardA, guardB, guardC];

      final nextEligible = ShiftService.findNextEligibleShift(allShifts, allGuards, now: now);

      // Guard A: ACTIVE -> Must show [ End Shift ], NOT [ Start Shift ]
      final guardAHasActive = shiftA.status == 'ACTIVE';
      expect(guardAHasActive, isTrue);

      // Guard B: ASSIGNED & is Next Eligible -> Must show [ Start Shift ]
      final isGuardBNext = nextEligible?.shiftId == shiftB.shiftId;
      expect(isGuardBNext, isTrue);

      // Guard C: ASSIGNED but NOT Next Eligible -> Must NOT show [ Start Shift ] on card
      final isGuardCNext = nextEligible?.shiftId == shiftC.shiftId;
      expect(isGuardCNext, isFalse);
    });

    test('7. Shift Rotation Transition: Guard A ends -> Guard B becomes Active -> Guard C becomes Next', () {
      final shiftACompleted = ShiftModel(
        shiftId: 'shift_a',
        guardId: guardA.uid,
        guardName: guardA.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 6, 0),
        endTime: DateTime(2026, 9, 30, 14, 0),
        status: 'COMPLETED',
        actualEndTime: DateTime(2026, 9, 30, 14, 0),
        endedBy: 'SYSTEM',
      );

      // Guard B automatically becomes ACTIVE at 02:00 PM
      final shiftBActive = ShiftModel(
        shiftId: 'shift_b',
        guardId: guardB.uid,
        guardName: guardB.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 14, 0),
        endTime: DateTime(2026, 9, 30, 22, 0),
        status: 'ACTIVE',
        actualStartTime: DateTime(2026, 9, 30, 14, 0),
        startedBy: 'SYSTEM',
      );

      // Guard C is ASSIGNED for 10:00 PM
      final shiftCAssigned = ShiftModel(
        shiftId: 'shift_c',
        guardId: guardC.uid,
        guardName: guardC.name,
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 22, 0),
        endTime: DateTime(2026, 10, 1, 6, 0),
        status: 'ASSIGNED',
      );

      final allShifts = [shiftACompleted, shiftBActive, shiftCAssigned];
      final allGuards = [guardA, guardB, guardC];

      final nextEligible = ShiftService.findNextEligibleShift(allShifts, allGuards, now: now);

      // Guard B is now ACTIVE, so next eligible shift must automatically rotate to Guard C!
      expect(nextEligible, isNotNull);
      expect(nextEligible!.shiftId, 'shift_c');
      expect(nextEligible.guardId, 'guard_c');
      expect(nextEligible.guardName, 'Guard C');
    });

    test('8. Guard matching supports UID, email, and display name', () {
      final testShift = ShiftModel(
        shiftId: 'shift_test',
        guardId: 'guard_123',
        guardUid: 'guard_uid_456',
        guardEmail: 'guard@example.com',
        guardName: 'Ramesh Guard',
        shiftDate: DateTime(2026, 9, 30),
        startTime: DateTime(2026, 9, 30, 8, 0),
        endTime: DateTime(2026, 9, 30, 16, 0),
      );

      expect(ShiftService.matchesGuard(testShift, 'guard_123'), isTrue);
      expect(ShiftService.matchesGuard(testShift, 'guard_uid_456'), isTrue);
      expect(ShiftService.matchesGuard(testShift, '', 'guard@example.com'), isTrue);
      expect(ShiftService.matchesGuard(testShift, '', '', 'Ramesh Guard'), isTrue);
      expect(ShiftService.matchesGuard(testShift, 'other_guard'), isFalse);
    });
  });
}
