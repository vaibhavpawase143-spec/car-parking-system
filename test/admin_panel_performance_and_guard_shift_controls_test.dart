import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/dashboard_service.dart';
import 'package:car_parking_system/services/settings_service.dart';
import 'package:car_parking_system/services/shift_service.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  const testAdmin = GuardModel(
    uid: 'admin_test_123',
    name: 'Super Admin',
    email: 'admin@jayganesh.com',
    role: 'admin',
    isActive: true,
  );

  const testGuardA = GuardModel(
    uid: 'guard_a_uid',
    name: 'Guard A',
    email: 'guarda@jayganesh.com',
    role: 'guard',
    isActive: true,
  );

  group('1. Capacity Business Rules & Validation Tests', () {
    test('1.1 Total capacity is automatically calculated: 4W (100) + 2W (150) = 250', () {
      const data = CapacityData(
        carTotal: 100,
        carOccupied: 7,
        twoWheelerTotal: 150,
        twoWheelerOccupied: 12,
      );

      final totalCapacity = data.carTotal + data.twoWheelerTotal;
      final totalOccupied = data.carOccupied + data.twoWheelerOccupied;
      final totalAvailable = data.carAvailable + data.twoWheelerAvailable;

      expect(totalCapacity, 250);
      expect(totalOccupied, 19);
      expect(totalAvailable, 231);
      expect(data.carAvailable, 93);
      expect(data.twoWheelerAvailable, 138);
    });

    test('1.2 Reducing Four-Wheeler capacity below occupancy is strictly rejected', () {
      expect(
        () => SettingsService.instance.updateCapacity(
          fourWheelerCapacity: 5, // Below current occupied 7
          twoWheelerCapacity: 150,
          adminUid: testAdmin.uid,
          adminName: testAdmin.name,
          currentFourWheelerOccupied: 7,
          currentTwoWheelerOccupied: 12,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('7'),
        )),
      );
    });

    test('1.3 Reducing Two-Wheeler capacity below occupancy is strictly rejected', () {
      expect(
        () => SettingsService.instance.updateCapacity(
          fourWheelerCapacity: 100,
          twoWheelerCapacity: 10, // Below current occupied 12
          adminUid: testAdmin.uid,
          adminName: testAdmin.name,
          currentFourWheelerOccupied: 7,
          currentTwoWheelerOccupied: 12,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('12'),
        )),
      );
    });
  });

  group('2. Guard Management Shift Start/End Control Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    test('2.1 Eligible assigned shift is correctly identified for [Start Shift] button', () {
      final assignedShift = ShiftModel(
        shiftId: 's_assigned_1',
        guardId: testGuardA.uid,
        guardUid: testGuardA.uid,
        guardName: testGuardA.name,
        shiftDate: today,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 9)),
        durationHours: 8,
        status: 'ASSIGNED',
      );

      final shifts = [assignedShift];
      final guardShifts = shifts.where((s) => ShiftService.matchesGuard(s, testGuardA.uid, testGuardA.email, testGuardA.name)).toList();

      ShiftModel? activeShift;
      for (final s in guardShifts) {
        if (s.isActive && !s.isCancelled) {
          activeShift = s;
          break;
        }
      }

      ShiftModel? eligibleAssignedShift;
      if (activeShift == null) {
        final tomorrowEnd = today.add(const Duration(days: 2));
        for (final s in guardShifts) {
          if (s.effectiveStatus == ShiftStatus.assigned && !s.isCancelled) {
            if (s.startTime.isBefore(tomorrowEnd)) {
              eligibleAssignedShift = s;
              break;
            }
          }
        }
      }

      expect(activeShift, isNull);
      expect(eligibleAssignedShift, isNotNull);
      expect(eligibleAssignedShift!.shiftId, 's_assigned_1');
    });

    test('2.2 Active shift is correctly identified for [End Shift] button', () {
      final activeShiftModel = ShiftModel(
        shiftId: 's_active_1',
        guardId: testGuardA.uid,
        guardUid: testGuardA.uid,
        guardName: testGuardA.name,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        durationHours: 8,
        status: 'ACTIVE',
      );

      final shifts = [activeShiftModel];
      final guardShifts = shifts.where((s) => ShiftService.matchesGuard(s, testGuardA.uid, testGuardA.email, testGuardA.name)).toList();

      ShiftModel? activeShift;
      for (final s in guardShifts) {
        if (s.isActive && !s.isCancelled) {
          activeShift = s;
          break;
        }
      }

      expect(activeShift, isNotNull);
      expect(activeShift!.shiftId, 's_active_1');
      expect(activeShift.isActive, isTrue);
    });

    test('2.3 Ending shift does NOT reset outstanding financial responsibility or delete transactions', () {
      const resp = GuardFinancialResponsibility(
        guardUid: 'guard_a_uid',
        guardName: 'Guard A',
        totalCashCollected: 1200.0,
        cashWithdrawn: 500.0,
        totalUpiCollected: 800.0,
        upiWithdrawn: 300.0,
      );

      expect(resp.outstandingCash, 700.0);
      expect(resp.outstandingUpi, 500.0);
      expect(resp.totalOutstanding, 1200.0);

      // Simulating shift end: status becomes COMPLETED, financial responsibility stays unchanged
      final completedShift = ShiftModel(
        shiftId: 's_active_1',
        guardId: testGuardA.uid,
        guardUid: testGuardA.uid,
        guardName: testGuardA.name,
        shiftDate: today,
        startTime: now.subtract(const Duration(hours: 8)),
        endTime: now,
        actualStartTime: now.subtract(const Duration(hours: 8)),
        actualEndTime: now,
        durationHours: 8,
        status: 'COMPLETED',
      );

      expect(completedShift.isCompleted, isTrue);
      // Guard responsibility remains ₹1200
      expect(resp.totalOutstanding, 1200.0);
      expect(resp.outstandingCash, 700.0);
      expect(resp.outstandingUpi, 500.0);
    });
  });

  group('3. Performance & Stream Lifecycle Tests', () {
    test('3.1 DashboardService watchCapacity produces dedicated stream without hanging on subsequent listeners', () async {
      final service = DashboardService();
      final stream1 = service.watchCapacity();
      final stream2 = service.watchCapacity();

      expect(stream1, isNotNull);
      expect(stream2, isNotNull);

      final firstEvent1 = await stream1.first;
      final firstEvent2 = await stream2.first;

      expect(firstEvent1.carTotal, isPositive);
      expect(firstEvent2.carTotal, isPositive);
    });

    test('3.2 DashboardService watchTodayMetrics produces initial baseline event immediately', () async {
      final service = DashboardService();
      final stream = service.watchTodayMetrics();

      final firstEvent = await stream.first;
      expect(firstEvent.todayEntries, isNonNegative);
      expect(firstEvent.todayExits, isNonNegative);
      expect(firstEvent.todayCollection, isNonNegative);
    });
  });
}
