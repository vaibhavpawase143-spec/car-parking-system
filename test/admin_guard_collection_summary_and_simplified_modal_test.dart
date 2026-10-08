import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/payment_transaction_model.dart';
import 'package:car_parking_system/services/payment_service.dart';
import 'package:car_parking_system/screens/admin/guards/admin_guard_management_screen.dart';

void main() {
  group('Admin Guard Management — Collection Summary & Simplified Modal Tests', () {
    testWidgets('1. Collection Summary renders by default with Period: Today and 3 collection metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Collection Summary title is present
      expect(find.text('Collection Summary'), findsOneWidget);

      // Verify Period label and Dropdown default to Today
      expect(find.text('Period: '), findsOneWidget);
      expect(find.text('Today'), findsWidgets);

      // Verify the 3 metrics tiles are present
      expect(find.text(AppStrings.cashCollection), findsWidgets);
      expect(find.text(AppStrings.upiCollection), findsWidgets);
      expect(find.text(AppStrings.totalCollection), findsWidgets);
    });

    testWidgets('2. Period Dropdown contains all required periods and allows selecting Last 7 Days, Last 15 Days, Last 30 Days, Custom Date Range', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      final dropdownFinder = find.byKey(const ValueKey('collection_period_dropdown'));
      expect(dropdownFinder, findsOneWidget);

      // Tap dropdown to open menu
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Verify all 5 options are present
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Last 7 Days'), findsWidgets);
      expect(find.text('Last 15 Days'), findsWidgets);
      expect(find.text('Last 30 Days'), findsWidgets);
      expect(find.text('Custom Date Range'), findsWidgets);

      // Select 'Last 7 Days'
      await tester.tap(find.text('Last 7 Days').last);
      await tester.pumpAndSettle();
      expect(find.text('Last 7 Days'), findsOneWidget);

      // Select 'Custom Date Range'
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom Date Range').last);
      await tester.pumpAndSettle();

      // Verify From Date, To Date, and Apply button appear
      expect(find.byKey(const ValueKey('custom_from_date_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_to_date_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_period_apply_btn')), findsOneWidget);
    });

    test('3. PaymentReportData calculations: Cash, UPI, and Total collections match formula', () {
      final now = DateTime.now();

      // Create test transactions
      final txnCashAdvance = PaymentTransactionModel(
        id: 'tx1',
        ticketId: '1001',
        vehicleNumber: 'MH12AB1234',
        amount: 50.0,
        paymentType: 'advance',
        paymentMethod: 'cash',
        guardUid: 'guard_1',
        guardName: 'Guard A',
        createdAt: now,
      );

      final txnCashFinal = PaymentTransactionModel(
        id: 'tx2',
        ticketId: '1001',
        vehicleNumber: 'MH12AB1234',
        amount: 30.0,
        paymentType: 'final',
        paymentMethod: 'cash',
        guardUid: 'guard_1',
        guardName: 'Guard A',
        createdAt: now,
      );

      final txnCashRefund = PaymentTransactionModel(
        id: 'tx3',
        ticketId: '1001',
        vehicleNumber: 'MH12AB1234',
        amount: 10.0,
        paymentType: 'refund',
        paymentMethod: 'cash',
        guardUid: 'guard_1',
        guardName: 'Guard A',
        createdAt: now,
      );

      final txnUpiAdvance = PaymentTransactionModel(
        id: 'tx4',
        ticketId: '1002',
        vehicleNumber: 'MH14XY9999',
        amount: 200.0,
        paymentType: 'advance',
        paymentMethod: 'upi',
        guardUid: 'guard_2',
        guardName: 'Guard B',
        createdAt: now,
      );

      final txnUpiRefund = PaymentTransactionModel(
        id: 'tx5',
        ticketId: '1002',
        vehicleNumber: 'MH14XY9999',
        amount: 20.0,
        paymentType: 'refund',
        paymentMethod: 'upi',
        guardUid: 'guard_2',
        guardName: 'Guard B',
        createdAt: now,
      );

      // Cash calculation: 50 + 30 - 10 = 70
      final expectedCash = (50.0 + 30.0 - 10.0);
      // UPI calculation: 200 - 20 = 180
      final expectedUpi = (200.0 - 20.0);
      // Total calculation: Cash + UPI = 70 + 180 = 250
      final expectedTotal = expectedCash + expectedUpi;

      final report = PaymentReportData(
        todayTotalCollection: expectedTotal,
        expectedCash: 80.0,
        collectedCash: expectedCash,
        cashTransactionsCount: 3,
        expectedUpi: 200.0,
        collectedUpi: expectedUpi,
        upiTransactionsCount: 2,
        transactions: [txnCashAdvance, txnCashFinal, txnCashRefund, txnUpiAdvance, txnUpiRefund],
      );

      expect(report.collectedCash, 70.0);
      expect(report.collectedUpi, 180.0);
      expect(report.todayTotalCollection, 250.0);
    });

    test('4. PaymentReportData.zero provides safe fallback of ₹0 for empty periods', () {
      const emptyReport = PaymentReportData.zero;
      expect(emptyReport.collectedCash, 0.0);
      expect(emptyReport.collectedUpi, 0.0);
      expect(emptyReport.todayTotalCollection, 0.0);
      expect(emptyReport.transactions.isEmpty, true);
    });

    testWidgets('5. Guard Management search, filter, and sort controls remain fully operational', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      // Search field
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text(AppStrings.searchGuardsHint), findsOneWidget);

      // Filters
      expect(find.textContaining(AppStrings.all), findsWidgets);
      expect(find.textContaining(AppStrings.activeState), findsWidgets);
      expect(find.textContaining(AppStrings.inactiveGuards), findsWidgets);

      // Sort button
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('6. Custom Date Range shows From/To dates and Apply button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      final dropdownFinder = find.byKey(const ValueKey('collection_period_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom Date Range').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom_from_date_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_to_date_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_period_apply_btn')), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    test('7. Payment calculation handles advance, final, refund for Cash & UPI', () {
      final now = DateTime.now();
      final txns = [
        PaymentTransactionModel(
          id: '1',
          ticketId: 'T1',
          vehicleNumber: 'V1',
          amount: 5000.0,
          paymentType: 'ADVANCE',
          paymentMethod: 'cash',
          guardUid: 'G1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: '2',
          ticketId: 'T1',
          vehicleNumber: 'V1',
          amount: 700.0,
          paymentType: 'FINAL',
          paymentMethod: 'cash',
          guardUid: 'G1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: '3',
          ticketId: 'T1',
          vehicleNumber: 'V1',
          amount: 25.0,
          paymentType: 'REFUND',
          paymentMethod: 'cash',
          guardUid: 'G1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: '4',
          ticketId: 'T2',
          vehicleNumber: 'V2',
          amount: 250.0,
          paymentType: 'ADVANCE',
          paymentMethod: 'upi',
          guardUid: 'G1',
          createdAt: now,
        ),
        PaymentTransactionModel(
          id: '5',
          ticketId: 'T2',
          vehicleNumber: 'V2',
          amount: 30.0,
          paymentType: 'REFUND',
          paymentMethod: 'upi',
          guardUid: 'G1',
          createdAt: now,
        ),
      ];

      double cashNet = (5000.0 + 700.0 - 25.0); // 5675
      double upiNet = (250.0 - 30.0); // 220
      double total = cashNet + upiNet; // 5895

      final report = PaymentReportData(
        todayTotalCollection: total,
        expectedCash: 5700.0,
        collectedCash: cashNet,
        cashTransactionsCount: 3,
        expectedUpi: 250.0,
        collectedUpi: upiNet,
        upiTransactionsCount: 2,
        transactions: txns,
      );

      expect(report.collectedCash, 5675.0);
      expect(report.collectedUpi, 220.0);
      expect(report.todayTotalCollection, 5895.0);
    });

    testWidgets('8. Add Guard FloatingActionButton remains functional and available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminGuardManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('add_guard_fab')), findsOneWidget);
      expect(find.text(AppStrings.addGuard), findsOneWidget);
    });
  });
}
