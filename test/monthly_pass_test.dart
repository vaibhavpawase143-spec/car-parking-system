import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/core/utils/fee_calculator.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/services/receipt_print_service.dart';
import 'package:car_parking_system/services/whatsapp_service.dart';

void main() {
  group('Monthly Pass Model & Fixed Price Tests', () {
    test('MonthlyPassModel enforces fixed ₹600 amount and full payment in advance', () {
      final now = DateTime.now();
      final pass = MonthlyPassModel(
        id: 'PASS-2026-001',
        passNumber: 'PASS-2026-001',
        vehicleNumber: 'MH 15 AB 1234',
        normalizedVehicleNumber: AppFormatters.normalizeVehicleNumber('MH 15 AB 1234'),
        vehicleType: VehicleType.twoWheeler,
        customerName: 'Ramesh Patil',
        customerMobile: '9876543210',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 28)),
        amount: MonthlyPassModel.fixedPrice,
        amountPaid: MonthlyPassModel.fixedPrice,
        paymentStatus: 'PAID',
        paymentMethod: 'CASH',
        status: 'ACTIVE',
        createdAt: now,
        createdBy: 'ADMIN',
      );

      expect(MonthlyPassModel.fixedPrice, 600.0);
      expect(pass.amount, 600.0);
      expect(pass.amountPaid, 600.0);
      expect(pass.outstandingAmount, 0.0);
      expect(pass.isFullyPaid, isTrue);
      expect(pass.paymentStatus, 'PAID');
      expect(pass.normalizedVehicleNumber, 'MH15AB1234');
    });

    test('MonthlyPassModel status calculation works dynamically', () {
      final now = DateTime.now();

      // Active pass (started 5 days ago, expires in 25 days)
      final activePass = MonthlyPassModel(
        id: 'PASS-1',
        passNumber: 'PASS-1',
        vehicleNumber: 'MH15AB1234',
        normalizedVehicleNumber: 'MH15AB1234',
        vehicleType: VehicleType.twoWheeler,
        customerName: 'Test',
        customerMobile: '9999999999',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        status: 'ACTIVE',
        createdAt: now,
        createdBy: 'ADMIN',
      );
      expect(activePass.dynamicStatus, 'ACTIVE');
      expect(activePass.isValidAt(now), isTrue);

      // Upcoming pass (starts 2 days from now)
      final upcomingPass = activePass.copyWith(
        startDate: now.add(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 32)),
      );
      expect(upcomingPass.dynamicStatus, 'UPCOMING');
      expect(upcomingPass.isValidAt(now), isFalse);

      // Expired pass (ended 1 day ago)
      final expiredPass = activePass.copyWith(
        startDate: now.subtract(const Duration(days: 31)),
        endDate: now.subtract(const Duration(days: 1)),
      );
      expect(expiredPass.dynamicStatus, 'EXPIRED');
      expect(expiredPass.isValidAt(now), isFalse);

      // Expiring soon (expires in 4 days, within 7 days window)
      final expiringSoonPass = activePass.copyWith(
        startDate: now.subtract(const Duration(days: 26)),
        endDate: now.add(const Duration(days: 4)),
      );
      expect(expiringSoonPass.isExpiringSoon, isTrue);
    });

    test('Firestore serialization and deserialization preserves all values', () {
      final now = DateTime(2026, 10, 1, 10, 0);
      final pass = MonthlyPassModel(
        id: 'PASS-2026-099',
        passNumber: 'PASS-2026-099',
        vehicleNumber: 'MH 12 CD 5678',
        normalizedVehicleNumber: 'MH12CD5678',
        vehicleType: VehicleType.fourWheeler,
        customerName: 'Suresh Kumar',
        customerMobile: '9812345678',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31, 23, 59, 59),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        status: 'ACTIVE',
        createdAt: now,
        createdBy: 'admin_uid',
      );

      final map = pass.toFirestore();
      expect(map['passNumber'], 'PASS-2026-099');
      expect(map['amount'], 600.0);
      expect(map['amountPaid'], 600.0);
      expect(map['outstandingAmount'], 0.0);
      expect(map['paymentStatus'], 'PAID');
      expect(map['vehicleType'], 'fourWheeler');

      final fromMap = MonthlyPassModel.fromMap(map, 'PASS-2026-099');
      expect(fromMap.passNumber, 'PASS-2026-099');
      expect(fromMap.amount, 600.0);
      expect(fromMap.amountPaid, 600.0);
      expect(fromMap.outstandingAmount, 0.0);
      expect(fromMap.paymentStatus, 'PAID');
      expect(fromMap.paymentMethod, 'upi');
    });
  });

  group('FeeCalculator & Parking Logic Tests', () {
    test('Vehicle WITH valid Monthly Pass always incurs ₹0 parking fee', () {
      final entryTime = DateTime(2026, 10, 1, 10, 0);
      final exitTime = DateTime(2026, 10, 1, 18, 0); // 8 hours parked

      final resultTwoWheeler = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: entryTime,
        exitTime: exitTime,
        isMonthlyPass: true,
      );

      expect(resultTwoWheeler.grossCharge, 0.0);
      expect(resultTwoWheeler.balanceDue, 0.0);
      expect(resultTwoWheeler.billableHours, 0);

      final resultFourWheeler = FeeCalculator.calculate(
        vehicleType: VehicleType.fourWheeler,
        entryTime: entryTime,
        exitTime: exitTime,
        isMonthlyPass: true,
      );

      expect(resultFourWheeler.grossCharge, 0.0);
      expect(resultFourWheeler.balanceDue, 0.0);
      expect(resultFourWheeler.billableHours, 0);
    });

    test('Vehicle WITHOUT Monthly Pass (or expired/upcoming) uses standard rate engine', () {
      final entryTime = DateTime(2026, 10, 1, 10, 0);
      final exitTime = DateTime(2026, 10, 1, 12, 0); // 2 hours

      final result = FeeCalculator.calculate(
        vehicleType: VehicleType.twoWheeler,
        entryTime: entryTime,
        exitTime: exitTime,
        isMonthlyPass: false,
      );

      expect(result.grossCharge, 25.0); // 2 hours standard rate: 15 + 10 = 25
      expect(result.balanceDue, 25.0);
    });
  });

  group('Vehicle Normalization Tests', () {
    test('Normalizes various vehicle number formats consistently', () {
      expect(AppFormatters.normalizeVehicleNumber('mh 15 ab 1234'), 'MH15AB1234');
      expect(AppFormatters.normalizeVehicleNumber('MH-15-AB-1234'), 'MH15AB1234');
      expect(AppFormatters.normalizeVehicleNumber('MH 15  AB  1234'), 'MH15AB1234');
      expect(AppFormatters.normalizeVehicleNumber('mh15ab1234'), 'MH15AB1234');
    });
  });

  group('Thermal Pass Receipt & WhatsApp Text Format Tests', () {
    test('Receipt contains required header, fixed ₹600 amount, and PAID status', () {
      final pass = MonthlyPassModel(
        id: 'PASS-2026-001',
        passNumber: 'PASS-2026-001',
        vehicleNumber: 'MH 15 AB 1234',
        normalizedVehicleNumber: 'MH15AB1234',
        vehicleType: VehicleType.twoWheeler,
        customerName: 'Ramesh Patil',
        customerMobile: '9876543210',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31, 23, 59, 59),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'CASH',
        status: 'ACTIVE',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        createdBy: 'ADMIN',
      );

      final html = ReceiptPrintService.buildMonthlyPassReceiptHtml(pass);

      expect(html.contains('JAY GANESH PAY & PARK'), isTrue);
      expect(html.contains('CAR PARKING SYSTEM'), isTrue);
      expect(html.contains('BIZFLOW'), isTrue);
      expect(html.contains('Monthly Pass'), isTrue);
      expect(html.contains('PASS-2026-001'), isTrue);
      expect(html.contains('MH15AB1234'), isTrue);
      expect(html.contains('Two-Wheeler'), isTrue);
      expect(html.contains('Ramesh Patil'), isTrue);
      expect(html.contains('9876543210'), isTrue);
      expect(html.contains('600'), isTrue);
      expect(html.contains('PAID'), isTrue);
      expect(html.contains('CASH'), isTrue);
      // Ensure no partial or balance mentions
      expect(html.contains('Balance Due'), isFalse);
      expect(html.contains('Pending'), isFalse);
    });

    test('WhatsApp confirmation message contains required plain text details', () {
      final pass = MonthlyPassModel(
        id: 'PASS-2026-002',
        passNumber: 'PASS-2026-002',
        vehicleNumber: 'MH 15 XY 9999',
        normalizedVehicleNumber: 'MH15XY9999',
        vehicleType: VehicleType.fourWheeler,
        customerName: 'Ganesh Shinde',
        customerMobile: '9822001122',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31, 23, 59, 59),
        amount: 600.0,
        amountPaid: 600.0,
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        status: 'ACTIVE',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        createdBy: 'ADMIN',
      );

      final message = WhatsAppService.buildMonthlyPassMessage(pass);

      expect(message.contains('JAY GANESH PAY & PARK'), isTrue);
      expect(message.contains('Monthly Pass'), isTrue);
      expect(message.contains('CAR PARKING SYSTEM'), isTrue);
      expect(message.contains('BIZFLOW'), isTrue);
      expect(message.contains('PASS-2026-002'), isTrue);
      expect(message.contains('MH15XY9999'), isTrue);
      expect(message.contains('Four-Wheeler'), isTrue);
      expect(message.contains('600'), isTrue);
      expect(message.contains('PAID'), isTrue);
    });
  });

  group('Localization Coverage Tests', () {
    test('All Monthly Pass keys change correctly between English and Marathi', () {
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.monthlyPasses, 'Monthly Passes');
      expect(AppStrings.monthlyPassManagement, 'Monthly Pass Management');
      expect(AppStrings.createMonthlyPass, 'Create Monthly Pass');
      expect(AppStrings.activePasses, 'Active Passes');
      expect(AppStrings.expiringSoon, 'Expiring Soon');
      expect(AppStrings.expiredPasses, 'Expired Passes');
      expect(AppStrings.passCollection, 'Pass Collection');
      expect(AppStrings.pay600AndCreatePass, 'Pay ₹600 & Create Pass');
      expect(AppStrings.fullPaymentInAdvance, 'FULL ₹600 IN ADVANCE');
      expect(AppStrings.appName, 'CAR PARKING SYSTEM');
      expect(AppStrings.companyBrand, 'BIZFLOW');
      expect(AppStrings.adminPortal, 'ADMIN PORTAL');

      AppStrings.setLanguage(AppLanguage.marathi);
      expect(AppStrings.monthlyPasses, 'मासिक पासेस');
      expect(AppStrings.monthlyPassManagement, 'मासिक पास व्यवस्थापन');
      expect(AppStrings.createMonthlyPass, 'मासिक पास तयार करा');
      expect(AppStrings.activePasses, 'सक्रिय पासेस');
      expect(AppStrings.expiringSoon, 'लवकरच संपणारे');
      expect(AppStrings.expiredPasses, 'मुदत संपलेले पासेस');
      expect(AppStrings.passCollection, 'पास संकलन');
      expect(AppStrings.pay600AndCreatePass, '₹६०० भरा आणि पास तयार करा');
      expect(AppStrings.fullPaymentInAdvance, 'संपूर्ण ₹६०० आगाऊ रक्कम');

      // Fixed brand identifiers remain English
      expect(AppStrings.appName, 'CAR PARKING SYSTEM');
      expect(AppStrings.companyBrand, 'BIZFLOW');
      expect(AppStrings.adminPortal, 'ADMIN PORTAL');

      // Reset to English
      AppStrings.setLanguage(AppLanguage.english);
    });
  });
}
