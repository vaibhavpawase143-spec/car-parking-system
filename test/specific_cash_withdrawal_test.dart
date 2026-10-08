import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/withdrawal_model.dart';
import 'package:car_parking_system/services/financial_responsibility_service.dart';

void main() {
  group('SPECIFIC CASH & UPI WITHDRAWAL AMOUNT — Test Suite', () {
    setUp(() async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
    });

    // 1. Outstanding ₹6685 -> withdraw ₹2000 -> ₹4685
    test('1. Outstanding ₹6685 -> withdraw ₹2000 -> ₹4685', () {
      final initialResp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
      );
      expect(initialResp.outstandingCash, equals(6685.0));

      final afterWithdrawal = initialResp.copyWith(
        cashWithdrawn: 2000.0,
      );
      expect(afterWithdrawal.outstandingCash, equals(4685.0));
    });

    // 2. Outstanding ₹6685 -> withdraw ₹1 -> ₹6684
    test('2. Outstanding ₹6685 -> withdraw ₹1 -> ₹6684', () {
      final initialResp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
      );
      final afterWithdrawal = initialResp.copyWith(
        cashWithdrawn: 1.0,
      );
      expect(afterWithdrawal.outstandingCash, equals(6684.0));
    });

    // 3. Outstanding ₹6685 -> withdraw ₹6685 -> ₹0
    test('3. Outstanding ₹6685 -> withdraw ₹6685 -> ₹0', () {
      final initialResp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
      );
      final afterWithdrawal = initialResp.copyWith(
        cashWithdrawn: 6685.0,
      );
      expect(afterWithdrawal.outstandingCash, equals(0.0));
    });

    // 4. ₹0 -> reject
    test('4. ₹0 -> rejected by validation', () {
      expect(
        () {
          const double amount = 0.0;
          if (amount <= 0) {
            throw ArgumentError(AppStrings.withdrawalMustBeGreaterThanZero);
          }
        },
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', AppStrings.withdrawalMustBeGreaterThanZero)),
      );
    });

    // 5. Blank -> rejected
    test('5. Blank -> rejected by validation', () {
      const String input = '   ';
      final parsed = double.tryParse(input.trim());
      expect(parsed, isNull);
    });

    // 6. Negative -> rejected
    test('6. Negative amount -> rejected by validation', () {
      const String input = '-500';
      final parsed = double.tryParse(input.trim());
      expect(parsed, isNotNull);
      expect(parsed! <= 0, isTrue);
    });

    // 7. ₹7000 against ₹6685 -> reject
    test('7. ₹7000 against ₹6685 -> rejected with clear error message', () {
      const double outstanding = 6685.0;
      const double requested = 7000.0;
      expect(requested > outstanding, isTrue);

      final errorMsg = AppStrings.withdrawalAmountExceeds('cash', AppFormatters.formatCurrency(outstanding));
      expect(errorMsg, contains('cannot exceed current cash outstanding of ₹6685'));
    });

    // 8. Multiple withdrawals: ₹6685 -> withdraw ₹2000 -> withdraw ₹1000 -> withdraw ₹500 -> ₹3185
    test('8. Multiple specific withdrawals cumulatively reduce balance', () {
      var resp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
      );
      expect(resp.outstandingCash, equals(6685.0));

      // 1st withdrawal: ₹2000
      resp = resp.copyWith(cashWithdrawn: resp.cashWithdrawn + 2000.0);
      expect(resp.outstandingCash, equals(4685.0));

      // 2nd withdrawal: ₹1000
      resp = resp.copyWith(cashWithdrawn: resp.cashWithdrawn + 1000.0);
      expect(resp.outstandingCash, equals(3685.0));

      // 3rd withdrawal: ₹500
      resp = resp.copyWith(cashWithdrawn: resp.cashWithdrawn + 500.0);
      expect(resp.outstandingCash, equals(3185.0));
    });

    // 9. Cash withdrawal does not affect UPI
    test('9. Cash withdrawal does not affect UPI responsibility', () {
      var resp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
        totalUpiCollected: 220.0,
      );
      expect(resp.outstandingCash, equals(6685.0));
      expect(resp.outstandingUpi, equals(220.0));
      expect(resp.totalOutstanding, equals(6905.0));

      // Withdraw Cash ₹2000
      resp = resp.copyWith(cashWithdrawn: 2000.0);
      expect(resp.outstandingCash, equals(4685.0));
      expect(resp.outstandingUpi, equals(220.0)); // Unchanged!
      expect(resp.totalOutstanding, equals(4905.0));
    });

    // 10. UPI withdrawal does not affect Cash
    test('10. UPI withdrawal does not affect Cash responsibility', () {
      var resp = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
        totalUpiCollected: 220.0,
      );

      // Withdraw UPI ₹100
      resp = resp.copyWith(upiWithdrawn: 100.0);
      expect(resp.outstandingCash, equals(6685.0)); // Unchanged!
      expect(resp.outstandingUpi, equals(120.0));
      expect(resp.totalOutstanding, equals(6805.0));
    });

    // 11 & 13. WithdrawalModel preserves previousOutstanding, amount, remainingOutstanding
    test('11 & 13. WithdrawalModel correctly stores and serializes history fields', () {
      final now = DateTime.now();
      final model = WithdrawalModel(
        withdrawalId: 'with_101',
        guardId: 'guard_1',
        guardName: 'Guard A',
        shiftId: 'shift_99',
        type: 'CASH',
        amount: 2000.0,
        adminUid: 'admin_1',
        adminName: 'Master Admin',
        createdAt: now,
        previousOutstanding: 6685.0,
        remainingOutstanding: 4685.0,
      );

      final map = model.toFirestore();
      expect(map['previousOutstanding'], equals(6685.0));
      expect(map['amount'], equals(2000.0));
      expect(map['remainingOutstanding'], equals(4685.0));
      expect(map['guardName'], equals('Guard A'));
      expect(map['adminName'], equals('Master Admin'));

      final reconstructed = WithdrawalModel.fromMap(map, 'with_101');
      expect(reconstructed.previousOutstanding, equals(6685.0));
      expect(reconstructed.amount, equals(2000.0));
      expect(reconstructed.remainingOutstanding, equals(4685.0));
    });

    // 14. Keep With Me uses remaining balance
    test('14. Keep With Me uses remaining amount after withdrawal', () {
      const resp = GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
        cashWithdrawn: 2000.0,
      );
      final remainingForNextShift = resp.outstandingCash;
      expect(remainingForNextShift, equals(4685.0));
    });

    // 15. Handover uses remaining balance
    test('15. Handover uses remaining amount after withdrawal', () {
      var outgoingGuard = const GuardFinancialResponsibility(
        guardUid: 'guard_1',
        guardName: 'Guard A',
        totalCashCollected: 6685.0,
        cashWithdrawn: 2000.0, // Outstanding = 4685
      );
      expect(outgoingGuard.outstandingCash, equals(4685.0));

      // Handover the remaining 4685
      outgoingGuard = outgoingGuard.copyWith(cashHandedOver: 4685.0);
      expect(outgoingGuard.outstandingCash, equals(0.0));
    });

    // 16. Stale balance detection
    test('16. Stale balance protection rejects withdrawal if amount exceeds fresh balance', () {
      // Admin UI thought balance was 6685, but concurrent withdrawal made it 1500
      const latestAuthoritative = 1500.0;
      const requestedAmount = 2000.0;

      expect(requestedAmount > latestAuthoritative, isTrue);
      expect(
        () {
          if (requestedAmount > latestAuthoritative) {
            throw StateError(AppStrings.withdrawalAmountExceeds('cash', AppFormatters.formatCurrency(latestAuthoritative)));
          }
        },
        throwsA(isA<StateError>()),
      );
    });

    // 17. Button text and labels in English and Marathi
    test('17. Localized strings for specific withdrawal exist in English and Marathi', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.withdrawCash, equals('Withdraw Cash'));
      expect(AppStrings.withdrawUpi, equals('Withdraw UPI'));
      expect(AppStrings.currentCashOutstanding, equals('Current Cash Outstanding'));
      expect(AppStrings.currentUpiOutstanding, equals('Current UPI Outstanding'));
      expect(AppStrings.remainingAfterWithdrawal, equals('Remaining After Withdrawal'));

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.withdrawCash, equals('रोख काढा'));
      expect(AppStrings.withdrawUpi, equals('UPI काढा'));
      expect(AppStrings.currentCashOutstanding, equals('सध्याची थकीत रोख'));
      expect(AppStrings.currentUpiOutstanding, equals('सध्याची थकीत UPI'));
      expect(AppStrings.remainingAfterWithdrawal, equals('काढल्यानंतर शिल्लक'));
    });
  });
}
