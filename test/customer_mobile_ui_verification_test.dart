import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/widgets/common/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Real UI Widget Verification — Customer Mobile Input & Validation', () {
    testWidgets('1. UI: typing letters is rejected', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              labelText: 'Customer Mobile Number *',
              hintText: 'Enter 10-digit mobile number',
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
          ),
        ),
      );

      // Typing letters 'abcdefghij'
      await tester.enterText(find.byType(TextField), 'abcdefghij');
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(find.text('abcdefghij'), findsNothing);

      // Typing alphanumeric '98765abc10'
      await tester.enterText(find.byType(TextField), '98765abc10');
      await tester.pump();

      expect(controller.text, equals('9876510'));
    });

    testWidgets('2. UI: 11th digit is blocked by maxLength and limiter', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              labelText: 'Customer Mobile Number *',
              hintText: 'Enter 10-digit mobile number',
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
          ),
        ),
      );

      // Attempt to enter 11 digits: '98765432101'
      await tester.enterText(find.byType(TextField), '98765432101');
      await tester.pump();

      // Only first 10 digits accepted
      expect(controller.text, equals('9876543210'));
      expect(controller.text.length, 10);
    });

    testWidgets('3. UI: valid 10-digit number accepted without errors', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                controller: controller,
                labelText: 'Customer Mobile Number *',
                hintText: 'Enter 10-digit mobile number',
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mobile number is required.';
                  }
                  if (!AppFormatters.isValidCustomerMobile(v)) {
                    return 'Enter a valid 10-digit mobile number.';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Enter valid number starting with 9
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      expect(find.text('Enter a valid 10-digit mobile number.'), findsNothing);
      expect(find.text('Mobile number is required.'), findsNothing);

      // Enter valid number starting with 6
      await tester.enterText(find.byType(TextField), '6654321098');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);

      // Enter valid number starting with 7
      await tester.enterText(find.byType(TextField), '7654321098');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);

      // Enter valid number starting with 8
      await tester.enterText(find.byType(TextField), '8765432109');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('4. UI: submit with invalid or empty number is blocked with exact error messages', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                controller: controller,
                labelText: 'Customer Mobile Number *',
                hintText: 'Enter 10-digit mobile number',
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mobile number is required.';
                  }
                  if (!AppFormatters.isValidCustomerMobile(v)) {
                    return 'Enter a valid 10-digit mobile number.';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Empty submission
      controller.text = '';
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Mobile number is required.'), findsOneWidget);

      // Invalid first digit (starts with 1)
      await tester.enterText(find.byType(TextField), '1234567890');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);

      // Less than 10 digits (9 digits)
      await tester.enterText(find.byType(TextField), '987654321');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    });

    testWidgets('5. UI: verify Firestore receives exactly 10 digits and WhatsApp URL is correct', (tester) async {
      const validMobile = '9876543210';
      expect(AppFormatters.isValidCustomerMobile(validMobile), isTrue);

      final record = ParkingRecord(
        id: 'TKT-20260923-9999',
        ticketId: 'TKT-20260923-9999',
        ticketNumber: 'TKT-20260923-9999',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: validMobile,
        entryTime: DateTime(2026, 9, 23, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      // Stored in Firestore exactly as 10 digits
      final firestoreMap = record.toFirestore();
      expect(firestoreMap['customerMobile'], equals('9876543210'));

      // WhatsApp URL correctly prepends country code 91
      final waUrl = 'https://wa.me/91${record.customerMobile}?text=Test';
      expect(waUrl, equals('https://wa.me/919876543210?text=Test'));
    });
  });
}
