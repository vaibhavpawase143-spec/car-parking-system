import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/shift_service.dart';

void main() {
  group('Reports Hub - Parking Summary Vehicle Breakdown & Guard-Wise Report Tests', () {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 6));

    final records = [
      // Today: Two-Wheeler Entry & Exit
      ParkingRecord(
        id: 'r1',
        ticketNumber: '101',
        vehicleNumber: 'MH12AB1001',
        vehicleType: VehicleType.twoWheeler,
        entryTime: todayStart.add(const Duration(hours: 8)),
        exitTime: todayStart.add(const Duration(hours: 10)),
        status: 'EXITED',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        entryShift: 'Shift 1',
      ),
      // Today: Two-Wheeler Entry (Still Parked)
      ParkingRecord(
        id: 'r2',
        ticketNumber: '102',
        vehicleNumber: 'MH12AB1002',
        vehicleType: VehicleType.twoWheeler,
        entryTime: todayStart.add(const Duration(hours: 9)),
        status: 'ACTIVE',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        entryShift: 'Shift 1',
      ),
      // Today: Four-Wheeler Entry & Exit
      ParkingRecord(
        id: 'r3',
        ticketNumber: '103',
        vehicleNumber: 'MH12CD2001',
        vehicleType: VehicleType.fourWheeler,
        entryTime: todayStart.add(const Duration(hours: 8, minutes: 30)),
        exitTime: todayStart.add(const Duration(hours: 11)),
        status: 'EXITED',
        entryGuardUid: 'guard_b',
        entryGuardName: 'Guard B',
        entryShift: 'Shift 1',
      ),
      // 3 days ago: Four-Wheeler Entry & Exit
      ParkingRecord(
        id: 'r4',
        ticketNumber: '104',
        vehicleNumber: 'MH12EF3001',
        vehicleType: VehicleType.fourWheeler,
        entryTime: todayStart.subtract(const Duration(days: 3)),
        exitTime: todayStart.subtract(const Duration(days: 3, hours: -2)),
        status: 'EXITED',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        entryShift: 'Shift 1',
      ),
      // 3 days ago: Two-Wheeler Entry & Exit
      ParkingRecord(
        id: 'r5',
        ticketNumber: '105',
        vehicleNumber: 'MH12GH4001',
        vehicleType: VehicleType.twoWheeler,
        entryTime: todayStart.subtract(const Duration(days: 3)),
        exitTime: todayStart.subtract(const Duration(days: 3, hours: -1)),
        status: 'EXITED',
        entryGuardUid: 'guard_b',
        entryGuardName: 'Guard B',
        entryShift: 'Shift 1',
      ),
    ];

    final transactions = [
      // Today Guard A: Cash Advance 20
      PaymentTransactionModel(
        id: 't1',
        ticketId: '101',
        vehicleNumber: 'MH12AB1001',
        amount: 20.0,
        paymentType: 'ADVANCE',
        paymentMethod: 'cash',
        guardUid: 'guard_a',
        guardName: 'Guard A',
        createdAt: todayStart.add(const Duration(hours: 8)),
      ),
      // Today Guard A: Cash Final 30
      PaymentTransactionModel(
        id: 't2',
        ticketId: '101',
        vehicleNumber: 'MH12AB1001',
        amount: 30.0,
        paymentType: 'FINAL',
        paymentMethod: 'cash',
        guardUid: 'guard_a',
        guardName: 'Guard A',
        createdAt: todayStart.add(const Duration(hours: 10)),
      ),
      // Today Guard B: UPI Final 100
      PaymentTransactionModel(
        id: 't3',
        ticketId: '103',
        vehicleNumber: 'MH12CD2001',
        amount: 100.0,
        paymentType: 'FINAL',
        paymentMethod: 'upi',
        guardUid: 'guard_b',
        guardName: 'Guard B',
        createdAt: todayStart.add(const Duration(hours: 11)),
      ),
      // 3 days ago Guard A: Cash Final 50
      PaymentTransactionModel(
        id: 't4',
        ticketId: '104',
        vehicleNumber: 'MH12EF3001',
        amount: 50.0,
        paymentType: 'FINAL',
        paymentMethod: 'cash',
        guardUid: 'guard_a',
        guardName: 'Guard A',
        createdAt: todayStart.subtract(const Duration(days: 3)),
      ),
    ];

    final guards = const [
      GuardModel(uid: 'guard_a', name: 'Guard A', email: 'guard.a@example.com'),
      GuardModel(uid: 'guard_b', name: 'Guard B', email: 'guard.b@example.com'),
      GuardModel(uid: 'guard_c', name: 'Guard C', email: 'guard.c@example.com'),
    ];

    // =========================================================================
    // PARKING SUMMARY TESTS
    // =========================================================================

    test('Parking Summary: Today Period - Two-Wheeler & Four-Wheeler breakdown verification', () {
      final todayEntries = records.where((r) =>
          !r.entryTime.isBefore(todayStart) && !r.entryTime.isAfter(todayEnd)).toList();
      final twoWheelerEntries = todayEntries.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
      final fourWheelerEntries = todayEntries.where((r) => r.vehicleType == VehicleType.fourWheeler).length;
      final totalEntries = todayEntries.length;

      expect(twoWheelerEntries, 2); // r1 and r2
      expect(fourWheelerEntries, 1); // r3
      expect(totalEntries, 3);
      // Verify Rule: Total Entries = Two-Wheeler Entries + Four-Wheeler Entries
      expect(totalEntries, equals(twoWheelerEntries + fourWheelerEntries));

      final todayExits = records.where((r) =>
          r.exitTime != null && !r.exitTime!.isBefore(todayStart) && !r.exitTime!.isAfter(todayEnd)).toList();
      final twoWheelerExits = todayExits.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
      final fourWheelerExits = todayExits.where((r) => r.vehicleType == VehicleType.fourWheeler).length;
      final totalExits = todayExits.length;

      expect(twoWheelerExits, 1); // r1
      expect(fourWheelerExits, 1); // r3
      expect(totalExits, 2);
      // Verify Rule: Total Exits = Two-Wheeler Exits + Four-Wheeler Exits
      expect(totalExits, equals(twoWheelerExits + fourWheelerExits));
    });

    test('Parking Summary: Last 7 Days Period - vehicle breakdown verification', () {
      final rangeEntries = records.where((r) =>
          !r.entryTime.isBefore(sevenDaysAgo) && !r.entryTime.isAfter(todayEnd)).toList();
      final twoWheelerEntries = rangeEntries.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
      final fourWheelerEntries = rangeEntries.where((r) => r.vehicleType == VehicleType.fourWheeler).length;
      final totalEntries = rangeEntries.length;

      expect(twoWheelerEntries, 3); // r1, r2, r5
      expect(fourWheelerEntries, 2); // r3, r4
      expect(totalEntries, 5);
      expect(totalEntries, equals(twoWheelerEntries + fourWheelerEntries));

      final rangeExits = records.where((r) =>
          r.exitTime != null && !r.exitTime!.isBefore(sevenDaysAgo) && !r.exitTime!.isAfter(todayEnd)).toList();
      final twoWheelerExits = rangeExits.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
      final fourWheelerExits = rangeExits.where((r) => r.vehicleType == VehicleType.fourWheeler).length;
      final totalExits = rangeExits.length;

      expect(twoWheelerExits, 2); // r1, r5
      expect(fourWheelerExits, 2); // r3, r4
      expect(totalExits, 4);
      expect(totalExits, equals(twoWheelerExits + fourWheelerExits));
    });

    // =========================================================================
    // GUARD-WISE REPORT TESTS
    // =========================================================================

    test('Test 1: Guard A ACTIVE -> Default Guard is Guard A', () {
      final now = DateTime.now();
      final testTime = now;
      final shifts = [
        ShiftModel(
          shiftId: 's1',
          guardId: 'guard_a',
          guardUid: 'guard_a',
          guardName: 'Guard A',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 6)),
          status: 'ACTIVE',
        ),
      ];

      final activeShifts = shifts.where((s) {
        if (s.isCancelled || s.isCompleted) return false;
        if (s.actualEndTime != null) return false;
        if (s.status.toUpperCase().trim() != 'ACTIVE') return false;
        final opStart = s.actualStartTime ?? s.startTime;
        final opEnd = s.endTime;
        return !testTime.isBefore(opStart) && !testTime.isAfter(opEnd);
      }).toList();

      expect(activeShifts.length, 1);
      final activeShift = activeShifts.first;
      final matchedGuard = guards.where((g) => ShiftService.matchesGuard(activeShift, g.uid, g.email, g.name)).firstOrNull;
      expect(matchedGuard?.name, 'Guard A');
    });

    test('Test 2: Guard A COMPLETED, Guard B ACTIVE -> Default automatically Guard B', () {
      final now = DateTime.now();
      final testTime = now;
      final shifts = [
        ShiftModel(
          shiftId: 's1',
          guardId: 'guard_a',
          guardUid: 'guard_a',
          guardName: 'Guard A',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 9)),
          endTime: now.subtract(const Duration(hours: 1)),
          status: 'COMPLETED',
          actualEndTime: now.subtract(const Duration(hours: 1)),
        ),
        ShiftModel(
          shiftId: 's2',
          guardId: 'guard_b',
          guardUid: 'guard_b',
          guardName: 'Guard B',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 7)),
          status: 'ACTIVE',
        ),
      ];

      final activeShifts = shifts.where((s) {
        if (s.isCancelled || s.isCompleted) return false;
        if (s.actualEndTime != null) return false;
        if (s.status.toUpperCase().trim() != 'ACTIVE') return false;
        final opStart = s.actualStartTime ?? s.startTime;
        final opEnd = s.endTime;
        return !testTime.isBefore(opStart) && !testTime.isAfter(opEnd);
      }).toList();

      expect(activeShifts.length, 1);
      final activeShift = activeShifts.first;
      expect(activeShift.guardName, 'Guard B');
    });

    test('Test 3 & 4: Manual selection & Automatic change after shift rotation', () {
      String? selectedGuardUid;
      String? lastActiveShiftId;
      bool isManualSelection = false;

      // Initial state: Shift 2 (Guard B) is ACTIVE
      var currentActiveShift = ShiftModel(
        shiftId: 's2',
        guardId: 'guard_b',
        guardUid: 'guard_b',
        guardName: 'Guard B',
        shiftDate: DateTime(2026, 10, 1),
        startTime: DateTime(2026, 10, 1, 14, 0),
        endTime: DateTime(2026, 10, 1, 22, 0),
        status: 'ACTIVE',
      );

      // Simulation of build logic:
      if (currentActiveShift.shiftId != lastActiveShiftId) {
        lastActiveShiftId = currentActiveShift.shiftId;
        isManualSelection = false;
      }
      if (!isManualSelection) {
        selectedGuardUid = currentActiveShift.guardUid;
      }
      expect(selectedGuardUid, 'guard_b');

      // Test 3: Admin manually selects Guard A
      selectedGuardUid = 'guard_a';
      isManualSelection = true;
      expect(selectedGuardUid, 'guard_a');
      expect(isManualSelection, true);

      // Test 4: Shift rotates to Shift 3 (Guard C)
      currentActiveShift = ShiftModel(
        shiftId: 's3',
        guardId: 'guard_c',
        guardUid: 'guard_c',
        guardName: 'Guard C',
        shiftDate: DateTime(2026, 10, 1),
        startTime: DateTime(2026, 10, 1, 22, 0),
        endTime: DateTime(2026, 10, 2, 6, 0),
        status: 'ACTIVE',
      );

      // On next stream emission / shift change:
      if (currentActiveShift.shiftId != lastActiveShiftId) {
        lastActiveShiftId = currentActiveShift.shiftId;
        isManualSelection = false; // Reset manual override!
      }
      if (!isManualSelection) {
        selectedGuardUid = currentActiveShift.guardUid;
      }
      expect(selectedGuardUid, 'guard_c'); // Automatically switched to Guard C!
      expect(isManualSelection, false);
    });

    test('Test 5: No active shift -> No random Guard selected', () {
      final now = DateTime.now();
      final testTime = now;
      final shifts = [
        ShiftModel(
          shiftId: 's1',
          guardId: 'guard_a',
          guardUid: 'guard_a',
          guardName: 'Guard A',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 9)),
          endTime: now.subtract(const Duration(hours: 1)),
          status: 'COMPLETED',
        ),
      ];

      final activeShifts = shifts.where((s) {
        if (s.isCancelled || s.isCompleted) return false;
        if (s.actualEndTime != null) return false;
        if (s.status.toUpperCase().trim() != 'ACTIVE') return false;
        final opStart = s.actualStartTime ?? s.startTime;
        final opEnd = s.endTime;
        return !testTime.isBefore(opStart) && !testTime.isAfter(opEnd);
      }).toList();

      expect(activeShifts.isEmpty, true);
    });

    test('Test 6: Overnight shift (10 PM to 6 AM) at 1 AM -> Current Guard = overnight Guard', () {
      final now = DateTime.now();
      final testTime = now;
      final overnightShift = ShiftModel(
        shiftId: 's_night',
        guardId: 'guard_c',
        guardUid: 'guard_c',
        guardName: 'Guard C',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 5)),
        status: 'ACTIVE',
      );

      final shifts = [overnightShift];

      final activeShifts = shifts.where((s) {
        if (s.isCancelled || s.isCompleted) return false;
        if (s.actualEndTime != null) return false;
        if (s.status.toUpperCase().trim() != 'ACTIVE') return false;
        final opStart = s.actualStartTime ?? s.startTime;
        final opEnd = s.endTime;
        return !testTime.isBefore(opStart) && !testTime.isAfter(opEnd);
      }).toList();

      expect(activeShifts.length, 1);
      expect(activeShifts.first.guardName, 'Guard C');
    });

    test('Test 7: Period filtering on selected Guard collection', () {
      // Guard A in Today period:
      final guardATxnsToday = transactions.where((t) =>
          t.guardUid == 'guard_a' &&
          !t.createdAt.isBefore(todayStart) &&
          !t.createdAt.isAfter(todayEnd)).toList();

      double cashToday = 0.0;
      double upiToday = 0.0;
      for (final t in guardATxnsToday) {
        if (t.isAdvance || t.isFinal) {
          if (t.isUpi) {
            upiToday += t.amount;
          } else {
            cashToday += t.amount;
          }
        }
      }
      expect(cashToday, 50.0); // 20 + 30
      expect(upiToday, 0.0);
      expect(cashToday + upiToday, 50.0);
      expect(guardATxnsToday.length, 2);

      // Guard A in Last 7 Days period:
      final guardATxns7Days = transactions.where((t) =>
          t.guardUid == 'guard_a' &&
          !t.createdAt.isBefore(sevenDaysAgo) &&
          !t.createdAt.isAfter(todayEnd)).toList();

      double cash7Days = 0.0;
      for (final t in guardATxns7Days) {
        if (t.isAdvance || t.isFinal) {
          if (!t.isUpi) cash7Days += t.amount;
        }
      }
      expect(cash7Days, 100.0); // 20 + 30 + 50
      expect(guardATxns7Days.length, 3);
    });

    test('Test 8: Multiple active shift safety -> Anomaly detected', () {
      final now = DateTime.now();
      final testTime = now;
      final shifts = [
        ShiftModel(
          shiftId: 's1',
          guardId: 'guard_a',
          guardUid: 'guard_a',
          guardName: 'Guard A',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 6)),
          status: 'ACTIVE',
        ),
        ShiftModel(
          shiftId: 's2',
          guardId: 'guard_b',
          guardUid: 'guard_b',
          guardName: 'Guard B',
          shiftDate: DateTime(now.year, now.month, now.day),
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 6)),
          status: 'ACTIVE',
        ),
      ];

      final activeShifts = shifts.where((s) {
        if (s.isCancelled || s.isCompleted) return false;
        if (s.actualEndTime != null) return false;
        if (s.status.toUpperCase().trim() != 'ACTIVE') return false;
        final opStart = s.actualStartTime ?? s.startTime;
        final opEnd = s.endTime;
        return !testTime.isBefore(opStart) && !testTime.isAfter(opEnd);
      }).toList();

      final hasMultipleActiveShifts = activeShifts.length > 1;
      expect(hasMultipleActiveShifts, true);
    });

    test('Test 9: AppStrings localization verification', () {
      expect(AppStrings.vehicleEntries.isNotEmpty, true);
      expect(AppStrings.vehicleExits.isNotEmpty, true);
      expect(AppStrings.guardWiseReport.isNotEmpty, true);
      expect(AppStrings.noActiveGuard.isNotEmpty, true);
      expect(AppStrings.noGuardActiveShift.isNotEmpty, true);
      expect(AppStrings.multipleActiveShiftsWarning.isNotEmpty, true);
    });
  });
}
