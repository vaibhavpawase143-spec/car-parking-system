import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/screens/admin/passes/admin_monthly_pass_management_screen.dart';
import 'package:car_parking_system/services/monthly_pass_service.dart';
import 'package:car_parking_system/models/monthly_pass_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';

class FakeMonthlyPassService extends MonthlyPassService {
  final StreamController<List<MonthlyPassModel>> controller;

  FakeMonthlyPassService(this.controller);

  @override
  Stream<List<MonthlyPassModel>> watchAllPasses() {
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  final activePass = MonthlyPassModel(
    id: 'pass_active_1',
    passNumber: 'PASS-2026-001',
    vehicleNumber: 'MH 15 AB 1234',
    normalizedVehicleNumber: 'MH15AB1234',
    vehicleType: VehicleType.twoWheeler,
    customerName: 'Ramesh Patil',
    customerMobile: '9876543210',
    startDate: now.subtract(const Duration(days: 5)),
    endDate: now.add(const Duration(days: 25)),
    amount: 600.0,
    amountPaid: 600.0,
    outstandingAmount: 0.0,
    paymentStatus: 'PAID',
    paymentMethod: 'cash',
    status: 'ACTIVE',
    createdAt: now.subtract(const Duration(days: 5)),
    createdBy: 'Admin Test',
  );

  final upcomingPass = MonthlyPassModel(
    id: 'pass_upcoming_1',
    passNumber: 'PASS-2026-002',
    vehicleNumber: 'MH 12 CD 5678',
    normalizedVehicleNumber: 'MH12CD5678',
    vehicleType: VehicleType.fourWheeler,
    customerName: 'Suresh Shinde',
    customerMobile: '9123456789',
    startDate: now.add(const Duration(days: 3)),
    endDate: now.add(const Duration(days: 33)),
    amount: 600.0,
    amountPaid: 600.0,
    outstandingAmount: 0.0,
    paymentStatus: 'PAID',
    paymentMethod: 'upi',
    status: 'UPCOMING',
    createdAt: now.subtract(const Duration(days: 1)),
    createdBy: 'Admin Test',
  );

  final expiredPass = MonthlyPassModel(
    id: 'pass_expired_1',
    passNumber: 'PASS-2026-003',
    vehicleNumber: 'MH 14 EF 9012',
    normalizedVehicleNumber: 'MH14EF9012',
    vehicleType: VehicleType.twoWheeler,
    customerName: 'Ganesh Pawar',
    customerMobile: '9988776655',
    startDate: now.subtract(const Duration(days: 35)),
    endDate: now.subtract(const Duration(days: 5)),
    amount: 600.0,
    amountPaid: 600.0,
    outstandingAmount: 0.0,
    paymentStatus: 'PAID',
    paymentMethod: 'cash',
    status: 'EXPIRED',
    createdAt: now.subtract(const Duration(days: 35)),
    createdBy: 'Admin Test',
  );

  group('Monthly Pass Management - Loading & All States Verification', () {
    testWidgets('1. Loading state renders spinner while waiting', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      // Verify CircularProgressIndicator is present while waiting
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });

    testWidgets('2. Zero records renders empty state (never infinite loading)', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      // Emit empty list
      controller.add(<MonthlyPassModel>[]);
      await tester.pumpAndSettle();

      // Verify empty state is displayed and no spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(AppStrings.noPassesFound), findsOneWidget);

      await controller.close();
    });

    testWidgets('3. One record renders pass card with full details', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.add([activePass]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('PASS-2026-001'), findsOneWidget);
      expect(find.text('MH 15 AB 1234'), findsOneWidget);
      expect(find.text('Ramesh Patil'), findsOneWidget);
      expect(find.text('ACTIVE'), findsWidgets);

      await controller.close();
    });

