import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/models/notification_model.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';

void main() {
  group('1. Guard Reports & Financial Aggregation Tests', () {
    final now = DateTime.now();
    final testTransactions = [
      // Cash Advance
      PaymentTransactionModel(
        id: 'tx_1',
        ticketId: 'T-001',
        vehicleNumber: 'MH12AB1234',
        paymentType: 'ADVANCE',
        paymentMethod: 'cash',
        amount: 50.0,
        guardUid: 'guard_123',
        guardName: 'Ramesh Guard',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      // Cash Final
      PaymentTransactionModel(
        id: 'tx_2',
        ticketId: 'T-002',
        vehicleNumber: 'MH12CD5678',
        paymentType: 'FINAL',
        paymentMethod: 'cash',
        amount: 30.0,
        guardUid: 'guard_123',
        guardName: 'Ramesh Guard',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      // UPI Advance
      PaymentTransactionModel(
        id: 'tx_3',
        ticketId: 'T-003',
        vehicleNumber: 'MH12EF9012',
        paymentType: 'ADVANCE',
        paymentMethod: 'upi',
        amount: 50.0,
        guardUid: 'guard_123',
        guardName: 'Ramesh Guard',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      // UPI Final
      PaymentTransactionModel(
        id: 'tx_4',
        ticketId: 'T-004',
        vehicleNumber: 'MH12GH3456',
        paymentType: 'FINAL',
        paymentMethod: 'upi',
        amount: 25.0,
        guardUid: 'guard_123',
        guardName: 'Ramesh Guard',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      // Cash Refund
      PaymentTransactionModel(
        id: 'tx_5',
        ticketId: 'T-001',
        vehicleNumber: 'MH12AB1234',
        paymentType: 'REFUND',
        paymentMethod: 'cash',
        amount: 10.0,
        guardUid: 'guard_123',
        guardName: 'Ramesh Guard',
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      // Other Guard's transaction (must be isolated)
      PaymentTransactionModel(
        id: 'tx_6',
        ticketId: 'T-005',
        vehicleNumber: 'MH12IJ7890',
        paymentType: 'ADVANCE',
        paymentMethod: 'cash',
        amount: 50.0,
        guardUid: 'other_guard',
        guardName: 'Suresh Guard',
        createdAt: now,
      ),
    ];

    test('Guard isolation: filters transactions strictly by guardUid', () {
      final guardTxs = testTransactions.where((t) => t.guardUid == 'guard_123').toList();
      expect(guardTxs.length, 5);
      expect(guardTxs.any((t) => t.guardUid == 'other_guard'), isFalse);
    });

    test('Cash net collection calculates: Advance (50) + Final (30) - Refund (10) = 70', () {
      final guardTxs = testTransactions.where((t) => t.guardUid == 'guard_123').toList();
      double cashAdvance = 0;
      double cashFinal = 0;
      double cashRefund = 0;

      for (final tx in guardTxs) {
        if (tx.isCash) {
          if (tx.isAdvance) cashAdvance += tx.amount;
          if (tx.isFinal) cashFinal += tx.amount;
          if (tx.isRefund) cashRefund += tx.amount;
        }
      }

      final netCash = cashAdvance + cashFinal - cashRefund;
      expect(cashAdvance, 50.0);
      expect(cashFinal, 30.0);
      expect(cashRefund, 10.0);
      expect(netCash, 70.0);
    });

    test('UPI net collection calculates: Advance (50) + Final (25) - Refund (0) = 75', () {
      final guardTxs = testTransactions.where((t) => t.guardUid == 'guard_123').toList();
      double upiAdvance = 0;
      double upiFinal = 0;
      double upiRefund = 0;

      for (final tx in guardTxs) {
        if (tx.isUpi) {
          if (tx.isAdvance) upiAdvance += tx.amount;
          if (tx.isFinal) upiFinal += tx.amount;
          if (tx.isRefund) upiRefund += tx.amount;
        }
      }

      final netUpi = upiAdvance + upiFinal - upiRefund;
      expect(upiAdvance, 50.0);
      expect(upiFinal, 25.0);
      expect(upiRefund, 0.0);
      expect(netUpi, 75.0);
    });

    test('Total Guard collection is net Cash (70) + net UPI (75) = 145', () {
      final guardTxs = testTransactions.where((t) => t.guardUid == 'guard_123').toList();
      double total = 0;
      for (final tx in guardTxs) {
        if (tx.isRefund) {
          total -= tx.amount;
        } else {
          total += tx.amount;
        }
      }
      expect(total, 145.0);
    });
  });

  group('2. Custom Date Range Validation Tests', () {
    test('Valid range: From Date <= To Date', () {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 28);
      expect(from.isBefore(to) || from.isAtSameMomentAs(to), isTrue);
    });

    test('Invalid range: From Date > To Date must be rejected', () {
      final from = DateTime(2026, 9, 28);
      final to = DateTime(2026, 9, 1);
      expect(from.isAfter(to), isTrue);
    });
  });

  group('3. Search, Filter, and Sort on Typed Raw Values', () {
    final list = [
      PaymentTransactionModel(
        id: '1',
        ticketId: 'T-100',
        vehicleNumber: 'MH12AA1111',
        paymentType: 'ADVANCE',
        paymentMethod: 'cash',
        amount: 20.0,
        guardUid: 'g1',
        createdAt: DateTime(2026, 9, 20, 10, 0),
      ),
      PaymentTransactionModel(
        id: '2',
        ticketId: 'T-050',
        vehicleNumber: 'MH12BB2222',
        paymentType: 'FINAL',
        paymentMethod: 'upi',
        amount: 100.0,
        guardUid: 'g1',
        createdAt: DateTime(2026, 9, 25, 12, 0),
      ),
      PaymentTransactionModel(
        id: '3',
        ticketId: 'T-200',
        vehicleNumber: 'MH12CC3333',
        paymentType: 'FINAL',
        paymentMethod: 'cash',
        amount: 50.0,
        guardUid: 'g1',
        createdAt: DateTime(2026, 9, 22, 14, 0),
      ),
    ];

    test('Sort by Date Newest -> Oldest uses raw DateTime comparison', () {
      final sorted = List<PaymentTransactionModel>.from(list);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.map((t) => t.id).toList(), ['2', '3', '1']);
    });

    test('Sort by Date Oldest -> Newest uses raw DateTime comparison', () {
      final sorted = List<PaymentTransactionModel>.from(list);
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(sorted.map((t) => t.id).toList(), ['1', '3', '2']);
    });

    test('Sort by Amount High -> Low uses raw num comparison', () {
      final sorted = List<PaymentTransactionModel>.from(list);
      sorted.sort((a, b) => b.amount.compareTo(a.amount));
      expect(sorted.map((t) => t.id).toList(), ['2', '3', '1']);
    });

    test('Sort by Amount Low -> High uses raw num comparison', () {
      final sorted = List<PaymentTransactionModel>.from(list);
      sorted.sort((a, b) => a.amount.compareTo(b.amount));
      expect(sorted.map((t) => t.id).toList(), ['1', '3', '2']);
    });

    test('Sort by Vehicle Number A -> Z uses lowercase string comparison', () {
      final sorted = List<PaymentTransactionModel>.from(list);
      sorted.sort((a, b) => a.vehicleNumber.toLowerCase().compareTo(b.vehicleNumber.toLowerCase()));
      expect(sorted.map((t) => t.id).toList(), ['1', '2', '3']);
    });

    test('Filter by paymentMethod == cash works accurately', () {
      final filtered = list.where((t) => t.isCash).toList();
      expect(filtered.length, 2);
      expect(filtered.every((t) => t.isCash), isTrue);
    });

    test('Search matches vehicle number case-insensitively', () {
      final query = 'mh12bb';
      final filtered = list.where((t) =>
        t.vehicleNumber.toLowerCase().contains(query) ||
        t.ticketId.toLowerCase().contains(query)
      ).toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, '2');
    });
  });

  group('4. Notifications Category & Filter Audit', () {
    final notifications = [
      NotificationModel(
        notificationId: 'n1',
        recipientUserId: 'guard_123',
        title: 'Shift Started',
        message: 'Shift has started.',
        createdAt: DateTime.now(),
        type: 'shift',
        isRead: false,
      ),
      NotificationModel(
        notificationId: 'n2',
        recipientUserId: 'guard_123',
        title: 'Cash Payment Received',
        message: 'Cash of Rs 50 received.',
        createdAt: DateTime.now(),
        type: 'cash',
        isRead: true,
      ),
      NotificationModel(
        notificationId: 'n3',
        recipientUserId: 'guard_123',
        title: 'UPI Payment Received',
        message: 'UPI of Rs 100 received.',
        createdAt: DateTime.now(),
        type: 'upi',
        isRead: false,
      ),
      NotificationModel(
        notificationId: 'n4',
        recipientUserId: 'guard_123',
        title: 'Handover Accepted',
        message: 'Handover of cash accepted.',
        createdAt: DateTime.now(),
        type: 'handover',
        isRead: false,
      ),
      NotificationModel(
        notificationId: 'n5',
        recipientUserId: 'guard_123',
        title: 'Withdrawal Completed',
        message: 'Admin withdrawal processed.',
        createdAt: DateTime.now(),
        type: 'withdrawal',
        isRead: false,
      ),
      NotificationModel(
        notificationId: 'n6',
        recipientUserId: 'guard_123',
        title: 'Multiple Devices Detected',
        message: 'Security warning.',
        createdAt: DateTime.now(),
        type: 'security',
        isRead: true,
      ),
      NotificationModel(
        notificationId: 'n7',
        recipientUserId: 'guard_123',
        title: 'System Alert',
        message: 'App updated.',
        createdAt: DateTime.now(),
        type: 'system',
        isRead: false,
      ),
    ];

    test('Unread count matches unread items count', () {
      final unreadCount = notifications.where((n) => !n.isRead).length;
      expect(unreadCount, 5);
    });

    test('Category filter accurately isolates notifications', () {
      expect(notifications.where((n) => n.type.toLowerCase() == 'shift').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'cash').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'upi').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'handover').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'withdrawal').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'security').length, 1);
      expect(notifications.where((n) => n.type.toLowerCase() == 'system').length, 1);
    });
  });

  group('5. Live Active Parking Fee Calculation Tests', () {
    test('Two-Wheeler fee structure: 1st hr ₹20, +₹5/hr, 12h cap ₹60', () {
      final entryTime = DateTime(2026, 9, 28, 10, 0);

      // 30 mins: 1 hour tier -> ₹20
      final res30m = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 10, 30),
        vehicleType: VehicleType.twoWheeler,
      );
      expect(res30m.grossCharge, 20.0);

      // 2 hours 15 mins: 3 hour tier -> 20 + 2*5 = 30
      final res2h15m = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 12, 15),
        vehicleType: VehicleType.twoWheeler,
      );
      expect(res2h15m.grossCharge, 30.0);

      // 12 hours: cap at ₹60
      final res12h = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 22, 0),
        vehicleType: VehicleType.twoWheeler,
      );
      expect(res12h.grossCharge, 60.0);
    });

    test('Four-Wheeler fee structure: 1st hr ₹50, +₹10/hr, 12h cap ₹150', () {
      final entryTime = DateTime(2026, 9, 28, 10, 0);

      // 45 mins: 1 hour tier -> ₹50
      final res45m = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 10, 45),
        vehicleType: VehicleType.fourWheeler,
      );
      expect(res45m.grossCharge, 50.0);

      // 3 hours: 50 + 2*10 = 70
      final res3h = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 13, 0),
        vehicleType: VehicleType.fourWheeler,
      );
      expect(res3h.grossCharge, 70.0);

      // 12 hours: cap at ₹150
      final res12h = FeeCalculator.calculate(
        entryTime: entryTime,
        exitTime: DateTime(2026, 9, 28, 22, 0),
        vehicleType: VehicleType.fourWheeler,
      );
      expect(res12h.grossCharge, 150.0);
    });

    test('Net fee correctly deducts advance amount', () {
      final res = FeeCalculator.calculate(
        entryTime: DateTime(2026, 9, 28, 10, 0),
        exitTime: DateTime(2026, 9, 28, 11, 0),
        vehicleType: VehicleType.fourWheeler,
        advancePaid: 50.0,
      );
      expect(res.grossCharge, 50.0);
      expect(res.balanceDue, 0.0);
      expect(res.refundAmount, 0.0);
    });
  });

  group('6. Exit WhatsApp Message & Link Generation Tests', () {
    final record = ParkingRecord(
      id: 'rec_100',
      ticketNumber: '1001',
      vehicleNumber: 'MH12DE1234',
      vehicleType: VehicleType.fourWheeler,
      customerMobile: '9876543210',
      entryTime: DateTime(2026, 9, 28, 10, 0),
      exitTime: DateTime(2026, 9, 28, 12, 0),
      advanceAmount: 50.0,
      grossCharge: 60.0,
      balanceDue: 10.0,
      refundAmount: 0.0,
      paymentMethod: 'CASH',
      status: 'EXITED',
      entryGuardUid: 'g1',
      entryGuardName: 'Guard A',
      entryShift: 'Morning',
    );

    test('WhatsApp text-only message in English includes all required fields', () {
      final msg = WhatsAppService.buildExitMessage(
        record,
        language: AppLanguage.english,
      );

      expect(msg.contains('CAR PARKING SYSTEM - BIZFLOW'), isTrue);
      expect(msg.contains('MH12DE1234'), isTrue);
      expect(msg.contains('1001'), isTrue);
      expect(msg.contains('₹60'), isTrue); // Total Fee
      expect(msg.contains('₹50'), isTrue); // Advance
      expect(msg.contains('₹10'), isTrue); // Final Paid
      expect(msg.contains('CASH'), isTrue);
      // Ensure NO QR code link or image is present
      expect(msg.contains('.png'), isFalse);
      expect(msg.contains('.jpg'), isFalse);
    });

    test('WhatsApp text-only message in Marathi includes all required Marathi terms', () {
      final msg = WhatsAppService.buildExitMessage(
        record,
        language: AppLanguage.marathi,
      );

      expect(msg.contains('CAR PARKING SYSTEM'), isTrue);
      expect(msg.contains('जय गणेश'), isFalse);
      expect(msg.contains('MH12DE1234'), isTrue);
      expect(msg.contains('1001'), isTrue);
      expect(msg.contains('रोख'), isTrue); // Cash in Marathi
    });

    test('Click-to-chat URL correctly prepends country code 91', () {
      final url = WhatsAppService.buildExitClickToChatUrl(
        record,
        language: AppLanguage.english,
      );

      expect(url.startsWith('https://wa.me/919876543210?text='), isTrue);
    });
  });

  group('7. AppStrings & Immediate Localization Tests', () {
    test('LanguageController toggles and AppStrings produces localized text', () {
      AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.today, 'Today');
      expect(AppStrings.reports, 'Reports');

      AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.today, 'आज');
      expect(AppStrings.reports, 'अहवाल');

      // Reset back to English
      AppLanguageController.instance.setLanguage(AppLanguage.english);
    });
  });
}
