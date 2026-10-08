import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/monthly_pass_service.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';

void main() {
  group('Part 1: Monthly Pass Vehicle Type Validation & Mismatch Rejection', () {
    final now = DateTime(2026, 9, 30, 17, 0);

    final twoWheelerPass = MonthlyPassModel(
      id: 'PASS-2026-001',
      passNumber: 'PASS-2026-001',
      vehicleNumber: 'MH 17 PD 2121',
      normalizedVehicleNumber: 'MH17PD2121',
      vehicleType: VehicleType.twoWheeler,
      customerName: 'Vaibhav Pawase',
      customerMobile: '9876543210',
      startDate: DateTime(2026, 9, 30),
      endDate: DateTime(2026, 10, 29, 23, 59, 59),
      amount: 600.0,
      amountPaid: 600.0,
      paymentStatus: 'PAID',
      paymentMethod: 'CASH',
      status: 'ACTIVE',
      createdAt: now,
      createdBy: 'ADMIN',
    );

    final fourWheelerPass = MonthlyPassModel(
      id: 'PASS-2026-002',
      passNumber: 'PASS-2026-002',
      vehicleNumber: 'MH 12 AB 9999',
      normalizedVehicleNumber: 'MH12AB9999',
      vehicleType: VehicleType.fourWheeler,
      customerName: 'Rahul Shinde',
      customerMobile: '9123456780',
      startDate: DateTime(2026, 9, 30),
      endDate: DateTime(2026, 10, 29, 23, 59, 59),
      amount: 600.0,
      amountPaid: 600.0,
      paymentStatus: 'PAID',
      paymentMethod: 'UPI',
      status: 'ACTIVE',
      createdAt: now,
      createdBy: 'ADMIN',
    );

    test('VehiclePassCheckResult.isValidForType strictly matches pass vehicle type', () {
      final twoWheelerResult = VehiclePassCheckResult(validPass: twoWheelerPass);
      expect(twoWheelerResult.hasValidPass, isTrue);
      // Valid for Two-Wheeler
      expect(twoWheelerResult.isValidForType(VehicleType.twoWheeler), isTrue);
      // INVALID for Four-Wheeler (MUST NOT MATCH)
      expect(twoWheelerResult.isValidForType(VehicleType.fourWheeler), isFalse);

      final fourWheelerResult = VehiclePassCheckResult(validPass: fourWheelerPass);
      expect(fourWheelerResult.hasValidPass, isTrue);
      // Valid for Four-Wheeler
      expect(fourWheelerResult.isValidForType(VehicleType.fourWheeler), isTrue);
      // INVALID for Two-Wheeler (MUST NOT MATCH)
      expect(fourWheelerResult.isValidForType(VehicleType.twoWheeler), isFalse);
    });

    test('Two-Wheeler Pass + Four-Wheeler entry MUST NOT get free parking (normal fees apply)', () {
      final twoWheelerResult = VehiclePassCheckResult(validPass: twoWheelerPass);
      const selectedType = VehicleType.fourWheeler;

      // In vehicle entry logic:
      final hasValidPass = twoWheelerResult.hasValidPass;
      final isTypeMatch = hasValidPass && twoWheelerResult.validPass!.vehicleType == selectedType;
      final isMonthlyPass = isTypeMatch;
      final monthlyPassId = isTypeMatch ? twoWheelerResult.validPass?.id : null;

      expect(isTypeMatch, isFalse, reason: 'Two-Wheeler pass must not match Four-Wheeler entry');
      expect(isMonthlyPass, isFalse);
      expect(monthlyPassId, isNull);

      // Fee calculation for normal Four-Wheeler entry of 3 hours
      final entryTime = now;
      final exitTime = now.add(const Duration(hours: 3));
      final calculation = FeeCalculator.calculate(
        vehicleType: selectedType,
        entryTime: entryTime,
        exitTime: exitTime,
        isMonthlyPass: isMonthlyPass,
      );

      // Four-Wheeler rate: 30 first hr + 20/hr * 2 = 70
      expect(calculation.grossCharge, 70.0);
      expect(calculation.balanceDue, 70.0);
    });

    test('Two-Wheeler Pass + Two-Wheeler entry GETS free parking (₹0)', () {
      final twoWheelerResult = VehiclePassCheckResult(validPass: twoWheelerPass);
      const selectedType = VehicleType.twoWheeler;

      final hasValidPass = twoWheelerResult.hasValidPass;
      final isTypeMatch = hasValidPass && twoWheelerResult.validPass!.vehicleType == selectedType;
      final isMonthlyPass = isTypeMatch;
      final monthlyPassId = isTypeMatch ? twoWheelerResult.validPass?.id : null;

      expect(isTypeMatch, isTrue);
      expect(isMonthlyPass, isTrue);
      expect(monthlyPassId, 'PASS-2026-001');

      final entryTime = now;
      final exitTime = now.add(const Duration(hours: 5));
      final calculation = FeeCalculator.calculate(
        vehicleType: selectedType,
        entryTime: entryTime,
        exitTime: exitTime,
        isMonthlyPass: isMonthlyPass,
      );

      expect(calculation.grossCharge, 0.0);
      expect(calculation.balanceDue, 0.0);
    });

    test('Four-Wheeler Pass + Two-Wheeler entry MUST NOT get free parking', () {
      final fourWheelerResult = VehiclePassCheckResult(validPass: fourWheelerPass);
      const selectedType = VehicleType.twoWheeler;

      final isTypeMatch = fourWheelerResult.hasValidPass &&
          fourWheelerResult.validPass!.vehicleType == selectedType;

      expect(isTypeMatch, isFalse);

      final calculation = FeeCalculator.calculate(
        vehicleType: selectedType,
        entryTime: now,
        exitTime: now.add(const Duration(hours: 2)),
        isMonthlyPass: isTypeMatch,
      );

      // Two-Wheeler rate: 15 first hr + 10 = 25
      expect(calculation.grossCharge, 25.0);
      expect(calculation.balanceDue, 25.0);
    });

    test('Upcoming or Expired pass does not allow pass entry or ₹0 fee', () {
      // Expired pass
      final expiredPass = MonthlyPassModel(
        id: 'PASS-OLD',
        passNumber: 'PASS-OLD',
        vehicleNumber: 'MH 17 PD 2121',
        normalizedVehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        customerName: 'Vaibhav',
        customerMobile: '9876543210',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'CASH',
        status: 'ACTIVE',
        createdAt: DateTime(2026, 8, 1),
        createdBy: 'ADMIN',
      );

      final expiredResult = VehiclePassCheckResult(
        validPass: null,
        expiredPass: expiredPass,
      );

      expect(expiredResult.hasValidPass, isFalse);
      expect(expiredResult.isExpired, isTrue);
      expect(expiredResult.isValidForType(VehicleType.twoWheeler), isFalse);

      // Upcoming pass
      final upcomingPass = MonthlyPassModel(
        id: 'PASS-FUTURE',
        passNumber: 'PASS-FUTURE',
        vehicleNumber: 'MH 17 PD 2121',
        normalizedVehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        customerName: 'Vaibhav',
        customerMobile: '9876543210',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'CASH',
        status: 'ACTIVE',
        createdAt: now,
        createdBy: 'ADMIN',
      );

      final upcomingResult = VehiclePassCheckResult(
        validPass: null,
        upcomingPass: upcomingPass,
      );

      expect(upcomingResult.hasValidPass, isFalse);
      expect(upcomingResult.isUpcoming, isTrue);
      expect(upcomingResult.isValidForType(VehicleType.twoWheeler), isFalse);
    });

    test('Normalization handles spaces, lowercase, and hyphens accurately', () {
      const rawInput = 'mh-17 pd 2121';
      final normalized = AppFormatters.normalizeVehicleNumber(rawInput);
      expect(normalized, 'MH17PD2121');
      expect(normalized, twoWheelerPass.normalizedVehicleNumber);
    });
  });

  group('Part 2: Pass Entry / Exit Records & Parking History', () {
    final entryTime = DateTime(2026, 9, 30, 17, 6);
    final exitTime = DateTime(2026, 9, 30, 20, 20);

    test('Pass vehicle entry creates complete ParkingRecord with ₹0 advance and isMonthlyPass true', () {
      final record = ParkingRecord(
        id: 'rec_1025',
        ticketId: 'rec_1025',
        ticketNumber: '1025',
        vehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        customerMobile: '9876543210',
        entryTime: entryTime,
        status: 'ACTIVE',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        entryShift: '06:00 - 14:00',
        advanceAmount: 0.0,
        isMonthlyPass: true,
        monthlyPassId: 'PASS-2026-001',
      );

      expect(record.isMonthlyPass, isTrue);
      expect(record.monthlyPassId, 'PASS-2026-001');
      expect(record.advanceAmount, 0.0);
      expect(record.status, 'ACTIVE');

      final firestoreMap = record.toFirestore();
      expect(firestoreMap['isMonthlyPass'], isTrue);
      expect(firestoreMap['monthlyPassId'], 'PASS-2026-001');
      expect(firestoreMap['normalizedVehicleNumber'], 'MH17PD2121');
    });

    test('Pass vehicle exit records exit info, guard, duration, and fee ₹0', () {
      final completedRecord = ParkingRecord(
        id: 'rec_1025',
        ticketId: 'rec_1025',
        ticketNumber: '1025',
        vehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        customerMobile: '9876543210',
        entryTime: entryTime,
        exitTime: exitTime,
        status: 'COMPLETED',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        exitGuardUid: 'guard_b',
        exitGuardName: 'Guard B',
        entryShift: '14:00 - 22:00',
        exitShift: '14:00 - 22:00',
        grossCharge: 0.0,
        finalCharge: 0.0,
        paidAmount: 0.0,
        balanceDue: 0.0,
        isMonthlyPass: true,
        monthlyPassId: 'PASS-2026-001',
      );

      expect(completedRecord.status, 'COMPLETED');
      expect(completedRecord.exitTime, isNotNull);
      expect(completedRecord.exitGuardName, 'Guard B');
      expect(completedRecord.finalCharge, 0.0);

      final duration = completedRecord.exitTime!.difference(completedRecord.entryTime);
      expect(duration.inHours, 3);
      expect(duration.inMinutes.remainder(60), 14);
    });

    test('Edge Case: Entry before pass expiry and exit after pass expiry remains ₹0', () {
      // Entry: 29 Oct 2026 11:00 PM (before pass expires at 11:59 PM)
      final lateEntry = DateTime(2026, 10, 29, 23, 0);
      // Exit: 30 Oct 2026 01:00 AM (after pass has expired)
      final nextDayExit = DateTime(2026, 10, 30, 1, 0);

      // In the application, entry was accepted with isMonthlyPass = true
      final feeResult = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: lateEntry,
        exitTime: nextDayExit,
        isMonthlyPass: true,
      );

      expect(feeResult.grossCharge, 0.0);
      expect(feeResult.balanceDue, 0.0);
    });

    test('Live currently parked pass vehicle has active status and calculates live duration', () {
      final activeVisit = ParkingRecord(
        id: 'rec_1031',
        ticketId: 'rec_1031',
        ticketNumber: '1031',
        vehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
        exitTime: null,
        status: 'ACTIVE',
        entryGuardUid: 'guard_a',
        entryGuardName: 'Guard A',
        entryShift: 'Shift 1',
        isMonthlyPass: true,
        monthlyPassId: 'PASS-2026-001',
      );

      final isCurrentlyParked = activeVisit.status.toUpperCase() != 'COMPLETED' && activeVisit.exitTime == null;
      expect(isCurrentlyParked, isTrue);
      final liveDuration = DateTime.now().difference(activeVisit.entryTime);
      expect(liveDuration.inHours, greaterThanOrEqualTo(2));
    });
  });

  group('Part 3: Localization Strings Verification', () {
    test('English and Marathi strings for Monthly Pass validation and history exist', () {
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.monthlyPassVehicleTypeMismatch, 'Monthly Pass vehicle type mismatch.');
      expect(AppStrings.passVehicleType, 'Pass Type');
      expect(AppStrings.selectedVehicleType, 'Selected Type');
      expect(AppStrings.viewParkingHistory, 'View Parking History');
      expect(AppStrings.monthlyPassParkingHistory, 'Monthly Pass Parking History');
      expect(AppStrings.currentlyParked, 'Currently Parked');
      expect(AppStrings.totalVisits, 'Total Visits');

      AppStrings.setLanguage(AppLanguage.marathi);
      expect(AppStrings.monthlyPassVehicleTypeMismatch, 'मासिक पास वाहन प्रकार जुळत नाही.');
      expect(AppStrings.passVehicleType, 'पास प्रकार');
      expect(AppStrings.selectedVehicleType, 'निवडलेला प्रकार');
      expect(AppStrings.viewParkingHistory, 'पार्किंग इतिहास पहा');
      expect(AppStrings.monthlyPassParkingHistory, 'मासिक पास पार्किंग इतिहास');
      expect(AppStrings.currentlyParked, 'सध्या पार्क केलेली वाहने');

      // Reset to English
      AppStrings.setLanguage(AppLanguage.english);
    });
  });
}
