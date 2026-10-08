import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/models/guard_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testAdmin = GuardModel(
    uid: 'admin_test_01',
    name: 'Master Admin',
    email: 'admin@parking.com',
    role: 'admin',
    isActive: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('Branding & Localization Master Test Suite', () {
    test('1. Branding constants exist and are exact uppercase strings', () {
      expect(AppStrings.appName, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.companyBrand, equals('BIZFLOW'));
      expect(AppStrings.adminPortal, equals('ADMIN PORTAL'));
      expect(AppStrings.guardPortalTitle, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.browserTitle, equals('CAR PARKING SYSTEM | BIZFLOW'));
    });

    test('2. Branding remains exact English in both English and Marathi modes', () async {
      // English mode
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(AppStrings.appName, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.companyBrand, equals('BIZFLOW'));
      expect(AppStrings.adminPortal, equals('ADMIN PORTAL'));

      // Marathi mode
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(AppStrings.appName, equals('CAR PARKING SYSTEM'));
      expect(AppStrings.companyBrand, equals('BIZFLOW'));
      expect(AppStrings.adminPortal, equals('ADMIN PORTAL'));
      expect(AppStrings.browserTitle, equals('CAR PARKING SYSTEM | BIZFLOW'));
    });

    test('3. English mode renders English labels across all modules', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      expect(AppStrings.dashboard, equals('Dashboard'));
      expect(AppStrings.guardManagement, equals('Guard Management'));
      expect(AppStrings.shiftManagement, equals('Shift Management'));
      expect(AppStrings.paymentManagement, equals('Payment Management'));
      expect(AppStrings.reportsHub, equals('Reports Hub'));
      expect(AppStrings.adminSettings, equals('Admin Settings'));

      // Payment Management tabs & labels
      expect(AppStrings.overview, equals('Overview'));
      expect(AppStrings.cashManagement, equals('Cash Management'));
      expect(AppStrings.upiManagement, equals('UPI Management'));
      expect(AppStrings.keepWithMe, equals('Keep With Me'));
      expect(AppStrings.handovers, equals('Handovers'));
      expect(AppStrings.withdrawals, equals('Withdrawals'));
      expect(AppStrings.transactionsLedger, equals('Transactions Ledger'));
      expect(AppStrings.guardAndShiftReports, equals('Guard & Shift Reports'));

      // Reports Hub
      expect(AppStrings.parkingSummary, equals('Parking Summary'));
      expect(AppStrings.totalEntries, equals('Total Entries'));
      expect(AppStrings.totalExits, equals('Total Exits'));
      expect(AppStrings.currentlyParked, equals('Currently Parked'));
      expect(AppStrings.fourWheeler, equals('Four-Wheeler'));
      expect(AppStrings.twoWheeler, equals('Two-Wheeler'));
      expect(AppStrings.vehicleReport, equals('Vehicle Report'));

      // Guard Financial Report
      expect(AppStrings.collectionSummary, equals('Collection Summary'));
      expect(AppStrings.currentOutstanding, equals('Current Outstanding'));
      expect(AppStrings.activity, equals('Activity'));
      expect(AppStrings.responsibilityHistory, equals('Responsibility History'));
      expect(AppStrings.dateWiseSummary, equals('Date-wise Summary'));

      // Common actions & buttons
      expect(AppStrings.save, equals('Save'));
      expect(AppStrings.cancel, equals('Cancel'));
      expect(AppStrings.delete, equals('Delete'));
      expect(AppStrings.search, equals('Search'));
      expect(AppStrings.apply, equals('Apply'));
      expect(AppStrings.withdraw, equals('Withdraw'));
    });

    test('4. Marathi mode renders complete Marathi labels across all modules', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      expect(AppStrings.dashboard, equals('डॅशबोर्ड'));
      expect(AppStrings.guardManagement, equals('सुरक्षा रक्षक व्यवस्थापन'));
      expect(AppStrings.shiftManagement, equals('पाळी व्यवस्थापन'));
      expect(AppStrings.paymentManagement, equals('पेमेंट व्यवस्थापन'));
      expect(AppStrings.reportsHub, equals('अहवाल केंद्र'));
      expect(AppStrings.adminSettings, equals('ॲडमिन सेटिंग्ज'));

      // Payment Management tabs & labels
      expect(AppStrings.overview, equals('आढावा'));
      expect(AppStrings.cashManagement, equals('रोख व्यवस्थापन'));
      expect(AppStrings.upiManagement, equals('UPI व्यवस्थापन'));
      expect(AppStrings.keepWithMe, equals('स्वतःकडे शिल्लक'));
      expect(AppStrings.handovers, equals('हस्तांतरण'));
      expect(AppStrings.withdrawals, equals('पैसे काढणे'));
      expect(AppStrings.transactionsLedger, equals('व्यवहार लेजर'));
      expect(AppStrings.guardAndShiftReports, equals('रक्षक व पाळी अहवाल'));

      // Reports Hub
      expect(AppStrings.parkingSummary, equals('वाहनतळ सारांश'));
      expect(AppStrings.totalEntries, equals('एकूण प्रवेश'));
      expect(AppStrings.totalExits, equals('एकूण निर्गमन'));
      expect(AppStrings.currentlyParked, equals('सध्या पार्क केलेली वाहने'));
      expect(AppStrings.fourWheeler, equals('चारचाकी'));
      expect(AppStrings.twoWheeler, equals('दुचाकी'));
      expect(AppStrings.vehicleReport, equals('वाहन अहवाल'));

      // Guard Financial Report
      expect(AppStrings.collectionSummary, equals('संकलन सारांश'));
      expect(AppStrings.currentOutstanding, equals('चालू शिल्लक'));
      expect(AppStrings.activity, equals('हालचाली'));
      expect(AppStrings.responsibilityHistory, equals('जबाबदारी इतिहास'));
      expect(AppStrings.dateWiseSummary, equals('दिनांकनिहाय सारांश'));

      // Common actions & buttons
      expect(AppStrings.save, equals('जतन करा'));
      expect(AppStrings.cancel, equals('रद्द करा'));
      expect(AppStrings.delete, equals('हटवा'));
      expect(AppStrings.search, equals('शोधा'));
      expect(AppStrings.apply, equals('लागू करा'));
      expect(AppStrings.withdraw, equals('काढून घ्या'));
    });

    test('5. Status, payment type, and method formatters return localized text in Marathi', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      expect(AppStrings.formatStatus('PENDING'), equals('प्रलंबित'));
      expect(AppStrings.formatStatus('ACCEPTED'), equals('स्वीकारले'));
      expect(AppStrings.formatStatus('REJECTED'), equals('नाकारले'));
      expect(AppStrings.formatStatus('COMPLETED'), equals('पूर्ण'));
      expect(AppStrings.formatStatus('ACTIVE'), equals('सक्रिय'));

      expect(AppStrings.formatPaymentType('ADVANCE'), equals('अ‍ॅडव्हान्स'));
      expect(AppStrings.formatPaymentType('FINAL'), equals('अंतिम'));
      expect(AppStrings.formatPaymentType('REFUND'), equals('परतावा'));

      expect(AppStrings.formatPaymentMethod('CASH'), equals('रोख'));
      expect(AppStrings.formatPaymentMethod('UPI'), equals('UPI'));
    });

    testWidgets('6. Admin sidebar renders exact branding and updates language immediately without restart', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await AppLanguageController.instance.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: AppLanguageController.instance,
          builder: (context, _) => MaterialApp(
            home: const AdminNavigationShell(currentAdmin: testAdmin),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In English:
      // Verify branding:
      expect(find.text('CAR PARKING SYSTEM'), findsWidgets);
      expect(find.text('BIZFLOW'), findsWidgets);
      expect(find.text('ADMIN PORTAL'), findsWidgets);

      // Verify English sidebar labels:
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Guard Management'), findsWidgets);
      expect(find.text('Shift Management'), findsWidgets);
      expect(find.text('Payment Management'), findsWidgets);
      expect(find.text('Reports Hub'), findsWidgets);
      expect(find.text('Admin Settings'), findsWidgets);

      // Verify old branding is not rendered:
      expect(find.text('JAY GANESH PAY & PARK'), findsNothing);
      expect(find.text('Jay Ganesh Pay & Park'), findsNothing);
      expect(find.text('जय गणेश पे अँड पार्क'), findsNothing);

      // Switch to Marathi mode
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Branding MUST still remain fixed uppercase English
      expect(find.text('CAR PARKING SYSTEM'), findsWidgets);
      expect(find.text('BIZFLOW'), findsWidgets);
      expect(find.text('ADMIN PORTAL'), findsWidgets);

      // Verify old branding is NOT rendered
      expect(find.text('जय गणेश पे अँड पार्क'), findsNothing);
      expect(find.text('JAY GANESH PAY & PARK'), findsNothing);

      // Verify UI labels immediately changed to Marathi
      expect(find.text('डॅशबोर्ड'), findsWidgets);
      expect(find.text('सुरक्षा रक्षक व्यवस्थापन'), findsWidgets);
      expect(find.text('पाळी व्यवस्थापन'), findsWidgets);
      expect(find.text('पेमेंट व्यवस्थापन'), findsWidgets);
      expect(find.text('अहवाल केंद्र'), findsWidgets);
      expect(find.text('ॲडमिन सेटिंग्ज'), findsWidgets);

      // Switch back to English
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Payment Management'), findsWidgets);
    });
  });
}
