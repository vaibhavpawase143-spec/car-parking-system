import 'dart:math';
import '../../models/vehicle_type.dart';
import '../constants/app_constants.dart';

/// Holds the breakdown and final calculated parking charge.
class FeeCalculationResult {
  final Duration duration;
  final int totalMinutes;
  final int billableHours;
  final bool isGracePeriod;
  final double grossCharge;
  final double advancePaid;
  final double balanceDue;
  final double refundAmount;

  const FeeCalculationResult({
    required this.duration,
    required this.totalMinutes,
    required this.billableHours,
    required this.isGracePeriod,
    required this.grossCharge,
    required this.advancePaid,
    required this.balanceDue,
    required this.refundAmount,
  });

  bool get hasAdvance => advancePaid > 0;
  bool get hasRefund => refundAmount > 0;
  bool get isSettled => balanceDue == 0 && refundAmount == 0;
}

/// Calculates parking fees according to finalized two-wheeler rates
/// and proposed four-wheeler rates with zero free grace period.
class FeeCalculator {
  FeeCalculator._();

  /// Calculates the gross parking charge and adjusts for any advance collected.
  /// If [isMonthlyPass] is true, parking fee is strictly ₹0.
  static FeeCalculationResult calculate({
    required VehicleType vehicleType,
    required DateTime entryTime,
    required DateTime exitTime,
    double advancePaid = 0.0,
    bool isMonthlyPass = false,
  }) {
    final difference = exitTime.isAfter(entryTime)
        ? exitTime.difference(entryTime)
        : Duration.zero;

    // Monthly Pass: valid pass vehicle parking charge is strictly ₹0
    if (isMonthlyPass) {
      final int totalMinutes = difference.inMinutes < 1 ? (difference.inSeconds > 0 ? 1 : 0) : difference.inMinutes;
      final refund = advancePaid > 0 ? advancePaid : 0.0;
      return FeeCalculationResult(
        duration: difference,
        totalMinutes: totalMinutes,
        billableHours: 0,
        isGracePeriod: false,
        grossCharge: 0.0,
        advancePaid: advancePaid,
        balanceDue: 0.0,
        refundAmount: refund,
      );
    }

    // True zero duration: entryTime == exitTime or negative/zero difference
    if (difference.inSeconds <= 0) {
      final refund = advancePaid > 0 ? advancePaid : 0.0;
      return FeeCalculationResult(
        duration: Duration.zero,
        totalMinutes: 0,
        billableHours: 0,
        isGracePeriod: false,
        grossCharge: 0.0,
        advancePaid: advancePaid,
        balanceDue: 0.0,
        refundAmount: refund,
      );
    }

    // Any started stay (> 0 seconds) has at least 1 minute billable basis
    // (e.g. 5s, 30s stay incurs the 1st hour charge immediately)
    final int totalMinutes = difference.inMinutes < 1 ? 1 : difference.inMinutes;

    final firstHourRate = AppConstants.getFirstHourRate(vehicleType);
    final additionalHourRate = AppConstants.getAdditionalHourRate(vehicleType);
    final twelveHourCap = AppConstants.get12HourCap(vehicleType);

    // Billable hours calculation:
    // Zero free grace period — customer pays applicable first-hour charge from minute 1.
    // 1 to 60 mins -> 1 billable hour
    // 61 to 120 mins -> 2 billable hours
    // 121 to 180 mins -> 3 billable hours
    final int billableHours = calculateBillableHours(totalMinutes);

    double charge = 0.0;

    if (billableHours <= 1) {
      charge = firstHourRate;
    } else {
      final additionalHours = billableHours - 1;
      charge = firstHourRate + (additionalHours * additionalHourRate);
    }

    // Apply 12-hour cap for stays up to 12 hours (720 minutes)
    if (billableHours <= 12) {
      charge = min(charge, twelveHourCap);
    } else {
      // Beyond 12 hours: 12-hour cap + additional hours beyond 12
      final hoursBeyond12 = billableHours - 12;
      charge = twelveHourCap + (hoursBeyond12 * additionalHourRate);
    }

    // Advance payment adjustment
    final double balanceDue = max(0.0, charge - advancePaid);
    final double refundAmount = max(0.0, advancePaid - charge);

    return FeeCalculationResult(
      duration: difference,
      totalMinutes: totalMinutes,
      billableHours: billableHours,
      isGracePeriod: false,
      grossCharge: charge,
      advancePaid: advancePaid,
      balanceDue: balanceDue,
      refundAmount: refundAmount,
    );
  }

  /// Calculates the billable hours for a given duration in minutes.
  ///
  /// Business rules:
  /// - 0 minutes: 0 billable hours
  /// - 1 to 60 minutes: 1 billable hour (first hour)
  /// - 61 to 120 minutes: 2 billable hours (second hour)
  /// - 121 to 180 minutes: 3 billable hours (third hour)
  /// - Each subsequent 60-minute window adds 1 billable hour.
  static int calculateBillableHours(int totalMinutes) {
    if (totalMinutes <= 0) {
      return 0;
    }
    return (totalMinutes + 59) ~/ 60;
  }
}
