import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/constants/app_constants.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/models/vehicle_type.dart';

void main() {
  group('FEE CALCULATOR — ZERO FREE PERIOD & STRICT FIRST-HOUR BILLING (0 to 121+ mins)', () {
    final baseTime = DateTime(2026, 9, 25, 10, 0, 0);

    // =========================================================================
    // 1. DURATION 0 MIN: Zero charge
    // =========================================================================
    test('0 min: returns 0 billable hours and ₹0 gross charge', () {
      final calc2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime,
      );
      expect(calc2W.billableHours, 0);
      expect(calc2W.grossCharge, 0.0);

      final calc4W = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime,
      );
      expect(calc4W.billableHours, 0);
      expect(calc4W.grossCharge, 0.0);
    });

    // =========================================================================
    // 2. SUB-MINUTE & FIRST HOUR (15s, 30s, 1 min to 60 mins) — Immediate first-hour charge
    // =========================================================================
    test('15 seconds stay (started session): incurs 1 billable hour (first-hour rate)', () {
      final calc2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(seconds: 15)),
      );
      expect(calc2W.billableHours, 1);
      expect(calc2W.grossCharge, AppConstants.twoWheelerFirstHourRate);

      final calc4W = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(seconds: 15)),
      );
      expect(calc4W.billableHours, 1);
      expect(calc4W.grossCharge, AppConstants.fourWheelerFirstHourRate);
    });

    final firstHourMinutes = [1, 5, 10, 11, 30, 59, 60];

    for (final mins in firstHourMinutes) {
      test('$mins min: incurs 1 billable hour (2W: ₹${AppConstants.twoWheelerFirstHourRate.toInt()}, 4W: ₹${AppConstants.fourWheelerFirstHourRate.toInt()})', () {
        final calc2W = FeeCalculator.calculate(
          vehicleType: VehicleType.twoWheeler,
          entryTime: baseTime,
          exitTime: baseTime.add(Duration(minutes: mins)),
        );
        expect(calc2W.billableHours, 1);
        expect(calc2W.grossCharge, AppConstants.twoWheelerFirstHourRate);

        final calc4W = FeeCalculator.calculate(
          vehicleType: VehicleType.fourWheeler,
          entryTime: baseTime,
          exitTime: baseTime.add(Duration(minutes: mins)),
        );
        expect(calc4W.billableHours, 1);
        expect(calc4W.grossCharge, AppConstants.fourWheelerFirstHourRate);
      });
    }

    // =========================================================================
    // 3. SECOND HOUR (61 min to 120 mins)
    // =========================================================================
    final secondHourMinutes = [61, 69, 70, 119, 120];

    for (final mins in secondHourMinutes) {
      test('$mins min: incurs 2 billable hours (2W: ₹${(AppConstants.twoWheelerFirstHourRate + AppConstants.twoWheelerAdditionalHourRate).toInt()}, 4W: ₹${(AppConstants.fourWheelerFirstHourRate + AppConstants.fourWheelerAdditionalHourRate).toInt()})', () {
        final calc2W = FeeCalculator.calculate(
          vehicleType: VehicleType.twoWheeler,
          entryTime: baseTime,
          exitTime: baseTime.add(Duration(minutes: mins)),
        );
        expect(calc2W.billableHours, 2);
        expect(calc2W.grossCharge, AppConstants.twoWheelerFirstHourRate + AppConstants.twoWheelerAdditionalHourRate);

        final calc4W = FeeCalculator.calculate(
          vehicleType: VehicleType.fourWheeler,
          entryTime: baseTime,
          exitTime: baseTime.add(Duration(minutes: mins)),
        );
        expect(calc4W.billableHours, 2);
        expect(calc4W.grossCharge, AppConstants.fourWheelerFirstHourRate + AppConstants.fourWheelerAdditionalHourRate);
      });
    }

    // =========================================================================
    // 4. THIRD HOUR (121 min to 180 mins)
    // =========================================================================
    test('121 min: incurs 3 billable hours (2W: ₹30, 4W: ₹70)', () {
      final calc2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(minutes: 121)),
      );
      expect(calc2W.billableHours, 3);
      expect(calc2W.grossCharge, AppConstants.twoWheelerFirstHourRate + (2 * AppConstants.twoWheelerAdditionalHourRate));

      final calc4W = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(minutes: 121)),
      );
      expect(calc4W.billableHours, 3);
      expect(calc4W.grossCharge, AppConstants.fourWheelerFirstHourRate + (2 * AppConstants.fourWheelerAdditionalHourRate));
    });

    // =========================================================================
    // 5. 12-HOUR CAP & BEYOND 12 HOURS
    // =========================================================================
    test('12-hour stays cap at configured limits (2W: ₹60, 4W: ₹150)', () {
      final calc12h2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 12)),
      );
      expect(calc12h2W.billableHours, 12);
      expect(calc12h2W.grossCharge, AppConstants.twoWheeler12HourCap);

      final calc12h4W = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 12)),
      );
      expect(calc12h4W.billableHours, 12);
      expect(calc12h4W.grossCharge, AppConstants.fourWheeler12HourCapProposed);
    });

    test('13 hours (780 min): 12-hour cap + 1 additional hour', () {
      final calc13h2W = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(hours: 13)),
      );
      expect(calc13h2W.billableHours, 13);
      expect(calc13h2W.grossCharge, AppConstants.twoWheeler12HourCap + AppConstants.twoWheelerAdditionalHourRate); // 60 + 5 = 65
    });

    // =========================================================================
    // 6. ADVANCE & REFUND SETTLEMENT
    // =========================================================================
    test('Advance greater than fee yields correct refund', () {
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(minutes: 45)),
        advancePaid: 50.0,
      );
      expect(calc.grossCharge, 20.0);
      expect(calc.advancePaid, 50.0);
      expect(calc.balanceDue, 0.0);
      expect(calc.refundAmount, 30.0);
    });

    test('Advance less than fee yields correct balance due', () {
      final calc = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: baseTime,
        exitTime: baseTime.add(const Duration(minutes: 120)),
        advancePaid: 30.0,
      );
      expect(calc.grossCharge, 60.0);
      expect(calc.advancePaid, 30.0);
      expect(calc.balanceDue, 30.0);
      expect(calc.refundAmount, 0.0);
    });
  });
}
