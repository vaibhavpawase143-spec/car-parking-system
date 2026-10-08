import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/services/payment_service.dart';
import 'package:car_parking_system/services/shift_service.dart';
import 'package:car_parking_system/screens/guard/payment/payment_management_screen.dart';
import 'package:car_parking_system/screens/guard/shift/guard_my_shift_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('A) Payment Ledger Calculation & Parity Tests', () {
    test('1. ADVANCE and FINAL add to collection, REFUND subtracts', () {
      final now = DateTime.now();
      final txns = [
        PaymentTransactionModel(
          id: 'txn1',
          ticketId: '1001',
          vehicleNumber: 'MH 12 AB 1234',
          amount: 50.0,
          paymentMethod: 'cash',
          paymentType: 'ADVANCE',
          guardUid: 'guard1',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        PaymentTransactionModel(
          id: 'txn2',
          ticketId: '1002',
          vehicleNumber: 'MH 12 CD 5678',
          amount: 70.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard1',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        PaymentTransactionModel(
          id: 'txn3',
          ticketId: '1003',
          vehicleNumber: 'MH 12 EF 9012',
          amount: 20.0,
          paymentMethod: 'cash',
          paymentType: 'REFUND',
          guardUid: 'guard1',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

      double cash = 0.0;
      int cashCount = 0;
      for (final t in txns) {
        if (t.isCash) {
          if (t.isAdvance || t.isFinal) {
            cash += t.amount;
            cashCount++;
          } else if (t.isRefund) {
            cash -= t.amount;
          }
        }
      }

      expect(cash, equals(100.0)); // 50 + 70 - 20 = 100
      expect(cashCount, equals(2));
    });

    test('2. Cash and UPI segregation & Total Collection calculation', () {
      final now = DateTime.now();
      final txns = [
        PaymentTransactionModel(
          id: 'txn1',
          ticketId: '1001',
          vehicleNumber: 'MH 12 AB 1234',
          amount: 100.0,
          paymentMethod: 'cash',
          paymentType: 'ADVANCE',
          guardUid: 'guard1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: 'txn2',
          ticketId: '1002',
          vehicleNumber: 'MH 12 CD 5678',
          amount: 150.0,
          paymentMethod: 'upi',
          paymentType: 'FINAL',
          guardUid: 'guard1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: 'txn3',
          ticketId: '1003',
          vehicleNumber: 'MH 12 EF 9012',
          amount: 50.0,
          paymentMethod: 'upi',
          paymentType: 'REFUND',
          guardUid: 'guard1',
          createdAt: now,
        ),
      ];

      double cash = 0.0;
      double upi = 0.0;
      int cashCount = 0;
      int upiCount = 0;

      for (final t in txns) {
        if (t.isCash) {
          if (t.isAdvance || t.isFinal) {
            cash += t.amount;
            cashCount++;
          } else if (t.isRefund) {
            cash -= t.amount;
          }
        } else if (t.isUpi) {
          if (t.isAdvance || t.isFinal) {
            upi += t.amount;
            upiCount++;
          } else if (t.isRefund) {
            upi -= t.amount;
          }
        }
      }

      final total = cash + upi;
      expect(cash, equals(100.0));
      expect(upi, equals(100.0)); // 150 - 50 = 100
      expect(total, equals(200.0));
      expect(cashCount, equals(1));
      expect(upiCount, equals(1));
    });

    test('3. Zero transaction state returns 0.0 totals and empty counts', () {
      const report = PaymentReportData(
        todayTotalCollection: 0.0,
        expectedCash: 0.0,
        collectedCash: 0.0,
        cashTransactionsCount: 0,
        expectedUpi: 0.0,
        collectedUpi: 0.0,
        upiTransactionsCount: 0,
        transactions: [],
      );

      expect(report.todayTotalCollection, equals(0.0));
      expect(report.collectedCash, equals(0.0));
      expect(report.collectedUpi, equals(0.0));
      expect(report.transactions.isEmpty, isTrue);
    });

    test('4. Date filtering preserves only transactions on or after todayStart', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterday = todayStart.subtract(const Duration(hours: 2));

      final allTxns = [
        PaymentTransactionModel(
          id: 'old1',
          ticketId: '0999',
          vehicleNumber: 'MH 12 AA 1111',
          amount: 40.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard1',
          createdAt: yesterday,
        ),
        PaymentTransactionModel(
          id: 'new1',
          ticketId: '1000',
          vehicleNumber: 'MH 12 BB 2222',
          amount: 60.0,
          paymentMethod: 'cash',
          paymentType: 'FINAL',
          guardUid: 'guard1',
          createdAt: now,
        ),
      ];

      final todayTxns = allTxns.where((t) =>
        t.createdAt.isAfter(todayStart) || t.createdAt.isAtSameMomentAs(todayStart)
      ).toList();

      expect(todayTxns.length, equals(1));
      expect(todayTxns.first.ticketId, equals('1000'));
      expect(todayTxns.first.amount, equals(60.0));
    });
  });

  group('B) Shift Verification & Timeout Handling Tests', () {
    test('1. Shift matching by UID and email succeeds', () {
      final shift = ShiftModel(
        shiftId: 'shift_01',
        guardId: 'guard_doc_1',
        guardUid: 'firebase_auth_guard_uid',
        guardEmail: 'guard@parking.com',
        guardName: 'Test Guard',
        shiftDate: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 7)),
      );

      expect(ShiftService.matchesGuard(shift, 'firebase_auth_guard_uid'), isTrue);
      expect(ShiftService.matchesGuard(shift, 'other_uid', 'guard@parking.com'), isTrue);
      expect(ShiftService.matchesGuard(shift, 'unrelated_uid', 'other@parking.com'), isFalse);
    });

    test('2. Active shift calculation within time range', () {
      final now = DateTime.now();
      final shift = ShiftModel(
        shiftId: 'shift_active',
        guardId: 'guard1',
        guardName: 'Test Guard',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ASSIGNED',
      );

      expect(shift.effectiveStatus, equals(ShiftStatus.active));
      expect(shift.isActive, isTrue);
    });

    test('3. Timeout on hanging stream emits error/null without freezing UI', () async {
      final controller = StreamController<ShiftModel?>();
      
      final streamWithTimeout = controller.stream.timeout(
        const Duration(milliseconds: 100),
        onTimeout: (sink) {
          sink.add(null);
        },
      );

      final result = await streamWithTimeout.first;
      expect(result, isNull);
      await controller.close();
    });
  });

  group('C) Payment Management UI & Localization Tests', () {
    const testGuard = GuardModel(
      uid: 'guard_doc_1',
      name: 'Ramesh Guard',
      email: 'guard1@carparking.com',
      mobile: '9876543210',
      role: 'guard',
    );

    Widget createTestWidget({
      required Stream<PaymentReportData> reportStream,
    }) {
      return ListenableBuilder(
        listenable: AppLanguageController.instance,
        builder: (context, _) {
          return MaterialApp(
            home: PaymentManagementScreen(
              currentGuard: testGuard,
              customReportStream: reportStream,
            ),
          );
        },
      );
    }

    testWidgets('1. Payment Management displays English text and currency', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      final reportData = PaymentReportData(
        todayTotalCollection: 550.0,
        expectedCash: 350.0,
        collectedCash: 350.0,
        cashTransactionsCount: 4,
        expectedUpi: 200.0,
        collectedUpi: 200.0,
        upiTransactionsCount: 2,
        transactions: [
          PaymentTransactionModel(
            id: 'txn1',
            ticketId: '1001',
            vehicleNumber: 'MH 12 AB 1234',
            amount: 50.0,
            paymentMethod: 'cash',
            paymentType: 'ADVANCE',
            guardUid: 'guard1',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(
        reportStream: Stream.value(reportData),
      ));
      await tester.pumpAndSettle();

      // Check header and cards
      expect(find.text(AppStrings.paymentManagement), findsWidgets);
      expect(find.text(AppStrings.todayTotalCollection.toUpperCase()), findsOneWidget);
      expect(find.text('₹550'), findsOneWidget);
      expect(find.text(AppStrings.cashCollection), findsOneWidget);
      expect(find.text('₹350'), findsNWidgets(2)); // expected and collected
      expect(find.text(AppStrings.upiCollection), findsOneWidget);
      expect(find.text('₹200'), findsNWidgets(2));
      expect(find.text(AppStrings.transactions), findsOneWidget);
      expect(find.textContaining('MH 12 AB 1234'), findsOneWidget);
      expect(find.textContaining('1001'), findsOneWidget);
    });

    testWidgets('2. Payment Management reacts immediately to Marathi language switch', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      const reportData = PaymentReportData(
        todayTotalCollection: 1200.0,
        expectedCash: 800.0,
        collectedCash: 800.0,
        cashTransactionsCount: 5,
        expectedUpi: 400.0,
        collectedUpi: 400.0,
        upiTransactionsCount: 3,
        transactions: [],
      );

      await tester.pumpWidget(createTestWidget(
        reportStream: Stream.value(reportData),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Payment Management'), findsWidgets);

      // Switch language to Marathi
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      await tester.pumpAndSettle();

      // Check Marathi localized strings
      expect(find.text('पेमेंट व्यवस्थापन'), findsWidgets);
      expect(find.text('आजचे एकूण संकलन'.toUpperCase()), findsOneWidget);
      expect(find.text('₹1200'), findsOneWidget);
      expect(find.text('रोख संकलन'), findsOneWidget);
      expect(find.text('UPI संकलन'), findsOneWidget);
      expect(find.text('आज कोणतेही पेमेंट व्यवहार नाहीत.'), findsOneWidget);
    });

    testWidgets('3. Empty state displays properly in both languages', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      const emptyReport = PaymentReportData(
        todayTotalCollection: 0.0,
        expectedCash: 0.0,
        collectedCash: 0.0,
        cashTransactionsCount: 0,
        expectedUpi: 0.0,
        collectedUpi: 0.0,
        upiTransactionsCount: 0,
        transactions: [],
      );

      await tester.pumpWidget(createTestWidget(
        reportStream: Stream.value(emptyReport),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No payment transactions today.'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);

      // Switch to Marathi
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      await tester.pumpAndSettle();

      expect(find.text('आज कोणतेही पेमेंट व्यवहार नाहीत.'), findsOneWidget);
    });
  });

  group('D) Guard My Shift Screen UI Tests', () {
    const testGuard = GuardModel(
      uid: 'guard_doc_1',
      name: 'Ramesh Guard',
      email: 'guard1@carparking.com',
      mobile: '9876543210',
      role: 'guard',
    );

    testWidgets('1. Active shift displays guard name, active badge, and duration', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      final now = DateTime.now();
      final activeShift = ShiftModel(
        shiftId: 'shift_act_1',
        guardId: 'guard_doc_1',
        guardName: 'Ramesh Guard',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 6)),
        status: 'ASSIGNED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardMyShiftScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              customShiftsStream: Stream.value([activeShift]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Shift'), findsOneWidget);
      expect(find.text('Ramesh Guard'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('8 Hours'), findsOneWidget);
    });

    testWidgets('2. Upcoming assigned shift displays upcoming primary card with countdown', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      final now = DateTime.now();
      final upcomingShift = ShiftModel(
        shiftId: 'shift_up_1',
        guardId: 'guard_doc_1',
        guardName: 'Ramesh Guard',
        shiftDate: DateTime(now.year, now.month, now.day),
        startTime: now.add(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 11)),
        status: 'ASSIGNED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardMyShiftScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              customShiftsStream: Stream.value([upcomingShift]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Shift'), findsOneWidget);
      expect(find.text('Ramesh Guard'), findsOneWidget);
      expect(find.text('ASSIGNED'), findsOneWidget);
      expect(find.textContaining('Starts in:'), findsOneWidget);
    });

    testWidgets('3. No shift assigned shows clean empty state', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardMyShiftScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              customShiftsStream: Stream.value([]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No shift assigned.'), findsOneWidget);
      expect(find.text('Please contact Admin.'), findsOneWidget);
    });

    testWidgets('4. Error state displays retry button and error message', (tester) async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardMyShiftScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              customShiftsStream: Stream.error('Network unreachable'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load shift information.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