    testWidgets('4. Multiple records render all cards', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.add([activePass, upcomingPass, expiredPass]);
      await tester.pumpAndSettle();

      expect(find.text('PASS-2026-001'), findsOneWidget);
      expect(find.text('PASS-2026-002'), findsOneWidget);
      expect(find.text('PASS-2026-003'), findsOneWidget);

      await controller.close();
    });

    testWidgets('5. Stream error displays error state with Retry button (no infinite spinner)', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      // Emit error (e.g. PERMISSION_DENIED or network error)
      controller.addError('PERMISSION_DENIED: Missing or insufficient permissions');
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(AppStrings.unableToLoadMonthlyPasses), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_retry_monthly_passes')), findsOneWidget);

      await controller.close();
    });

    testWidgets('6. Search filters by vehicle number, pass number, customer name, mobile', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.add([activePass, upcomingPass, expiredPass]);
      await tester.pumpAndSettle();

      // Enter search query for "MH12" (upcoming four-wheeler)
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'MH12');
      await tester.pumpAndSettle();

      expect(find.text('PASS-2026-002'), findsOneWidget);
      expect(find.text('PASS-2026-001'), findsNothing);
      expect(find.text('PASS-2026-003'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('PASS-2026-001'), findsOneWidget);
      expect(find.text('PASS-2026-002'), findsOneWidget);
      expect(find.text('PASS-2026-003'), findsOneWidget);

      await controller.close();
    });

    testWidgets('7. Status filter isolates ACTIVE, UPCOMING, and EXPIRED passes', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.add([activePass, upcomingPass, expiredPass]);
      await tester.pumpAndSettle();

      // Filter by Active Passes
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.activePasses).last);
      await tester.pumpAndSettle();

      expect(find.text('PASS-2026-001'), findsOneWidget);
      expect(find.text('PASS-2026-002'), findsNothing);
      expect(find.text('PASS-2026-003'), findsNothing);

      await controller.close();
    });

    testWidgets('8. Vehicle type filter isolates Two-Wheeler and Four-Wheeler', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.add([activePass, upcomingPass, expiredPass]);
      await tester.pumpAndSettle();

      // Filter by Four-Wheeler
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.fourWheeler).last);
      await tester.pumpAndSettle();

      expect(find.text('PASS-2026-002'), findsOneWidget); // Four-wheeler
      expect(find.text('PASS-2026-001'), findsNothing);
      expect(find.text('PASS-2026-003'), findsNothing);

      await controller.close();
    });

    test('9. Null optional fields in MonthlyPassModel parse without crashing', () {
      final parsed = MonthlyPassModel.fromMap({
        'passNumber': 'PASS-NULL-001',
        'vehicleNumber': 'MH15Z9999',
        'vehicleType': 'twoWheeler',
        'startDate': null,
        'endDate': null,
        'amount': null,
        'amountPaid': null,
        'outstandingAmount': null,
        'paymentStatus': null,
        'paymentMethod': null,
        'status': null,
        'createdAt': null,
        'createdBy': null,
        'updatedAt': null,
      }, 'pass_doc_id_999');

      expect(parsed.passNumber, 'PASS-NULL-001');
      expect(parsed.amount, 600.0);
      expect(parsed.amountPaid, 600.0);
      expect(parsed.outstandingAmount, 0.0);
      expect(parsed.paymentStatus, 'PAID');
      expect(parsed.updatedAt, isNull);
    });

    testWidgets('10. Marathi mode renders all Monthly Pass headers and empty/error states', (tester) async {
      final controller = StreamController<List<MonthlyPassModel>>();
      final fakeService = FakeMonthlyPassService(controller);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      AppStrings.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMonthlyPassManagementScreen(monthlyPassService: fakeService),
          ),
        ),
      );

      controller.addError('Firestore permission error');
      await tester.pumpAndSettle();

      // Verify Marathi error state
      expect(find.text('मासिक पास लोड करण्यात अयशस्वी.'), findsOneWidget);
      expect(find.text('पुन्हा प्रयत्न करा'), findsOneWidget);

      // Now emit empty list
      controller.add(<MonthlyPassModel>[]);
      // Reset language back
      AppStrings.setLanguage(AppLanguage.english);
      await controller.close();
    });
  });
}
