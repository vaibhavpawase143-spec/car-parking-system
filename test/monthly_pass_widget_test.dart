import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/screens/admin/passes/admin_monthly_pass_management_screen.dart';

import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';

void main() {
  group('Monthly Pass Widget & Flow Verification', () {
    testWidgets('Monthly Pass Management screen renders search, filters and create button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Monthly Pass Management'), findsOneWidget);
      expect(find.text('Create Monthly Pass'), findsAtLeastNWidgets(1));

      // Verify Search Bar
      expect(find.byType(TextField), findsAtLeastNWidgets(1));

      // Verify Filter Dropdowns exist
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(find.text('All'), findsWidgets);
    });

    testWidgets('Create Monthly Pass dialog displays READ-ONLY ₹600 and no editable amount', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap [Create Monthly Pass]
      final createButton = find.byKey(const ValueKey('btn_create_monthly_pass'));
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify Dialog Title
      expect(find.text('Create Monthly Pass'), findsAtLeastNWidgets(1));

      // Verify ₹600 FIXED amount is displayed
      expect(find.text('₹600 FIXED'), findsAtLeastNWidgets(1));
      expect(find.text('Monthly Pass Amount'), findsOneWidget);

      // Verify read-only notice and full advance requirement
      expect(find.text('FULL ₹600 IN ADVANCE'), findsOneWidget);

      // Verify NO editable amount field exists (Amount Paid / Remaining / Pay Later must NOT exist)
      expect(find.text('Amount Paid'), findsNothing);
      expect(find.text('Remaining'), findsNothing);
      expect(find.text('Pay Later'), findsNothing);
      expect(find.text('Pay Partial'), findsNothing);
      expect(find.text('Edit Amount'), findsNothing);

      // Verify Payment Action Button
      expect(find.text('Pay ₹600 & Create Pass'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close dialog
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Monthly Pass Management renders properly in Marathi localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Marathi Header and Action
      expect(find.text('मासिक पास व्यवस्थापन'), findsOneWidget);
      final createButtonMr = find.byKey(const ValueKey('btn_create_monthly_pass'));
      expect(createButtonMr, findsOneWidget);

      // Open Dialog in Marathi
      await tester.tap(createButtonMr);
      await tester.pumpAndSettle();

      expect(find.text('मासिक पास तयार करा'), findsAtLeastNWidgets(1));
      expect(find.text('संपूर्ण ₹६०० आगाऊ रक्कम'), findsOneWidget);
      expect(find.text('₹६०० भरा आणि पास तयार करा'), findsOneWidget);

      // Close dialog
      await tester.ensureVisible(find.text('रद्द करा'));
      await tester.tap(find.text('रद्द करा'));
      await tester.pumpAndSettle();

      // Reset language
      AppStrings.setLanguage(AppLanguage.english);
    });
  });
}
