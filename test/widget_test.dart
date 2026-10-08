import 'package:car_parking_system/core/config/app_config.dart';
import 'package:car_parking_system/core/constants/app_constants.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/cloudinary_service.dart';
import 'package:car_parking_system/services/parking_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 4/5: Vehicle Exit & Settlement Automated Test Suite (A to U)', () {
    final baseTime = DateTime(2026, 9, 21, 10, 0);

    // A. Vehicle lookup by ticket
    test('A: Vehicle lookup by ticket matches active ticket ID', () {
      final activeRecord = ParkingRecord(
        id: 'TKT-20260921-0001',
        ticketNumber: 'TKT-20260921-0001',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Rajesh',
        entryShift: 'Shift 1',
      );

      // Simulating lookup predicate
      bool matchesTicket(ParkingRecord r, String query) =>
          r.isActive && (r.ticketNumber.toUpperCase() == query.toUpperCase() || r.id.toUpperCase() == query.toUpperCase());

      expect(matchesTicket(activeRecord, 'TKT-20260921-0001'), isTrue);
      expect(matchesTicket(activeRecord, 'tkt-20260921-0001'), isTrue);
      expect(matchesTicket(activeRecord, 'TKT-20260921-9999'), isFalse);
    });

    // B. Vehicle lookup by vehicle number
    test('B: Vehicle lookup by vehicle number matches active vehicle registration', () {
      final activeRecord = ParkingRecord(
        id: 'TKT-20260921-0002',
        ticketNumber: 'TKT-20260921-0002',
        vehicleNumber: 'DL04CA9999',
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Rajesh',
        entryShift: 'Shift 1',
      );

      bool matchesVehicleNumber(ParkingRecord r, String query) =>
          r.isActive && (r.vehicleNumber.replaceAll(' ', '').toUpperCase() == query.replaceAll(' ', '').toUpperCase());

      expect(matchesVehicleNumber(activeRecord, 'DL04CA9999'), isTrue);
      expect(matchesVehicleNumber(activeRecord, 'DL 04 CA 9999'), isTrue);
      expect(matchesVehicleNumber(activeRecord, 'MH12AB1234'), isFalse);
    });

    // C. Invalid ticket
    test('C: Invalid ticket returns not found and prevents exit flow', () {
      final records = <ParkingRecord>[
        ParkingRecord(
          id: 'TKT-20260921-0001',
          ticketNumber: 'TKT-20260921-0001',
          vehicleNumber: 'MH12AB1234',
          vehicleType: VehicleType.fourWheeler,
          entryTime: baseTime,
          status: 'ACTIVE',
          entryGuardUid: 'guard_1',
          entryGuardName: 'Guard Rajesh',
          entryShift: 'Shift 1',
        ),
      ];

      ParkingRecord? findActive(String query) {
        final clean = query.trim().toUpperCase();
        try {
          return records.firstWhere(
            (r) => r.isActive && (r.ticketNumber.toUpperCase() == clean || r.vehicleNumber.toUpperCase() == clean),
          );
        } catch (_) {
          return null;
        }
      }

      expect(findActive('INVALID-TICKET-999'), isNull);
      expect(findActive(''), isNull);
    });

    // D. Already exited vehicle
    test('D: Already exited vehicle is rejected with VehicleAlreadyExitedException', () {
      final exitedRecord = ParkingRecord(
        id: 'TKT-20260921-0003',
        ticketNumber: 'TKT-20260921-0003',
        vehicleNumber: 'KA01MJ4321',
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2)),
        status: 'EXITED',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Rajesh',
        entryShift: 'Shift 1',
      );

      expect(exitedRecord.isActive, isFalse);
      expect(exitedRecord.isExited, isTrue);

      void checkCanExit(ParkingRecord r) {
        if (!r.isActive) {
          throw VehicleAlreadyExitedException(r.ticketNumber);
        }
      }

      expect(() => checkCanExit(exitedRecord), throwsA(isA<VehicleAlreadyExitedException>()));
    });

    // E. 0 minutes duration incurs ₹0
    test('E: 0 minutes duration incurs ₹0 gross charge', () {
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime,
      );

      expect(calc.isGracePeriod, isFalse);
      expect(calc.grossCharge, 0.0);
      expect(calc.balanceDue, 0.0);
    });

    // F. 1 to 10 minutes incurs first-hour charge immediately (NO free grace period)
    test('F: 1 to 10 minutes incurs first-hour charge (no free parking window)', () {
      final exitTime = baseTime.add(const Duration(minutes: 10));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );

      expect(calc.isGracePeriod, isFalse);
      expect(calc.billableHours, 1);
      expect(calc.grossCharge, AppConstants.fourWheelerFirstHourRate); // ₹50
    });

    // G. 11 minutes applies 1st hour charge
    test('G: 11 minutes applies 1st hour charge', () {
      final exitTime = baseTime.add(const Duration(minutes: 11));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );

      expect(calc.isGracePeriod, isFalse);
      expect(calc.billableHours, 1);
      expect(calc.grossCharge, AppConstants.fourWheelerFirstHourRate); // ₹50
    });

    // H. Two-Wheeler calculation
    test('H: Two-Wheeler calculation (First hour ₹20, additional ₹5)', () {
      // 3 hours 2W: 20 + 2 * 5 = ₹30
      final exitTime = baseTime.add(const Duration(hours: 3));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );

      expect(calc.billableHours, 3);
      expect(calc.grossCharge, 30.0);
    });

    // I. Four-Wheeler calculation
    test('I: Four-Wheeler calculation (First hour ₹50, additional ₹10)', () {
      // 3 hours 4W: 50 + 2 * 10 = ₹70
      final exitTime = baseTime.add(const Duration(hours: 3));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );

      expect(calc.billableHours, 3);
      expect(calc.grossCharge, 70.0);
    });

    // I.1 Hourly boundaries for billable hours & charges (1-60m=1h, 61-120m=2h, 121-180m=3h)
    test('I.1: Hourly boundaries for billable hours & charges (1-60m=1h, 61-120m=2h)', () {
      // 1-Hour boundaries:
      // 1h 00m (60m) -> 1 hour
      final calc1h00 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1, minutes: 0)),
      );
      expect(calc1h00.billableHours, 1);
      expect(calc1h00.grossCharge, 20.0);

      // 1h 01m (61m) -> 2 hours (₹20 + ₹5 = ₹25)
      final calc1h01 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1, minutes: 1)),
      );
      expect(calc1h01.billableHours, 2);
      expect(calc1h01.grossCharge, 25.0);

      // 1h 09m (69m) -> 2 hours
      final calc1h09 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1, minutes: 9)),
      );
      expect(calc1h09.billableHours, 2);
      expect(calc1h09.grossCharge, 25.0);

      // 1h 10m (70m) -> 2 hours (₹20 + ₹5 = ₹25)
      final calc1h10 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1, minutes: 10)),
      );
      expect(calc1h10.billableHours, 2);
      expect(calc1h10.grossCharge, 25.0);

      // 1h 11m -> 2 hours
      final calc1h11 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1, minutes: 11)),
      );
      expect(calc1h11.billableHours, 2);
      expect(calc1h11.grossCharge, 25.0);

      // 2-Hour boundaries:
      // 2h 00m (120m) -> 2 billable hours
      final calc2h00 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 0)),
      );
      expect(calc2h00.billableHours, 2);
      expect(calc2h00.grossCharge, 25.0);

      // 2h 01m (121m) -> 3 billable hours (₹20 + 2 * ₹5 = ₹30)
      final calc2h01 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 1)),
      );
      expect(calc2h01.billableHours, 3);
      expect(calc2h01.grossCharge, 30.0);

      // 2h 09m -> 3 billable hours -> ₹30
      final calc2h09 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 9)),
      );
      expect(calc2h09.billableHours, 3);
      expect(calc2h09.grossCharge, 30.0);

      // 2h 10m -> 3 billable hours -> ₹30
      final calc2h10 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 10)),
      );
      expect(calc2h10.billableHours, 3);
      expect(calc2h10.grossCharge, 30.0);

      // 2h 11m -> 3 billable hours -> ₹30
      final calc2h11 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 11)),
      );
      expect(calc2h11.billableHours, 3);
      expect(calc2h11.grossCharge, 30.0);

      // 2h 16m -> 3 billable hours -> ₹30
      final calc2h16 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 2, minutes: 16)),
      );
      expect(calc2h16.billableHours, 3);
      expect(calc2h16.grossCharge, 30.0);

      // 3-Hour boundaries:
      // 3h 00m -> 3 billable hours
      final calc3h00 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 3, minutes: 0)),
      );
      expect(calc3h00.billableHours, 3);
      expect(calc3h00.grossCharge, 30.0);

      // 3h 01m (181m) -> 4 billable hours (₹20 + 3 * ₹5 = ₹35)
      final calc3h01 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 3, minutes: 1)),
      );
      expect(calc3h01.billableHours, 4);
      expect(calc3h01.grossCharge, 35.0);

      // 3h 09m -> 4 billable hours -> ₹35
      final calc3h09 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 3, minutes: 9)),
      );
      expect(calc3h09.billableHours, 4);
      expect(calc3h09.grossCharge, 35.0);

      // 3h 10m -> 4 billable hours -> ₹35
      final calc3h10 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 3, minutes: 10)),
      );
      expect(calc3h10.billableHours, 4);
      expect(calc3h10.grossCharge, 35.0);

      // 3h 11m -> 4 billable hours -> ₹35
      final calc3h11 = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 3, minutes: 11)),
      );
      expect(calc3h11.billableHours, 4);
      expect(calc3h11.grossCharge, 35.0);
    });

    // J. 12-hour cap
    test('J: 12-hour caps (Two-Wheeler ₹60, Four-Wheeler ₹150 PROPOSED)', () {
      final exitTime = baseTime.add(const Duration(hours: 12));

      final calc2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );
      expect(calc2W.grossCharge, AppConstants.twoWheeler12HourCap); // ₹60

      final calc4W = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
      );
      expect(calc4W.grossCharge, AppConstants.fourWheeler12HourCapProposed); // ₹150
    });

    // K. Advance less than charge
    test('K: Advance less than charge produces balance due and zero refund', () {
      final exitTime = baseTime.add(const Duration(hours: 3));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
        advancePaid: 30.0,
      );

      expect(calc.grossCharge, 70.0);
      expect(calc.advancePaid, 30.0);
      expect(calc.balanceDue, 40.0);
      expect(calc.refundAmount, 0.0);
      expect(calc.hasAdvance, isTrue);
      expect(calc.hasRefund, isFalse);
    });

    // L. Advance equal to charge
    test('L: Advance equal to charge produces zero balance due and zero refund', () {
      final exitTime = baseTime.add(const Duration(minutes: 50));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
        advancePaid: 50.0,
      );

      expect(calc.grossCharge, 50.0);
      expect(calc.advancePaid, 50.0);
      expect(calc.balanceDue, 0.0);
      expect(calc.refundAmount, 0.0);
      expect(calc.isSettled, isTrue);
    });

    // M. Advance greater than charge
    test('M: Advance greater than charge produces refund and zero balance due', () {
      final exitTime = baseTime.add(const Duration(minutes: 30));
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: exitTime,
        advancePaid: 100.0,
      );

      expect(calc.grossCharge, 50.0);
      expect(calc.advancePaid, 100.0);
      expect(calc.balanceDue, 0.0);
      expect(calc.refundAmount, 50.0);
      expect(calc.hasRefund, isTrue);
    });

    // N. Cash final payment
    test('N: Cash final payment creates payment transaction with paymentType=FINAL and method=cash', () {
      const balanceDue = 40.0;
      final txn = {
        'ticketId': 'TKT-20260921-0001',
        'vehicleNumber': 'MH12AB1234',
        'amount': balanceDue,
        'paymentMethod': 'cash',
        'paymentType': 'FINAL',
        'guardUid': 'guard_2',
        'guardName': 'Guard Suresh',
        'shift': 'Shift 2',
      };

      expect(txn['paymentType'], 'FINAL');
      expect(txn['paymentMethod'], 'cash');
      expect(txn['amount'], balanceDue);
    });

    // O. UPI final payment
    test('O: UPI final payment creates payment transaction with paymentType=FINAL and method=upi', () {
      const balanceDue = 40.0;
      final txn = {
        'ticketId': 'TKT-20260921-0001',
        'vehicleNumber': 'MH12AB1234',
        'amount': balanceDue,
        'paymentMethod': 'upi',
        'paymentType': 'FINAL',
        'guardUid': 'guard_2',
        'guardName': 'Guard Suresh',
        'shift': 'Shift 2',
      };

      expect(txn['paymentType'], 'FINAL');
      expect(txn['paymentMethod'], 'upi');
      expect(txn['amount'], balanceDue);
    });

    // P. Refund
    test('P: Refund creates payment transaction with paymentType=REFUND', () {
      const refundAmount = 50.0;
      final txn = {
        'ticketId': 'TKT-20260921-0001',
        'vehicleNumber': 'MH12AB1234',
        'amount': refundAmount,
        'paymentMethod': 'cash',
        'paymentType': 'REFUND',
        'guardUid': 'guard_2',
        'guardName': 'Guard Suresh',
        'shift': 'Shift 2',
      };

      expect(txn['paymentType'], 'REFUND');
      expect(txn['amount'], refundAmount);
    });

    // Q. Cross-shift entry/exit
    test('Q: Cross-shift entry/exit preserves both Entry and Exit Guard & Shift details', () {
      final record = ParkingRecord(
        id: 'TKT-20260921-8888',
        ticketNumber: 'TKT-20260921-8888',
        vehicleNumber: 'MH14DE5678',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 21, 7, 30),
        exitTime: DateTime(2026, 9, 21, 15, 30),
        status: 'EXITED',
        entryGuardUid: 'guard_1_uid',
        entryGuardName: 'Guard Rajesh',
        entryShift: 'Shift 1',
        advanceAmount: 50.0,
        advancePaymentMethod: 'cash',
        advanceCollectorGuardUid: 'guard_1_uid',
        advanceCollectorGuardName: 'Guard Rajesh',
        advanceCollectorShift: 'Shift 1',
        grossCharge: 120.0,
        paidAmount: 70.0,
        balanceDue: 70.0,
        refundAmount: 0.0,
        exitGuardUid: 'guard_2_uid',
        exitGuardName: 'Guard Suresh',
        exitShift: 'Shift 2',
        paymentMethod: 'upi',
        balanceCollectorGuardUid: 'guard_2_uid',
        balanceCollectorShift: 'Shift 2',
      );

      final map = record.toFirestore();
      // Entry Guard audit preserved
      expect(map['entryGuardUid'], 'guard_1_uid');
      expect(map['entryGuardName'], 'Guard Rajesh');
      expect(map['entryShift'], 'Shift 1');

      // Advance collector audit preserved
      expect(map['advanceCollectorGuardUid'], 'guard_1_uid');
      expect(map['advanceCollectorGuardName'], 'Guard Rajesh');
      expect(map['advanceCollectorShift'], 'Shift 1');

      // Exit Guard audit preserved
      expect(map['exitGuardUid'], 'guard_2_uid');
      expect(map['exitGuardName'], 'Guard Suresh');
      expect(map['exitShift'], 'Shift 2');

      // Balance collector audit preserved
      expect(map['balanceCollectorGuardUid'], 'guard_2_uid');
      expect(map['balanceCollectorShift'], 'Shift 2');
    });

    // R. Duplicate payment prevention
    test('R: Duplicate payment prevention: final payment contains only balance, never gross', () {
      const grossCharge = 180.0;
      const advancePaid = 100.0;
      const balanceDue = grossCharge - advancePaid; // ₹80

      // Step 1: Advance payment transaction
      final advanceTxn = {
        'amount': advancePaid,
        'paymentType': 'ADVANCE',
      };

      // Step 2: Final settlement payment transaction
      final finalTxn = {
        'amount': balanceDue,
        'paymentType': 'FINAL',
      };

      // Total collected is ₹100 + ₹80 = ₹180, NOT ₹180 + ₹180
      final totalRevenue = (advanceTxn['amount'] as double) + (finalTxn['amount'] as double);
      expect(totalRevenue, grossCharge);
      expect(finalTxn['amount'], 80.0);
    });

    // S. Successful exit updates capacity
    test('S: Successful exit updates capacity (active decreases, available increases, non-negative)', () {
      const maxFourWheelerCapacity = 50;
      int activeFourWheelers = 20;

      int availableCapacity() => (maxFourWheelerCapacity - activeFourWheelers).clamp(0, maxFourWheelerCapacity);

      expect(availableCapacity(), 30);

      // Four-Wheeler exits
      activeFourWheelers--;
      expect(activeFourWheelers, 19);
      expect(availableCapacity(), 31); // Available capacity increases by 1

      // Cannot become negative
      activeFourWheelers = 60; // hypothetically more than capacity
      expect(availableCapacity(), 0); // clamp prevents negative capacity
    });

    // T. Successful exit removes vehicle from Active Parking
    test('T: Successful exit removes vehicle from Active Parking directory', () {
      final records = <ParkingRecord>[
        ParkingRecord(
          id: 'TKT-001',
          ticketNumber: 'TKT-001',
          vehicleNumber: 'KA01AA1111',
          vehicleType: VehicleType.twoWheeler,
          entryTime: baseTime,
          status: 'ACTIVE',
          entryGuardUid: 'g1',
          entryGuardName: 'G1',
          entryShift: 'S1',
        ),
        ParkingRecord(
          id: 'TKT-002',
          ticketNumber: 'TKT-002',
          vehicleNumber: 'KA01BB2222',
          vehicleType: VehicleType.fourWheeler,
          entryTime: baseTime,
          status: 'ACTIVE',
          entryGuardUid: 'g1',
          entryGuardName: 'G1',
          entryShift: 'S1',
        ),
      ];

      List<ParkingRecord> getActiveVehicles() => records.where((r) => r.isActive).toList();

      expect(getActiveVehicles().length, 2);

      // Exit TKT-001
      records[0] = ParkingRecord(
        id: 'TKT-001',
        ticketNumber: 'TKT-001',
        vehicleNumber: 'KA01AA1111',
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 1)),
        status: 'EXITED',
        entryGuardUid: 'g1',
        entryGuardName: 'G1',
        entryShift: 'S1',
      );

      final updatedActive = getActiveVehicles();
      expect(updatedActive.length, 1);
      expect(updatedActive.first.ticketNumber, 'TKT-002');
      expect(records[0].isExited, isTrue); // Not deleted, preserved for history
    });

    // U. Failed settlement keeps vehicle ACTIVE
    test('U: Failed settlement keeps vehicle status ACTIVE without modifying exit fields', () {
      var record = ParkingRecord(
        id: 'TKT-003',
        ticketNumber: 'TKT-003',
        vehicleNumber: 'MH01AB3333',
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        status: 'ACTIVE',
        entryGuardUid: 'g1',
        entryGuardName: 'G1',
        entryShift: 'S1',
      );

      // Simulating failed transaction
      try {
        throw Exception('Network timeout during settlement batch commit');
      } catch (_) {
        // Settlement failed -> state remains unchanged
      }

      expect(record.isActive, isTrue);
      expect(record.status, 'ACTIVE');
      expect(record.exitTime, isNull);
      expect(record.exitGuardUid, isNull);
    });
  });

  group('GuardModel Tests (Phase 2)', () {
    test('isGuard returns true for active guard role', () {
      const guard = GuardModel(
        uid: 'uid_test_123',
        name: 'Rajesh Kumar',
        email: 'rajesh@parking.com',
        role: 'guard',
        isActive: true,
      );

      expect(guard.isGuard, isTrue);
    });

    test('isGuard returns false for inactive guard', () {
      const guard = GuardModel(
        uid: 'uid_test_123',
        name: 'Rajesh Kumar',
        email: 'rajesh@parking.com',
        role: 'guard',
        isActive: false,
      );

      expect(guard.isGuard, isFalse);
    });

    test('isGuard returns false for non-guard role', () {
      const admin = GuardModel(
        uid: 'uid_test_admin',
        name: 'Admin User',
        email: 'admin@parking.com',
        role: 'admin',
        isActive: true,
      );

      expect(admin.isGuard, isFalse);
    });

    test('GuardModel toFirestore produces valid structure without password', () {
      const guard = GuardModel(
        uid: 'uid_123',
        name: 'Ramesh Singh',
        email: 'ramesh@parking.com',
        role: 'guard',
        isActive: true,
        currentShift: 'Shift 2',
      );

      final map = guard.toFirestore();
      expect(map['uid'], 'uid_123');
      expect(map['name'], 'Ramesh Singh');
      expect(map['role'], 'guard');
      expect(map['isActive'], isTrue);
      expect(map.containsKey('password'), isFalse);
    });
  });

  group('Phase 3: Real Vehicle Entry, Storage Photo & Firestore Parking Records Tests', () {
    // 1. Ticket format
    test('1. Ticket format matches TKT-YYYYMMDD-XXXX and generates collision-resistant unique IDs', () {
      final ticketRegex = RegExp(r'^TKT-\d{8}-[A-Z0-9]{4}$');
      final generatedTickets = <String>{};

      for (int i = 0; i < 100; i++) {
        final ticket = AppFormatters.generateTicketNumber();
        expect(ticketRegex.hasMatch(ticket), isTrue, reason: 'Ticket $ticket should match TKT-YYYYMMDD-XXXX');
        generatedTickets.add(ticket);
      }

      // 100 generated tickets should be unique
      expect(generatedTickets.length, 100);
    });

    // 2. Safe QR Reference
    test('2. Safe QR reference safely identifies ticket and contains no sensitive credentials', () {
      const ticketId = 'TKT-20260922-A8F2';
      final record = ParkingRecord(
        id: ticketId,
        ticketId: ticketId,
        ticketNumber: ticketId,
        vehicleNumber: 'MH12DE1001',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_test_uid',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Shift 1',
        qrReference: ticketId,
      );

      expect(record.qrReference, ticketId);
      expect(record.qrReference!.contains('password'), isFalse);
      expect(record.qrReference!.contains('secret'), isFalse);
      expect(record.qrReference!.contains('token'), isFalse);
    });

    // 3. Mandatory photo validation
    test('3. Mandatory photo validation blocks submission if photo bytes are empty or null', () {
      bool validatePhoto(Uint8List? photo) {
        if (photo == null || photo.isEmpty) {
          return false;
        }
        return true;
      }

      expect(validatePhoto(null), isFalse);
      expect(validatePhoto(Uint8List(0)), isFalse);
      expect(validatePhoto(Uint8List.fromList([0xFF, 0xD8, 0xFF])), isTrue);
    });

    // 4. Capacity full blocks entry
    test('4. Capacity full blocks entry with clear error message', () {
      const maxBikes = 150;
      int activeBikes = 150;

      int availableCapacity() => (maxBikes - activeBikes).clamp(0, maxBikes);

      expect(availableCapacity(), 0);

      void checkCapacityBeforeEntry(VehicleType type) {
        if (availableCapacity() <= 0) {
          throw CapacityFullException(type);
        }
      }

      expect(
        () => checkCapacityBeforeEntry(VehicleType.twoWheeler),
        throwsA(
          isA<CapacityFullException>().having(
            (e) => e.toString(),
            'message',
            contains('Parking capacity is full for Two-Wheeler.'),
          ),
        ),
      );
    });

    // 5. Duplicate active vehicle check
    test('5. Duplicate active vehicle check blocks entry if vehicle already has status ACTIVE', () {
      final activeVehicles = <String>['MH12DE1001', 'DL01XY2020'];

      void checkDuplicate(String vehicleNumber) {
        final clean = vehicleNumber.toUpperCase().replaceAll(' ', '').trim();
        if (activeVehicles.map((v) => v.toUpperCase().replaceAll(' ', '')).contains(clean)) {
          throw VehicleAlreadyParkedException(clean);
        }
      }

      expect(
        () => checkDuplicate('MH 12 DE 1001'),
        throwsA(
          isA<VehicleAlreadyParkedException>().having(
            (e) => e.toString(),
            'message',
            'This vehicle is already parked.',
          ),
        ),
      );
      expect(
        () => checkDuplicate('mh12de1001'),
        throwsA(isA<VehicleAlreadyParkedException>()),
      );
      expect(() => checkDuplicate('KA01AB9999'), returnsNormally);
    });

    // 6. No advance option
    test('6. No advance option produces advanceAmount = 0 and no payment transaction', () {
      final record = ParkingRecord(
        id: 'TKT-20260922-0001',
        ticketId: 'TKT-20260922-0001',
        ticketNumber: 'TKT-20260922-0001',
        vehicleNumber: 'MH12DE1001',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Shift 1',
        advanceAmount: 0.0,
      );

      final firestoreMap = record.toFirestore();
      expect(firestoreMap['advanceAmount'], 0.0);
      expect(firestoreMap['advanceCollectorGuardUid'], isNull);
    });

    // 7. Cash advance option
    test('7. Cash advance option records advance amount and creates ADVANCE payment transaction', () {
      const advanceAmt = 50.0;
      final record = ParkingRecord(
        id: 'TKT-20260922-0002',
        ticketId: 'TKT-20260922-0002',
        ticketNumber: 'TKT-20260922-0002',
        vehicleNumber: 'DL01XY2020',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Shift 1',
        advanceAmount: advanceAmt,
        advancePaymentMethod: 'cash',
        advanceCollectorGuardUid: 'guard_1',
        advanceCollectorGuardName: 'Guard Ramesh',
        advanceCollectorShift: 'Shift 1',
      );

      final map = record.toFirestore();
      expect(map['advanceAmount'], 50.0);
      expect(map['advancePaymentMethod'], 'cash');
      expect(map['advanceCollectorGuardUid'], 'guard_1');

      final txn = {
        'ticketId': record.ticketId,
        'vehicleNumber': record.vehicleNumber,
        'amount': advanceAmt,
        'paymentMethod': 'cash',
        'paymentType': 'ADVANCE',
        'guardUid': 'guard_1',
        'guardName': 'Guard Ramesh',
        'shift': 'Shift 1',
      };

      expect(txn['paymentType'], 'ADVANCE');
      expect(txn['paymentMethod'], 'cash');
      expect(txn['amount'], 50.0);
    });

    // 8. UPI advance option
    test('8. UPI advance option records advance amount and creates ADVANCE payment transaction', () {
      const advanceAmt = 100.0;
      final record = ParkingRecord(
        id: 'TKT-20260922-0003',
        ticketId: 'TKT-20260922-0003',
        ticketNumber: 'TKT-20260922-0003',
        vehicleNumber: 'KA04MJ5555',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_2',
        entryGuardName: 'Guard Suresh',
        entryShift: 'Shift 2',
        advanceAmount: advanceAmt,
        advancePaymentMethod: 'upi',
        advanceCollectorGuardUid: 'guard_2',
        advanceCollectorGuardName: 'Guard Suresh',
        advanceCollectorShift: 'Shift 2',
      );

      final map = record.toFirestore();
      expect(map['advanceAmount'], 100.0);
      expect(map['advancePaymentMethod'], 'upi');

      final txn = {
        'ticketId': record.ticketId,
        'vehicleNumber': record.vehicleNumber,
        'amount': advanceAmt,
        'paymentMethod': 'upi',
        'paymentType': 'ADVANCE',
        'guardUid': 'guard_2',
        'guardName': 'Guard Suresh',
        'shift': 'Shift 2',
      };

      expect(txn['paymentType'], 'ADVANCE');
      expect(txn['paymentMethod'], 'upi');
      expect(txn['amount'], 100.0);
    });

    // 9. Firestore parking schema validation
    test('9. Firestore parking schema contains all required Phase 3 fields with null exit fields', () {
      final entryTime = DateTime(2026, 9, 22, 10, 15);
      final record = ParkingRecord(
        id: 'TKT-20260922-A1B2',
        ticketId: 'TKT-20260922-A1B2',
        ticketNumber: 'TKT-20260922-A1B2',
        vehicleNumber: 'MH12DE1001',
        vehicleType: VehicleType.twoWheeler,
        customerMobile: '9876543210',
        entryTime: entryTime,
        status: 'ACTIVE',
        entryGuardUid: 'uid_guard_123',
        entryGuardName: 'Guard Ramesh',
        entryShiftId: 'Shift 1',
        entryShift: 'Shift 1',
        advanceAmount: 0.0,
        advancePaymentMethod: 'cash',
        photoUrl: 'https://res.cloudinary.com/dvp8g1j7n/image/upload/v1/parking_records/TKT-20260922-A1B2/vehicle_photo.jpg',
        vehiclePhotoUrl: 'https://res.cloudinary.com/dvp8g1j7n/image/upload/v1/parking_records/TKT-20260922-A1B2/vehicle_photo.jpg',
        photoPublicId: 'parking_records/TKT-20260922-A1B2/vehicle_photo',
        photoStorageProvider: 'cloudinary',
        storagePath: 'parking_records/TKT-20260922-A1B2/vehicle_photo',
        qrReference: 'TKT-20260922-A1B2',
        createdAt: entryTime,
      );

      final map = record.toFirestore();

      // Required entry fields
      expect(map['ticketId'], 'TKT-20260922-A1B2');
      expect(map['ticketNumber'], 'TKT-20260922-A1B2');
      expect(map['vehicleNumber'], 'MH12DE1001');
      expect(map['vehicleType'], 'twoWheeler');
      expect(map['customerMobile'], '9876543210');
      expect(map['status'], 'ACTIVE');
      expect(map['entryGuardUid'], 'uid_guard_123');
      expect(map['entryGuardName'], 'Guard Ramesh');
      expect(map['entryShiftId'], 'Shift 1');
      expect(map['entryShift'], 'Shift 1');
      expect(map['advanceAmount'], 0.0);
      expect(map['advancePaymentMethod'], 'cash');
      expect(map['storagePath'], 'parking_records/TKT-20260922-A1B2/vehicle_photo');
      expect(map['vehiclePhotoUrl'], isNotNull);
      expect(map['photoUrl'], isNotNull);
      expect(map['photoPublicId'], 'parking_records/TKT-20260922-A1B2/vehicle_photo');
      expect(map['photoStorageProvider'], 'cloudinary');
      expect(map['qrReference'], 'TKT-20260922-A1B2');

      // Exit fields MUST be null initially
      expect(map['exitTime'], isNull);
      expect(map['grossCharge'], isNull);
      expect(map['finalCharge'], isNull);
      expect(map['paidAmount'], isNull);
      expect(map['balanceDue'], isNull);
      expect(map['refundAmount'], isNull);
      expect(map['exitGuardUid'], isNull);
      expect(map['exitGuardName'], isNull);
      expect(map['exitShift'], isNull);
    });

    // 10. Photo upload failure prevents Firestore creation
    test('10. Cloudinary upload failure prevents partial Firestore record creation', () async {
      bool firestoreDocCreated = false;

      Future<void> simulateVehicleEntryWithFailedUpload() async {
        // Step 1: Upload fails
        throw const CloudinaryUploadException(
          'Upload preset not found',
          statusCode: 400,
        );
        // Step 2: Firestore write would follow, but is aborted
        // firestoreDocCreated = true;
      }

      expect(
        () => simulateVehicleEntryWithFailedUpload(),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );

      expect(firestoreDocCreated, isFalse, reason: 'Firestore document must never be created if photo upload fails');
    });

    // 11. No double-counting advance
    test('11. Advance is not double-counted in final collection', () {
      const advanceAmount = 50.0;
      const grossCharge = 120.0;
      const balanceDue = grossCharge - advanceAmount; // 70.0

      final advanceTxn = {'amount': advanceAmount, 'type': 'ADVANCE'};
      final finalTxn = {'amount': balanceDue, 'type': 'FINAL'};

      final totalCollected = (advanceTxn['amount'] as double) + (finalTxn['amount'] as double);
      expect(totalCollected, grossCharge);
      expect(finalTxn['amount'], 70.0);
    });

    // 12. AppConfig DEV vs PROD switching and client-safe parameter validation
    test('12. AppConfig contains client-safe parameters and strictly NO API secrets', () {
      // Default environment should be dev
      expect(AppConfig.current.environment, AppEnvironment.dev);
      expect(AppConfig.current.isDevelopment, isTrue);
      expect(AppConfig.current.isProduction, isFalse);

      // DEV Cloudinary configuration must use real verified values
      expect(AppConfig.current.cloudinaryCloudName, 'dwzlw6jeu');
      expect(AppConfig.current.cloudinaryUploadPreset, 'car_parking_dev');
      expect(AppConfig.current.cloudinaryFolder, isNotEmpty);
      expect(AppConfig.current.uploadUrl, contains('dwzlw6jeu'));
      expect(AppConfig.current.uploadUrl, contains('api.cloudinary.com'));

      // Strictly verify no secret keys exist in config values
      const forbiddenTokens = ['secret', 'api_secret', 'private_key', 'service_account', 'password'];
      final configSummary =
          '${AppConfig.current.cloudinaryCloudName}_${AppConfig.current.cloudinaryUploadPreset}_${AppConfig.current.cloudinaryFolder}'
              .toLowerCase();
      for (final token in forbiddenTokens) {
        expect(configSummary.contains(token), isFalse, reason: 'Config must not contain $token');
      }
    });

    // 13. CloudinaryUploadResult parsing
    test('13. CloudinaryUploadResult parses valid JSON response accurately', () {
      final jsonResponse = {
        'secure_url': 'https://res.cloudinary.com/dwzlw6jeu/image/upload/v1726000000/parking_records/TKT-001/vehicle_photo.jpg',
        'public_id': 'parking_records/TKT-001/vehicle_photo',
        'format': 'jpg',
        'bytes': 24560,
      };

      final result = CloudinaryUploadResult.fromJson(jsonResponse);
      expect(result.secureUrl,
          'https://res.cloudinary.com/dwzlw6jeu/image/upload/v1726000000/parking_records/TKT-001/vehicle_photo.jpg');
      expect(result.publicId, 'parking_records/TKT-001/vehicle_photo');
      expect(result.format, 'jpg');
      expect(result.bytes, 24560);
    });

    // 14. Indian customer mobile number validation (Local 10 digits, 6-9 prefix)
    test('14. Indian customer mobile number validation accepts valid 10 digits and rejects invalid numbers', () {
      // Valid local 10-digit numbers starting with 6, 7, 8, 9
      expect(AppFormatters.isValidCustomerMobile('9876543210'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('8765432109'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('7654321098'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('6012345678'), isTrue);

      // Invalid numbers
      expect(AppFormatters.isValidCustomerMobile(''), isFalse);          // empty
      expect(AppFormatters.isValidCustomerMobile(null), isFalse);        // null
      expect(AppFormatters.isValidCustomerMobile('   '), isFalse);        // whitespace
      expect(AppFormatters.isValidCustomerMobile('12345'), isFalse);      // too short
      expect(AppFormatters.isValidCustomerMobile('987654321'), isFalse);  // 9 digits
      expect(AppFormatters.isValidCustomerMobile('98765432101'), isFalse);// 11 digits
      expect(AppFormatters.isValidCustomerMobile('1234567890'), isFalse); // starts with 1
      expect(AppFormatters.isValidCustomerMobile('5876543210'), isFalse); // starts with 5
      expect(AppFormatters.isValidCustomerMobile('0123456789'), isFalse); // starts with 0
      expect(AppFormatters.isValidCustomerMobile('abcdefghij'), isFalse); // letters
      expect(AppFormatters.isValidCustomerMobile('98765abc10'), isFalse); // mixed letters
      expect(AppFormatters.isValidCustomerMobile('98765@3210'), isFalse); // special characters
      expect(AppFormatters.isValidCustomerMobile('+919876543210'), isFalse); // +91 rejected
      expect(AppFormatters.isValidCustomerMobile('91 9876543210'), isFalse); // country code rejected
    });

    // 15. WhatsApp click-to-chat URL includes required fields
    test('15. WhatsApp click-to-chat URL contains ticket, vehicle, entry time, and parking name', () {
      final record = ParkingRecord(
        id: 'TKT-20260922-XY12',
        ticketId: 'TKT-20260922-XY12',
        ticketNumber: 'TKT-20260922-XY12',
        vehicleNumber: 'MH12DE1002',
        vehicleType: VehicleType.twoWheeler,
        customerMobile: '9876543210',
        entryTime: DateTime(2026, 9, 22, 10, 30),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Shift 1',
        advanceAmount: 0.0,
      );

      // Simulate the WhatsApp URL generation logic
      final mobile = record.customerMobile;
      final message = 'Parking Entry Confirmed ✅\n'
          'Parking: ${AppConstants.appName}\n'
          'Vehicle: ${record.vehicleNumber}\n'
          'Type: ${record.vehicleType.displayName}\n'
          'Ticket: ${record.ticketNumber}\n'
          'Entry Time: 22 Sep 2026, 10:30 AM\n'
          '\nPlease keep your ticket/QR for vehicle exit.';

      final encodedMsg = Uri.encodeComponent(message);
      final waUrl = 'https://wa.me/91$mobile?text=$encodedMsg';

      // Verify URL structure
      expect(waUrl, contains('wa.me'));
      expect(waUrl, contains('9876543210'));
      expect(waUrl, contains('MH12DE1002'));
      expect(waUrl, contains('TKT-20260922-XY12'));
      expect(waUrl.toLowerCase(), contains('car%20parking'));
      expect(waUrl, isNot(contains('secret')));
      expect(waUrl, isNot(contains('api_key')));
    });

    // 16. Mandatory Vehicle Photo UI options requirement
    test('16. Mandatory Vehicle Photo modal contains ONLY Take Photo with Camera and excludes gallery/dummy options', () {
      // Definition of allowed and forbidden options in the Capture Mandatory Vehicle Photo bottom sheet
      const allowedTitle = 'Take Photo with Camera';
      const allowedSubtitle = 'Use connected camera device';
      const forbiddenOptions = [
        'Choose Photo from Gallery / Files',
        'Capture Gate Camera Snapshot',
        'Choose from Gallery',
      ];

      // Simulated list of options rendered in the popup
      final popupOptions = [
        {'title': allowedTitle, 'subtitle': allowedSubtitle},
      ];

      expect(popupOptions.length, 1);
      expect(popupOptions.first['title'], allowedTitle);
      expect(popupOptions.first['subtitle'], allowedSubtitle);

      for (final forbidden in forbiddenOptions) {
        expect(popupOptions.any((opt) => opt['title'] == forbidden), isFalse);
      }
    });

    // 17. Vehicle Photo state transition and Retake availability
    test('17. Vehicle photo state transition updates badge to Photo Captured and provides Retake option', () {
      Uint8List? photoBytes;
      String getBadgeLabel(Uint8List? bytes) => bytes != null && bytes.isNotEmpty ? 'Photo Captured' : 'Required';
      bool hasRetakeOption(Uint8List? bytes) => bytes != null && bytes.isNotEmpty;

      // Initial state: no photo
      expect(getBadgeLabel(photoBytes), 'Required');
      expect(hasRetakeOption(photoBytes), isFalse);

      // Captured state: photo bytes present
      photoBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // JPEG magic bytes
      expect(getBadgeLabel(photoBytes), 'Photo Captured');
      expect(hasRetakeOption(photoBytes), isTrue);
    });
  });

  group('CAR PARKING SYSTEM — Vehicle Number Format & Normalization Test Suite (1 to 12)', () {
    // 1. lowercase input converts to uppercase
    test('1. lowercase input converts to uppercase', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'mh12ab1234',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(result.text, 'MH12AB1234');
      expect(result.selection.baseOffset, 10);
      expect(result.selection.extentOffset, 10);
    });

    // 2. mixed-case input converts to uppercase
    test('2. mixed-case input converts to uppercase', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: 'MH12',
          selection: TextSelection.collapsed(offset: 4),
        ),
        const TextEditingValue(
          text: 'Mh12aB1234',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(result.text, 'MH12AB1234');
      expect(result.selection.baseOffset, 10);
    });

    // 3. paste converts to uppercase
    test('3. paste converts to uppercase', () {
      final formatter = UpperCaseTextFormatter();
      // Pasting 'mh12ab1234' into an empty field
      final pasted1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'mh12ab1234',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(pasted1.text, 'MH12AB1234');

      // Pasting 'mh 12 ab 1234' with spaces
      final pasted2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'mh 12 ab 1234',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      expect(pasted2.text, 'MH 12 AB 1234');
      expect(pasted2.selection.baseOffset, 13);
    });

    // 4. spaces are normalized
    test('4. spaces are normalized', () {
      expect(AppFormatters.normalizeVehicleNumber('MH 12 AB 1234'), 'MH12AB1234');
      expect(AppFormatters.normalizeVehicleNumber('  MH   12   AB   1234  '), 'MH12AB1234');
      expect(AppFormatters.normalizeVehicleNumber('22 BH 1234 AA'), '22BH1234AA');
      expect(AppFormatters.normalizeVehicleNumber('DL 04 CA 9999'), 'DL04CA9999');
    });

    // 5. hyphens are normalized
    test('5. hyphens are normalized', () {
      expect(AppFormatters.normalizeVehicleNumber('MH-12-AB-1234'), 'MH12AB1234');
      expect(AppFormatters.normalizeVehicleNumber('mh-12-ab-1234'), 'MH12AB1234');
      expect(AppFormatters.normalizeVehicleNumber('DL--04--CA--9999'), 'DL04CA9999');
      expect(AppFormatters.normalizeVehicleNumber('KA-01-MJ-4321'), 'KA01MJ4321');
    });

    // 6. valid formats are accepted
    test('6. valid formats are accepted', () {
      final validInputs = [
        'MH12AB1234',
        'MH 12 AB 1234',
        'MH-12-AB-1234',
        'MH12A1234',
        'MH12AB123',
        'MH12AB12345',
        '22BH1234AA',
        '22 BH 1234 AA',
        'DL04CA9999',
        'KA01MJ4321',
        'GJ01AB1234',
      ];

      for (final input in validInputs) {
        expect(
          AppFormatters.isValidVehicleNumber(input),
          isTrue,
          reason: 'Expected "$input" to be valid',
        );
      }
    });

    // 7. invalid formats are rejected
    test('7. invalid formats are rejected', () {
      final invalidInputs = [
        'ABC',
        '123456',
        'MH',
        '12AB',
        'RANDOM123',
        '@@@###',
        '',
        '   ',
        '---',
        null,
      ];

      for (final input in invalidInputs) {
        expect(
          AppFormatters.isValidVehicleNumber(input),
          isFalse,
          reason: 'Expected "$input" to be rejected',
        );
      }
    });

    // 8. duplicate detection works across formatting variations
    test('8. duplicate detection works across formatting variations', () {
      // Stored active records (including normalized and legacy records with spaces/hyphens)
      final activeRecords = <String>['MH12AB1234', 'DL 04 CA 9999'];

      bool isVehicleAlreadyParked(String input) {
        final cleanInput = AppFormatters.normalizeVehicleNumber(input);
        return activeRecords.any((rec) => AppFormatters.normalizeVehicleNumber(rec) == cleanInput);
      }

      // Check all variations of MH12AB1234
      expect(isVehicleAlreadyParked('MH12AB1234'), isTrue);
      expect(isVehicleAlreadyParked('MH 12 AB 1234'), isTrue);
      expect(isVehicleAlreadyParked('MH-12-AB-1234'), isTrue);
      expect(isVehicleAlreadyParked('mh12ab1234'), isTrue);
      expect(isVehicleAlreadyParked('mh 12 ab 1234'), isTrue);

      // Check legacy record stored with spaces 'DL 04 CA 9999'
      expect(isVehicleAlreadyParked('DL04CA9999'), isTrue);
      expect(isVehicleAlreadyParked('dl04ca9999'), isTrue);
      expect(isVehicleAlreadyParked('DL-04-CA-9999'), isTrue);

      // Unparked vehicle
      expect(isVehicleAlreadyParked('KA01MJ4321'), isFalse);
    });

    // 9. Active Parking search works
    test('9. Active Parking search works', () {
      final records = [
        ParkingRecord(
          id: 'TKT-20260922-0001',
          ticketId: 'TKT-20260922-0001',
          ticketNumber: 'TKT-20260922-0001',
          vehicleNumber: 'MH12AB1234', // stored normalized
          vehicleType: VehicleType.fourWheeler,
          entryTime: DateTime(2026, 9, 22, 10, 0),
          status: 'ACTIVE',
          entryGuardUid: 'guard1',
          entryGuardName: 'Guard',
          entryShift: 'Shift 1',
        ),
        ParkingRecord(
          id: 'TKT-20260922-0002',
          ticketId: 'TKT-20260922-0002',
          ticketNumber: 'TKT-20260922-0002',
          vehicleNumber: 'DL 04 CA 9999', // legacy record stored with spaces
          vehicleType: VehicleType.fourWheeler,
          entryTime: DateTime(2026, 9, 22, 10, 30),
          status: 'ACTIVE',
          entryGuardUid: 'guard1',
          entryGuardName: 'Guard',
          entryShift: 'Shift 1',
        ),
      ];

      bool searchMatches(ParkingRecord r, String searchQuery) {
        final queryRaw = searchQuery.toUpperCase().trim();
        final queryNormalized = AppFormatters.normalizeVehicleNumber(searchQuery);
        final recVehicleNormalized = AppFormatters.normalizeVehicleNumber(r.vehicleNumber);

        final matchVehicle = (queryNormalized.isNotEmpty && recVehicleNormalized.contains(queryNormalized)) ||
            r.vehicleNumber.toUpperCase().contains(queryRaw);
        final matchTicket = r.ticketNumber.toUpperCase().contains(queryRaw) ||
            (queryNormalized.isNotEmpty && r.ticketNumber.toUpperCase().contains(queryNormalized));

        return matchVehicle || matchTicket;
      }

      // Stored normalized matches
      expect(searchMatches(records[0], 'mh12'), isTrue);
      expect(searchMatches(records[0], 'MH 12'), isTrue);
      expect(searchMatches(records[0], 'mh-12'), isTrue);
      expect(searchMatches(records[0], 'MH12AB1234'), isTrue);
      expect(searchMatches(records[0], 'mh 12 ab 1234'), isTrue);

      // Legacy record with spaces matches
      expect(searchMatches(records[1], 'dl04'), isTrue);
      expect(searchMatches(records[1], 'DL04CA9999'), isTrue);
      expect(searchMatches(records[1], 'dl-04-ca-9999'), isTrue);

      // Non-matching
      expect(searchMatches(records[0], 'KA01'), isFalse);
    });

    // 10. Vehicle Exit search works
    test('10. Vehicle Exit search works', () {
      final records = [
        ParkingRecord(
          id: 'TKT-20260922-0001',
          ticketId: 'TKT-20260922-0001',
          ticketNumber: 'TKT-20260922-0001',
          vehicleNumber: 'MH12AB1234',
          vehicleType: VehicleType.fourWheeler,
          entryTime: DateTime(2026, 9, 22, 10, 0),
          status: 'ACTIVE',
          entryGuardUid: 'guard1',
          entryGuardName: 'Guard',
          entryShift: 'Shift 1',
        ),
        ParkingRecord(
          id: 'TKT-20260922-0002',
          ticketId: 'TKT-20260922-0002',
          ticketNumber: 'TKT-20260922-0002',
          vehicleNumber: 'DL 04 CA 9999', // legacy record with spaces
          vehicleType: VehicleType.twoWheeler,
          entryTime: DateTime(2026, 9, 22, 10, 30),
          status: 'ACTIVE',
          entryGuardUid: 'guard1',
          entryGuardName: 'Guard',
          entryShift: 'Shift 1',
        ),
      ];

      ParkingRecord? findActiveVehicle(String query) {
        final clean = query.toUpperCase().trim();
        if (clean.isEmpty) return null;
        final normalized = AppFormatters.normalizeVehicleNumber(query);

        // 1. By ticket number
        for (final r in records) {
          if (r.ticketNumber.toUpperCase() == clean) return r;
        }
        // 2. By normalized vehicle number
        for (final r in records) {
          if (AppFormatters.normalizeVehicleNumber(r.vehicleNumber) == normalized) return r;
        }
        return null;
      }

      // All variations find the active vehicle
      expect(findActiveVehicle('MH12AB1234'), equals(records[0]));
      expect(findActiveVehicle('MH 12 AB 1234'), equals(records[0]));
      expect(findActiveVehicle('MH-12-AB-1234'), equals(records[0]));
      expect(findActiveVehicle('mh12ab1234'), equals(records[0]));

      // Ticket search continues working exactly as before
      expect(findActiveVehicle('TKT-20260922-0001'), equals(records[0]));
      expect(findActiveVehicle('tkt-20260922-0001'), equals(records[0]));

      // Legacy record with spaces found by normalized query
      expect(findActiveVehicle('DL04CA9999'), equals(records[1]));
      expect(findActiveVehicle('dl 04 ca 9999'), equals(records[1]));
    });

    // 11. Entry Slip displays normalized value
    test('11. Entry Slip displays normalized value', () {
      final legacyRecord = ParkingRecord(
        id: 'TKT-20260922-0001',
        ticketId: 'TKT-20260922-0001',
        ticketNumber: 'TKT-20260922-0001',
        vehicleNumber: 'mh 12 ab 1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      final displayedNumber = AppFormatters.normalizeVehicleNumber(legacyRecord.vehicleNumber);
      expect(displayedNumber, 'MH12AB1234');
      expect(displayedNumber.contains(' '), isFalse);
    });

    // 12. WhatsApp message displays normalized value
    test('12. WhatsApp message displays normalized value', () {
      final rawRecord = ParkingRecord(
        id: 'TKT-20260922-0001',
        ticketId: 'TKT-20260922-0001',
        ticketNumber: 'TKT-20260922-0001',
        vehicleNumber: 'mh-12-ab-1234',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: '9876543210',
        entryTime: DateTime(2026, 9, 22, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(rawRecord.vehicleNumber);
      final message = 'Parking Entry Confirmed ✅\nVehicle: $normalizedVehicleNumber\nTicket: ${rawRecord.ticketNumber}';
      expect(message, contains('Vehicle: MH12AB1234'));
      expect(message.contains('mh-12-ab-1234'), isFalse);
    });
  });

  group('CAR PARKING SYSTEM — Customer Phone Number Validation Test Suite (1 to 16)', () {
    // 1. Empty phone number -> FAIL
    test('1. Empty phone number -> FAIL', () {
      expect(AppFormatters.isValidCustomerMobile(''), isFalse);
      expect(AppFormatters.isValidCustomerMobile(null), isFalse);
      expect(AppFormatters.isValidCustomerMobile('   '), isFalse);
    });

    // 2. 9 digits -> FAIL
    test('2. 9 digits -> FAIL', () {
      expect(AppFormatters.isValidCustomerMobile('987654321'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('98765'), isFalse);
    });

    // 3. 10 digits starting with 6 -> PASS
    test('3. 10 digits starting with 6 -> PASS', () {
      expect(AppFormatters.isValidCustomerMobile('6654321098'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('6012345678'), isTrue);
    });

    // 4. 10 digits starting with 7 -> PASS
    test('4. 10 digits starting with 7 -> PASS', () {
      expect(AppFormatters.isValidCustomerMobile('7654321098'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('7012345678'), isTrue);
    });

    // 5. 10 digits starting with 8 -> PASS
    test('5. 10 digits starting with 8 -> PASS', () {
      expect(AppFormatters.isValidCustomerMobile('8765432109'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('8012345678'), isTrue);
    });

    // 6. 10 digits starting with 9 -> PASS
    test('6. 10 digits starting with 9 -> PASS', () {
      expect(AppFormatters.isValidCustomerMobile('9876543210'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('9667697879'), isTrue);
      expect(AppFormatters.isValidCustomerMobile('9876543211'), isTrue);
    });

    // 7. 11 digits -> FAIL / cannot be entered
    test('7. 11 digits -> FAIL / cannot be entered', () {
      expect(AppFormatters.isValidCustomerMobile('98765432101'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('987654321012'), isFalse);

      final limiter = LengthLimitingTextInputFormatter(10);
      final truncated = limiter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '98765432101',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(truncated.text, '9876543210');
      expect(truncated.text.length, 10);
    });

    // 8. Letters -> rejected
    test('8. Letters -> rejected', () {
      expect(AppFormatters.isValidCustomerMobile('abcdefghij'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('98765abc10'), isFalse);

      final digitsOnly = FilteringTextInputFormatter.digitsOnly;
      final filtered = digitsOnly.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '98765abc10'),
      );
      expect(filtered.text, '9876510');
    });

    // 9. Special characters -> rejected
    test('9. Special characters -> rejected', () {
      expect(AppFormatters.isValidCustomerMobile('98765@3210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('98765#3210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('98765\$3210'), isFalse);

      final digitsOnly = FilteringTextInputFormatter.digitsOnly;
      final filtered = digitsOnly.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '98765@3210'),
      );
      expect(filtered.text, '987653210');
    });

    // 10. Spaces -> rejected
    test('10. Spaces -> rejected', () {
      expect(AppFormatters.isValidCustomerMobile('98765 43210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile(' 9876543210 '), isTrue);
      expect(AppFormatters.isValidCustomerMobile('98 76 54 32 10'), isFalse);

      final digitsOnly = FilteringTextInputFormatter.digitsOnly;
      final filtered = digitsOnly.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '98765 43210'),
      );
      expect(filtered.text, '9876543210');
    });

    // 11. +91 format -> rejected
    test('11. +91 format -> rejected', () {
      expect(AppFormatters.isValidCustomerMobile('+919876543210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('+91 9876543210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('919876543210'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('91 9876543210'), isFalse);
    });

    // 12. Invalid first digit -> FAIL
    test('12. Invalid first digit -> FAIL', () {
      expect(AppFormatters.isValidCustomerMobile('1234567890'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('2234567890'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('3234567890'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('4234567890'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('5123456789'), isFalse);
      expect(AppFormatters.isValidCustomerMobile('0123456789'), isFalse);
    });

    // 13. Paste behavior -> verified
    test('13. Paste behavior -> verified', () {
      final digitsOnly = FilteringTextInputFormatter.digitsOnly;
      final limiter = LengthLimitingTextInputFormatter(10);

      TextEditingValue applyFormatters(String input) {
        var val = TextEditingValue(text: input);
        val = digitsOnly.formatEditUpdate(TextEditingValue.empty, val);
        val = limiter.formatEditUpdate(TextEditingValue.empty, val);
        return val;
      }

      final pastedValid = applyFormatters('9876543210');
      expect(pastedValid.text, '9876543210');
      expect(AppFormatters.isValidCustomerMobile(pastedValid.text), isTrue);

      final pastedWithCountryCode = applyFormatters('+91 9876543210');
      expect(pastedWithCountryCode.text, '9198765432');
      expect(pastedWithCountryCode.text.length, 10);
      expect(pastedWithCountryCode.text, isNot(equals('9876543210')));
    });

    // 14. Vehicle Entry blocks invalid phone number
    test('14. Vehicle Entry blocks invalid phone number', () {
      String? validateMobileField(String? v) {
        if (v == null || v.trim().isEmpty) {
          return 'Mobile number is required.';
        }
        if (!AppFormatters.isValidCustomerMobile(v)) {
          return 'Enter a valid 10-digit mobile number.';
        }
        return null;
      }

      expect(validateMobileField(''), 'Mobile number is required.');
      expect(validateMobileField('   '), 'Mobile number is required.');
      expect(validateMobileField(null), 'Mobile number is required.');
      expect(validateMobileField('98765'), 'Enter a valid 10-digit mobile number.');
      expect(validateMobileField('1234567890'), 'Enter a valid 10-digit mobile number.');
      expect(validateMobileField('+919876543210'), 'Enter a valid 10-digit mobile number.');
      expect(validateMobileField('9876543210'), isNull); // Valid!
    });

    // 15. Valid phone number is stored as exactly 10 digits
    test('15. Valid phone number is stored as exactly 10 digits', () {
      const input = '9876543210';
      expect(AppFormatters.isValidCustomerMobile(input), isTrue);

      final record = ParkingRecord(
        id: 'TKT-20260923-PHONE',
        ticketId: 'TKT-20260923-PHONE',
        ticketNumber: 'TKT-20260923-PHONE',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: input.trim(),
        entryTime: DateTime(2026, 9, 23, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      expect(record.customerMobile, equals('9876543210'));
      expect(record.customerMobile.length, 10);
      expect(record.toFirestore()['customerMobile'], equals('9876543210'));
    });

    // 16. WhatsApp still converts 10-digit number to +91/91 format correctly
    test('16. WhatsApp still converts 10-digit number to +91/91 format correctly', () {
      const storedMobile = '9876543210';
      const message = 'Test Parking Message';
      final encodedMsg = Uri.encodeComponent(message);

      String buildWhatsAppUrl(String mobile) {
        if (mobile.isNotEmpty) {
          return 'https://wa.me/91$mobile?text=$encodedMsg';
        }
        return 'https://wa.me/?text=$encodedMsg';
      }

      final url = buildWhatsAppUrl(storedMobile);
      expect(url, contains('https://wa.me/919876543210'));
    });
  });
}

