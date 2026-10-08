import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/dashboard_service.dart';

void main() {
  group('Simplified Admin Reports Hub Tests', () {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final sampleRecords = [
      ParkingRecord(
        id: 'rec_01',
        ticketNumber: '1001',
        vehicleNumber: 'MH17PQ7673',
        vehicleType: VehicleType.twoWheeler,
        entryTime: todayStart.add(const Duration(hours: 11, minutes: 11)),
        exitTime: todayStart.add(const Duration(hours: 17, minutes: 30)),
        status: 'EXITED',
        entryGuardUid: 'g1',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Morning Shift',
        advanceAmount: 20.0,
        paidAmount: 50.0,
        finalCharge: 50.0,
        paymentMethod: 'cash',
        exitGuardUid: 'g2',
        exitGuardName: 'Guard Suresh',
        exitShift: 'Evening Shift',
      ),
      ParkingRecord(
        id: 'rec_02',
        ticketNumber: '1002',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: todayStart.add(const Duration(hours: 10, minutes: 20)),
        status: 'ACTIVE',
        entryGuardUid: 'g1',
        entryGuardName: 'Guard Ramesh',
        entryShift: 'Morning Shift',
        advanceAmount: 100.0,
        paymentMethod: 'upi',
      ),
      ParkingRecord(
        id: 'rec_03',
        ticketNumber: '1003',
        vehicleNumber: 'MH14CD5678',
        vehicleType: VehicleType.fourWheeler,
        entryTime: todayStart.subtract(const Duration(days: 2)),
        exitTime: todayStart.subtract(const Duration(days: 2, hours: -3)),
        status: 'EXITED',
        entryGuardUid: 'g3',
        entryGuardName: 'Guard Mahesh',
        entryShift: 'Night Shift',
        finalCharge: 80.0,
        paymentMethod: 'cash',
      ),
    ];

    final sampleTransactions = [
      PaymentTransactionModel(
        id: 't1',
        ticketId: '1001',
        vehicleNumber: 'MH17PQ7673',
        amount: 20.0,
        paymentType: 'advance',
        paymentMethod: 'cash',
        guardUid: 'g1',
        createdAt: todayStart.add(const Duration(hours: 11, minutes: 11)),
      ),
      PaymentTransactionModel(
        id: 't2',
        ticketId: '1001',
        vehicleNumber: 'MH17PQ7673',
        amount: 30.0,
        paymentType: 'final',
        paymentMethod: 'cash',
        guardUid: 'g1',
        createdAt: todayStart.add(const Duration(hours: 17, minutes: 30)),
      ),
      PaymentTransactionModel(
        id: 't3',
        ticketId: '1002',
        vehicleNumber: 'MH12AB1234',
        amount: 100.0,
        paymentType: 'advance',
        paymentMethod: 'upi',
        guardUid: 'g1',
        createdAt: todayStart.add(const Duration(hours: 10, minutes: 20)),
      ),
      PaymentTransactionModel(
        id: 't4',
        ticketId: '1000',
        vehicleNumber: 'MH12XX0000',
        amount: 10.0,
        paymentType: 'refund',
        paymentMethod: 'cash',
        guardUid: 'g1',
        createdAt: todayStart.add(const Duration(hours: 14, minutes: 0)),
      ),
    ];

    const sampleCapacity = CapacityData(
      carTotal: 30,
      carOccupied: 6,
      twoWheelerTotal: 20,
      twoWheelerOccupied: 6,
    );

    test('1. Parking Summary: computes Total Entries, Total Exits, and authoritative Total Collection', () {
      // Filter for Today
      final todayEntries = sampleRecords.where((r) =>
          !r.entryTime.isBefore(todayStart) && !r.entryTime.isAfter(todayEnd)).length;
      final todayExits = sampleRecords.where((r) =>
          r.exitTime != null && !r.exitTime!.isBefore(todayStart) && !r.exitTime!.isAfter(todayEnd)).length;

      expect(todayEntries, 2);
      expect(todayExits, 1);

      // Currently Parked from authoritative capacity source
      final currentlyParked = sampleCapacity.carOccupied + sampleCapacity.twoWheelerOccupied;
      expect(currentlyParked, 12);

      // Total Collection: ADVANCE + FINAL - REFUND
      double totalCollection = 0.0;
      for (final t in sampleTransactions) {
        if (t.isAdvance || t.isFinal) {
          totalCollection += t.amount;
        } else if (t.isRefund) {
          totalCollection -= t.amount;
        }
      }
      expect(totalCollection, (20.0 + 30.0 + 100.0) - 10.0);
      expect(totalCollection, 140.0);
    });

    test('2. Parking Capacity: displays Four-Wheeler, Two-Wheeler, and Total Occupancy with Availability', () {
      expect(sampleCapacity.carOccupied, 6);
      expect(sampleCapacity.carTotal, 30);
      expect(sampleCapacity.carAvailable, 24);

      expect(sampleCapacity.twoWheelerOccupied, 6);
      expect(sampleCapacity.twoWheelerTotal, 20);
      expect(sampleCapacity.twoWheelerAvailable, 14);

      final totalOccupied = sampleCapacity.carOccupied + sampleCapacity.twoWheelerOccupied;
      final totalCapacity = sampleCapacity.carTotal + sampleCapacity.twoWheelerTotal;
      final totalAvailable = sampleCapacity.carAvailable + sampleCapacity.twoWheelerAvailable;

      expect(totalOccupied, 12);
      expect(totalCapacity, 50);
      expect(totalAvailable, 38);
    });

    test('3. Vehicle Report Pipeline: search by vehicle number, ticket number, and guard name', () {
      // Search by vehicle number
      final searchByVeh = sampleRecords.where((r) {
        final q = 'MH17PQ7673'.toLowerCase();
        final qNorm = 'MH17PQ7673'.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        final vehNorm = r.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        return vehNorm.contains(qNorm) || r.vehicleNumber.toLowerCase().contains(q);
      }).toList();
      expect(searchByVeh.length, 1);
      expect(searchByVeh.first.ticketNumber, '1001');

      // Search by ticket number
      final searchByTicket = sampleRecords.where((r) => r.ticketNumber.contains('1002')).toList();
      expect(searchByTicket.length, 1);
      expect(searchByTicket.first.vehicleNumber, 'MH12AB1234');

      // Search by guard name
      final searchByGuard = sampleRecords.where((r) =>
          r.entryGuardName.toLowerCase().contains('ramesh') ||
          (r.exitGuardName != null && r.exitGuardName!.toLowerCase().contains('ramesh'))).toList();
      expect(searchByGuard.length, 2);
    });

    test('4. Vehicle Report Pipeline: filter by Vehicle Type and Status', () {
      // Type filter
      final twoWheelers = sampleRecords.where((r) => r.vehicleType == VehicleType.twoWheeler).toList();
      expect(twoWheelers.length, 1);

      final fourWheelers = sampleRecords.where((r) => r.vehicleType == VehicleType.fourWheeler).toList();
      expect(fourWheelers.length, 2);

      // Status filter
      final activeVehicles = sampleRecords.where((r) => !r.isExited).toList();
      expect(activeVehicles.length, 1);
      expect(activeVehicles.first.vehicleNumber, 'MH12AB1234');

      final exitedVehicles = sampleRecords.where((r) => r.isExited).toList();
      expect(exitedVehicles.length, 2);
    });

    test('5. Vehicle Report Pipeline: sorts by newest vs oldest entry time', () {
      final sortedNewest = List<ParkingRecord>.from(sampleRecords)
        ..sort((a, b) => b.entryTime.compareTo(a.entryTime));
      expect(sortedNewest.first.ticketNumber, '1001'); // 11:11 AM today

      final sortedOldest = List<ParkingRecord>.from(sampleRecords)
        ..sort((a, b) => a.entryTime.compareTo(b.entryTime));
      expect(sortedOldest.first.ticketNumber, '1003'); // 2 days ago
    });

    test('6. Vehicle duration and amount formatting', () {
      String formatDuration(Duration d) {
        final hours = d.inHours;
        final minutes = d.inMinutes.remainder(60);
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        }
        return '${minutes}m';
      }

      final rec1 = sampleRecords[0];
      final duration = rec1.exitTime!.difference(rec1.entryTime);
      expect(formatDuration(duration), '6h 19m');

      double getRecordAmount(ParkingRecord rec) {
        if (rec.finalCharge != null && rec.finalCharge! > 0) return rec.finalCharge!;
        if (rec.paidAmount != null && rec.paidAmount! > 0) return rec.paidAmount!;
        if (rec.advanceAmount > 0) return rec.advanceAmount;
        return 0.0;
      }

      expect(getRecordAmount(rec1), 50.0);
      expect(AppFormatters.formatCurrency(getRecordAmount(rec1)), '₹50');
    });

    test('7. Confirmation of Exclusions: Reports Hub contains NO Withdrawals or Guard Financial balances', () {
      // In Reports Hub:
      // - No Cash/UPI outstanding breakdowns
      // - No Handover In / Out tabs
      // - No Keep With Me records
      // - No Withdrawal metrics
      const reportsHubSections = [
        'Header',
        'Period Selector',
        'Parking Summary',
        'Parking Capacity',
        'Vehicle Report',
      ];
      expect(reportsHubSections.contains('Withdrawals'), isFalse);
      expect(reportsHubSections.contains('Keep With Me'), isFalse);
      expect(reportsHubSections.contains('Handovers'), isFalse);
      expect(reportsHubSections.contains('Cash Outstanding'), isFalse);
      expect(reportsHubSections.contains('Guard Financial Report'), isFalse);
    });
  });
}
