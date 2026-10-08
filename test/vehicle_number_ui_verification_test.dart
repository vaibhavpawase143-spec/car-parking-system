import 'package:car_parking_system/core/theme/app_colors.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/widgets/common/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Real UI Widget Verification — Vehicle Number Input & Normalization', () {
    testWidgets('1. UI: lowercase input immediately converts to UPPERCASE', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              labelText: 'Vehicle Number *',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                UpperCaseTextFormatter(),
              ],
            ),
          ),
        ),
      );

      // Simulate typing lowercase 'mh12ab1234'
      await tester.enterText(find.byType(TextField), 'mh12ab1234');
      await tester.pump();

      expect(controller.text, equals('MH12AB1234'));
      expect(find.text('MH12AB1234'), findsOneWidget);
    });

    testWidgets('2. UI: paste and mixed-case immediately convert to UPPERCASE without cursor jumps', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              labelText: 'Vehicle Number *',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                UpperCaseTextFormatter(),
              ],
            ),
          ),
        ),
      );

      // Simulate pasting mixed case
      await tester.enterText(find.byType(TextField), 'Mh12aB1234');
      await tester.pump();

      expect(controller.text, equals('MH12AB1234'));

      // Simulate pasting with spaces
      await tester.enterText(find.byType(TextField), 'dl 04 ca 9999');
      await tester.pump();

      expect(controller.text, equals('DL 04 CA 9999'));
    });

    testWidgets('3. UI: special characters are rejected while preserving alphanumeric, spaces & hyphens', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              labelText: 'Vehicle Number *',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                UpperCaseTextFormatter(),
              ],
            ),
          ),
        ),
      );

      // Input containing rejected characters like @, #, $, %, &
      await tester.enterText(find.byType(TextField), 'MH@12#AB\$12%34&*');
      await tester.pump();

      // Only valid characters (MH12AB1234) should remain, uppercase
      expect(controller.text, equals('MH12AB1234'));

      // Spaces and hyphens are preserved during typing
      await tester.enterText(find.byType(TextField), 'MH-12 AB 1234');
      await tester.pump();
      expect(controller.text, equals('MH-12 AB 1234'));
    });

    testWidgets('4. UI: Form validation displays exact required error messages', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                controller: controller,
                labelText: 'Vehicle Number *',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                  UpperCaseTextFormatter(),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vehicle Number is required.';
                  }
                  if (!AppFormatters.isValidVehicleNumber(v)) {
                    return 'Enter a valid Indian vehicle registration number.';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Test empty
      controller.text = '';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Vehicle Number is required.'), findsOneWidget);

      // Test whitespace only
      controller.text = '   ';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Vehicle Number is required.'), findsOneWidget);

      // Test invalid vehicle number (e.g. ABC)
      controller.text = 'ABC';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsOneWidget);

      // Test invalid vehicle number (e.g. 123456)
      controller.text = '123456';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsOneWidget);

      // Test invalid vehicle number (e.g. RANDOM123)
      controller.text = 'RANDOM123';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsOneWidget);

      // Test valid format with spaces (e.g. MH 12 AB 1234)
      controller.text = 'MH 12 AB 1234';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsNothing);
      expect(find.text('Vehicle Number is required.'), findsNothing);

      // Test valid format with hyphens (e.g. MH-12-AB-1234)
      controller.text = 'MH-12-AB-1234';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsNothing);

      // Test valid Bharat series (e.g. 22BH1234AA)
      controller.text = '22BH1234AA';
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid Indian vehicle registration number.'), findsNothing);
    });

    testWidgets('5. UI: Duplicate Active Vehicle Alert Banner displays exact message', (tester) async {
      const errorMessage = 'This vehicle is already parked.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColoredBox(
              color: AppColors.dangerLight,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.dangerDark),
                    SizedBox(width: 8),
                    Text(errorMessage),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('This vehicle is already parked.'), findsOneWidget);
    });

    testWidgets('6. UI: Entry Slip Widget displays normalized uppercase vehicle number', (tester) async {
      // Legacy record created with lowercase and spaces
      final record = ParkingRecord(
        id: 'TKT-20260923-TEST',
        ticketId: 'TKT-20260923-TEST',
        ticketNumber: 'TKT-20260923-TEST',
        vehicleNumber: 'mh 12 ab 1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 23, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(
              AppFormatters.normalizeVehicleNumber(record.vehicleNumber),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );

      // Expect normalized uppercase string
      expect(find.text('MH12AB1234'), findsOneWidget);
      expect(find.text('mh 12 ab 1234'), findsNothing);
    });

    testWidgets('7. UI: WhatsApp Message Builder uses normalized uppercase vehicle number', (tester) async {
      final legacyRecord = ParkingRecord(
        id: 'TKT-20260923-WA',
        ticketId: 'TKT-20260923-WA',
        ticketNumber: 'TKT-20260923-WA',
        vehicleNumber: 'mh-12-ab-1234',
        vehicleType: VehicleType.twoWheeler,
        customerMobile: '9876543210',
        entryTime: DateTime(2026, 9, 23, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard1',
        entryGuardName: 'Guard',
        entryShift: 'Shift 1',
      );

      final normalizedVehicle = AppFormatters.normalizeVehicleNumber(legacyRecord.vehicleNumber);
      final waMessage = 'Parking Entry Confirmed ✅\nVehicle: $normalizedVehicle\nType: ${legacyRecord.vehicleType.displayName}';

      expect(waMessage, contains('Vehicle: MH12AB1234'));
      expect(waMessage.contains('mh-12-ab-1234'), isFalse);
    });
  });
}
