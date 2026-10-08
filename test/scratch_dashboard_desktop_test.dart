import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/screens/admin/dashboard/admin_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  const testAdmin = GuardModel(
    uid: 'admin_test_01',
    name: 'Master Admin',
    email: 'admin@parking.com',
    role: 'admin',
    isActive: true,
  );

  testWidgets('TEST DESKTOP 1366x768 AdminNavigationShell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() async => await tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminNavigationShell(currentAdmin: testAdmin),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    debugPrint('[TEST LOG] Errors: ${tester.takeException()}');
    final dashboardFinder = find.byType(AdminDashboardScreen);
    debugPrint('[TEST LOG] AdminDashboardScreen found: ${dashboardFinder.evaluate().length}');

    final headerFinder = find.text('Profile: Master Admin');
    debugPrint('[TEST LOG] Header found: ${headerFinder.evaluate().length}');

    final guardStatsFinder = find.text('Guard Statistics');
    debugPrint('[TEST LOG] Guard Statistics found: ${guardStatsFinder.evaluate().length}');
  });
}
