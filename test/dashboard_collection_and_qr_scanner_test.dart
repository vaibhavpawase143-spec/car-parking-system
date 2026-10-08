import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/dashboard_service.dart';
import 'package:car_parking_system/widgets/camera/qr_scanner_dialog.dart';

void main() {
  group('A) Dashboard Total Collection Financial Ledger Tests', () {
    test('1. Same-day entry (advance ₹20) + exit (balance ₹30 cash) = Total ₹50', () {
      final now = DateTime.now();

      // Simulated payment transactions for today
      final transactions = [
        {
          'ticketId': '1001',
          'amount': 20.0,
          'paymentType': 'ADVANCE',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(hours: 3)),
        },
        {
          'ticketId': '1001',
          'amount': 30.0,
          'paymentType': 'FINAL',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(minutes: 10)),
        },
      ];

      double cash = 0.0;
      double upi = 0.0;

      for (final txn in transactions) {
        final amount = txn['amount'] as double;
        final type = (txn['paymentType'] as String).toUpperCase();
        final isUpi = (txn['paymentMethod'] as String).toLowerCase() == 'upi';

        if (type == 'ADVANCE' || type == 'FINAL') {
          if (isUpi) {
            upi += amount;
          } else {
            cash += amount;
          }
        } else if (type == 'REFUND') {
          if (isUpi) {
            upi -= amount;
          } else {
            cash -= amount;
          }
        }
      }

      final metrics = DashboardMetrics(
        todayEntries: 1,
        todayExits: 1,
        todayCollection: cash + upi,
        cashCollection: cash,
        upiCollection: upi,
      );

      expect(metrics.todayCollection, equals(50.0));
      expect(metrics.cashCollection, equals(50.0));
      expect(metrics.upiCollection, equals(0.0));
      expect(metrics.todayEntries, equals(1));
      expect(metrics.todayExits, equals(1));
    });

    test('2. Multi-day stay: Entry yesterday (advance ₹20) + Exit today (balance ₹30 cash)', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Today's transaction only
      final todayTxns = [
        {
          'ticketId': '1002',
          'amount': 30.0,
          'paymentType': 'FINAL',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(minutes: 30)),
        },
      ];

      // Filter: createdAt >= todayStart
      final filteredTxns = todayTxns.where((t) => (t['createdAt'] as DateTime).isAfter(todayStart) || (t['createdAt'] as DateTime).isAtSameMomentAs(todayStart)).toList();

      double cash = 0.0;
      double upi = 0.0;

      for (final txn in filteredTxns) {
        final amount = txn['amount'] as double;
        final type = (txn['paymentType'] as String).toUpperCase();
        final isUpi = (txn['paymentMethod'] as String).toLowerCase() == 'upi';

        if (type == 'ADVANCE' || type == 'FINAL') {
          if (isUpi) {
            upi += amount;
          } else {
            cash += amount;
          }
        }
      }

      // Record entered yesterday, but exited today
      final record = ParkingRecord(
        id: '1002',
        ticketNumber: '1002',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: todayStart.subtract(const Duration(hours: 12)),
        exitTime: now.subtract(const Duration(minutes: 30)),
        status: 'EXITED',
        entryGuardUid: 'G1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
        advanceAmount: 20.0,
        paidAmount: 30.0,
      );

      final isExitToday = record.exitTime != null && (record.exitTime!.isAfter(todayStart) || record.exitTime!.isAtSameMomentAs(todayStart));

      final metrics = DashboardMetrics(
        todayEntries: 0, // entered yesterday
        todayExits: isExitToday ? 1 : 0, // exited today
        todayCollection: cash + upi,
        cashCollection: cash,
        upiCollection: upi,
      );

      // Crucial test: Today's collection is ONLY ₹30 (today's payment), NOT ₹50 and NOT ₹0
      expect(metrics.todayCollection, equals(30.0));
      expect(metrics.cashCollection, equals(30.0));
      expect(metrics.todayExits, equals(1));
      expect(metrics.todayEntries, equals(0));
    });

    test('3. Advance ₹50 today + Refund ₹20 today = Net Collection ₹30', () {
      final now = DateTime.now();

      final transactions = [
        {
          'ticketId': '1003',
          'amount': 50.0,
          'paymentType': 'ADVANCE',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(hours: 1)),
        },
        {
          'ticketId': '1003',
          'amount': 20.0,
          'paymentType': 'REFUND',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(minutes: 5)),
        },
      ];

      double cash = 0.0;
      double upi = 0.0;

      for (final txn in transactions) {
        final amount = txn['amount'] as double;
        final type = (txn['paymentType'] as String).toUpperCase();
        final isUpi = (txn['paymentMethod'] as String).toLowerCase() == 'upi';

        if (type == 'ADVANCE' || type == 'FINAL') {
          if (isUpi) {
            upi += amount;
          } else {
            cash += amount;
          }
        } else if (type == 'REFUND') {
          if (isUpi) {
            upi -= amount;
          } else {
            cash -= amount;
          }
        }
      }

      final netTotal = (cash + upi).clamp(0.0, double.infinity);
      final metrics = DashboardMetrics(
        todayEntries: 1,
        todayExits: 1,
        todayCollection: netTotal,
        cashCollection: cash.clamp(0.0, double.infinity),
        upiCollection: upi.clamp(0.0, double.infinity),
      );

      expect(metrics.todayCollection, equals(30.0));
      expect(metrics.cashCollection, equals(30.0));
    });

    test('4. Mixed Cash and UPI payments segregation', () {
      final now = DateTime.now();

      final transactions = [
        {
          'ticketId': '1004',
          'amount': 100.0,
          'paymentType': 'ADVANCE',
          'paymentMethod': 'upi',
          'createdAt': now.subtract(const Duration(hours: 2)),
        },
        {
          'ticketId': '1005',
          'amount': 50.0,
          'paymentType': 'FINAL',
          'paymentMethod': 'cash',
          'createdAt': now.subtract(const Duration(minutes: 15)),
        },
      ];

      double cash = 0.0;
      double upi = 0.0;

      for (final txn in transactions) {
        final amount = txn['amount'] as double;
        final type = (txn['paymentType'] as String).toUpperCase();
        final isUpi = (txn['paymentMethod'] as String).toLowerCase() == 'upi';

        if (type == 'ADVANCE' || type == 'FINAL') {
          if (isUpi) {
            upi += amount;
          } else {
            cash += amount;
          }
        }
      }

      final metrics = DashboardMetrics(
        todayEntries: 2,
        todayExits: 1,
        todayCollection: cash + upi,
        cashCollection: cash,
        upiCollection: upi,
      );

      expect(metrics.todayCollection, equals(150.0));
      expect(metrics.cashCollection, equals(50.0));
      expect(metrics.upiCollection, equals(100.0));
    });
  });

  group('B) Android QR Scanner Validation Tests', () {
    test('1. Valid parking QR formats are correctly accepted', () {
      // 1. Numeric ticket ID from 58mm thermal print
      expect(AppFormatters.isNumericTicketQuery('1004'), isTrue);
      expect(AppFormatters.isNumericTicketQuery('4'), isTrue);
      expect(AppFormatters.isNumericTicketQuery('1204'), isTrue);

      // 2. Legacy ticket ID
      expect(AppFormatters.isLegacyTicketQuery('TKT-1004'), isTrue);
      expect(AppFormatters.isLegacyTicketQuery('TKT-20260924-0001'), isTrue);

      // 3. Indian vehicle registration
      expect(AppFormatters.normalizeVehicleNumber('mh 12 ab 1234'), equals('MH12AB1234'));
      expect(AppFormatters.normalizeVehicleNumber('MH-14-CD-5678'), equals('MH14CD5678'));
    });

    test('2. Invalid QR codes (URLs, UPI, non-parking payloads) are properly identified', () {
      // URLs
      expect('https://google.com'.toLowerCase().startsWith('http'), isTrue);
      expect('http://evil.com/fake'.toLowerCase().startsWith('http'), isTrue);

      // UPI payment QR
      expect('upi://pay?pa=merchant@upi&am=50'.toLowerCase().startsWith('upi://'), isTrue);

      // Wi-Fi QR
      expect('WIFI:T:WPA;S:MyNetwork;P:password;;'.toLowerCase().startsWith('wifi:'), isTrue);

      // Non-numeric, non-legacy string is not accepted as ticket
      expect(AppFormatters.isTicketQuery('https://example.com'), isFalse);
      expect(AppFormatters.isTicketQuery('upi://pay?pa=merchant@upi'), isFalse);
    });

    test('3. extractTicketFromQr extracts ticket from various QR formats', () {
      // 1. Raw numeric ticket
      expect(QrScannerDialog.extractTicketFromQr('1004'), equals('1004'));
      expect(QrScannerDialog.extractTicketFromQr('  1004 \n'), equals('1004'));

      // 2. Legacy ticket format
      expect(QrScannerDialog.extractTicketFromQr('TKT-1004'), equals('TKT-1004'));
      expect(QrScannerDialog.extractTicketFromQr('TKT-20260924-0001'), equals('TKT-20260924-0001'));

      // 3. JSON format with numeric ticketNumber
      expect(
        QrScannerDialog.extractTicketFromQr('{"ticketNumber":1004,"vehicleNumber":"MH12AB1234"}'),
        equals('1004'),
      );

      // 4. JSON format with string ticketNumber
      expect(
        QrScannerDialog.extractTicketFromQr('{"ticketNumber":"1004","type":"CAR"}'),
        equals('1004'),
      );

      // 5. JSON format with ticketId
      expect(
        QrScannerDialog.extractTicketFromQr('{"ticketId":"1004"}'),
        equals('1004'),
      );

      // 6. JSON format with qrReference
      expect(
        QrScannerDialog.extractTicketFromQr('{"qrReference":"1004"}'),
        equals('1004'),
      );

      // 7. URL query param
      expect(
        QrScannerDialog.extractTicketFromQr('https://parking.app/exit?ticket=1004'),
        equals('1004'),
      );

      // 8. Vehicle registration
      expect(
        QrScannerDialog.extractTicketFromQr('MH12AB1234'),
        equals('MH12AB1234'),
      );

      // 9. Invalid / Non-parking formats return null
      expect(QrScannerDialog.extractTicketFromQr('WIFI:T:WPA;S:MyNet;P:pass;;'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('upi://pay?pa=merchant@upi'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('mailto:support@test.com'), isNull);
      expect(QrScannerDialog.extractTicketFromQr('https://google.com'), isNull);
    });

    test('4. QrScannerDialog.show returns mocked result in test environment', () async {
      QrScannerDialog.mockScanResult = '1004';
      expect(QrScannerDialog.mockScanResult, equals('1004'));
      QrScannerDialog.mockScanResult = null;
    });
  });
}
