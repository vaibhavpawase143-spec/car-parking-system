import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/notification_localizer.dart';
import 'package:car_parking_system/models/notification_model.dart';
import 'package:car_parking_system/widgets/notifications/notification_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('FOCUSED NOTIFICATION LOCALIZATION TESTS', () {
    // 1. EXACT REAL RECORD FROM SCREENSHOT
    test('TEST 1: Exact real screenshot notification - "New Shift Assigned" with 11:28 AM to 07:28 PM in Marathi and English', () async {
      final realNotif = NotificationModel(
        notificationId: 'notif-real-123',
        recipientUserId: 'guard-test-uid',
        title: 'New Shift Assigned',
        message: 'You have been assigned a 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.',
        type: 'shift',
        createdAt: DateTime(2026, 10, 8, 11, 28),
      );

      // In Marathi
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(realNotif.localizedTitle, equals('नवीन पाळी नेमणूक'));
      expect(
        realNotif.localizedMessage,
        equals('तुम्हाला 08/10/2026 रोजी 11:28 AM ते 07:28 PM या वेळेत 8 तासांची पाळी नेमून दिली आहे.'),
      );
      expect(realNotif.localizedCategory, equals('पाळी'));

      // In English
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(realNotif.localizedTitle, equals('New Shift Assigned'));
      expect(
        realNotif.localizedMessage,
        equals('You have been assigned a 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.'),
      );
      expect(realNotif.localizedCategory, equals('Shift'));
    });

    test('TEST 2: "an 8-hour shift" variant in Marathi and English', () async {
      final notifAn = NotificationModel(
        notificationId: 'notif-an-456',
        recipientUserId: 'guard-test-uid',
        title: 'New Shift Assigned',
        message: 'You have been assigned an 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.',
        type: 'shift',
        createdAt: DateTime(2026, 10, 8, 11, 28),
      );

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(notifAn.localizedTitle, equals('नवीन पाळी नेमणूक'));
      expect(
        notifAn.localizedMessage,
        equals('तुम्हाला 08/10/2026 रोजी 11:28 AM ते 07:28 PM या वेळेत 8 तासांची पाळी नेमून दिली आहे.'),
      );

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(notifAn.localizedTitle, equals('New Shift Assigned'));
      expect(
        notifAn.localizedMessage,
        equals('You have been assigned an 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.'),
      );
    });

    test('TEST 3: Switch back and forth between Marathi and English without restart', () async {
      final notif = NotificationModel(
        notificationId: 'notif-switch',
        recipientUserId: 'guard-1',
        title: 'Shift Cancelled',
        message: 'Your shift scheduled for 08/10/2026 (08:00 AM - 04:00 PM) has been cancelled.',
        type: 'shift',
        createdAt: DateTime(2026, 10, 8, 8, 0),
      );

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(notif.localizedTitle, equals('Shift Cancelled'));

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);
      expect(notif.localizedTitle, equals('पाळी रद्द केली'));

      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      expect(notif.localizedTitle, equals('Shift Cancelled'));
    });

    test('TEST 4: Various notification categories and actions in Marathi', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      // Handover
      final handoverNotif = NotificationModel(
        notificationId: 'notif-h1',
        recipientUserId: 'guard-2',
        title: 'Incoming CASH Handover',
        message: 'Ramesh has handed over ₹500.00 CASH responsibility to you.',
        type: 'handover',
        createdAt: DateTime(2026, 10, 8, 14, 0),
      );
      expect(handoverNotif.localizedTitle, equals('येणारे CASH हस्तांतरण'));
      expect(handoverNotif.localizedMessage, equals('Ramesh यांनी ₹500.00 CASH जबाबदारी तुमच्याकडे हस्तांतरित केली आहे.'));
      expect(handoverNotif.localizedCategory, equals('हस्तांतरण'));

      // Handover accepted
      final acceptedNotif = NotificationModel(
        notificationId: 'notif-h2',
        recipientUserId: 'guard-1',
        title: 'ACCEPTED: CASH Handover',
        message: 'Suresh has accepted your CASH handover of ₹500.00.',
        type: 'handover',
        createdAt: DateTime(2026, 10, 8, 14, 5),
      );
      expect(acceptedNotif.localizedTitle, equals('स्वीकारले: CASH हस्तांतरण'));
      expect(acceptedNotif.localizedMessage, equals('Suresh यांनी तुमचे ₹500.00 चे CASH हस्तांतरण स्वीकारले आहे.'));

      // Withdrawal
      final withNotif = NotificationModel(
        notificationId: 'notif-w1',
        recipientUserId: 'guard-1',
        title: 'CASH Withdrawal',
        message: 'Admin withdrew ₹500.00 CASH from your responsibility.\nRemaining CASH responsibility: ₹0.00\nDate: 08/10/2026 03:00 PM',
        type: 'withdrawal',
        createdAt: DateTime(2026, 10, 8, 15, 0),
      );
      expect(withNotif.localizedTitle, equals('CASH जमा / काढणे'));
      expect(withNotif.localizedMessage, equals('ॲडमिनने तुमच्या जबाबदारीतून ₹500.00 CASH जमा/कमी केले.\nउर्वरित CASH जबाबदारी: ₹0.00\nदिनांक: 08/10/2026 03:00 PM'));
      expect(withNotif.localizedCategory, equals('काढणे'));

      // Capacity
      final capNotif = NotificationModel(
        notificationId: 'notif-c1',
        recipientUserId: 'all',
        title: 'Parking Capacity Updated',
        message: 'Parking capacity has been updated by Admin (4W: 20, 2W: 50).',
        type: 'capacity',
        createdAt: DateTime(2026, 10, 8, 10, 0),
      );
      expect(capNotif.localizedTitle, equals('वाहनतळ क्षमता अद्यतनित'));
      expect(capNotif.localizedMessage, equals('ॲडमिनने वाहनतळ क्षमता अद्यतनित केली आहे (4W: 20, 2W: 50).'));
      expect(capNotif.localizedCategory, equals('सिस्टम'));

      // Entry blocked
      final entryNotif = NotificationModel(
        notificationId: 'notif-eb1',
        recipientUserId: 'guard-1',
        title: 'Vehicle Entry Blocked',
        message: 'No active shift is currently assigned to your account. Vehicle entry cannot be created.',
        type: 'entry_blocked',
        createdAt: DateTime(2026, 10, 8, 8, 0),
      );
      expect(entryNotif.localizedTitle, equals('वाहन प्रवेश थांबवला'));
      expect(entryNotif.localizedMessage, equals('सध्या तुमच्या खात्यावर कोणतीही सक्रिय पाळी नियुक्त केलेली नाही. वाहन प्रवेश नोंदवता येणार नाही.'));
      expect(entryNotif.localizedCategory, equals('सुरक्षा'));
    });

    test('TEST 5: Dynamic parameters integrity (Vehicle numbers, Amounts, Dates, Times, Names)', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      final notif1 = NotificationModel(
        notificationId: 'n1',
        recipientUserId: 'g1',
        title: 'Shift Started',
        message: 'Your shift has been started by Admin (SuperAdmin). Date: 09/10/2026, Start: 09:15 AM.',
        type: 'shift',
        createdAt: DateTime.now(),
      );
      expect(notif1.localizedMessage, contains('SuperAdmin'));
      expect(notif1.localizedMessage, contains('09/10/2026'));
      expect(notif1.localizedMessage, contains('09:15 AM'));

      final notif2 = NotificationModel(
        notificationId: 'n2',
        recipientUserId: 'g1',
        title: 'Shift Ended',
        message: 'Your shift has ended. Date: 09/10/2026, Scheduled Start: 08:00 AM, Scheduled End: 04:00 PM, Actual End: 04:12 PM.',
        type: 'shift',
        createdAt: DateTime.now(),
      );
      expect(notif2.localizedMessage, contains('09/10/2026'));
      expect(notif2.localizedMessage, contains('08:00 AM'));
      expect(notif2.localizedMessage, contains('04:00 PM'));
      expect(notif2.localizedMessage, contains('04:12 PM'));

      final notif3 = NotificationModel(
        notificationId: 'n3',
        recipientUserId: 'g2',
        title: 'Incoming UPI Handover',
        message: 'Vikram Pawar has handed over ₹1,250.50 UPI responsibility to you.',
        type: 'handover',
        createdAt: DateTime.now(),
      );
      expect(notif3.localizedMessage, contains('Vikram Pawar'));
      expect(notif3.localizedMessage, contains('₹1,250.50'));
      expect(notif3.localizedMessage, contains('UPI'));
    });

    test('TEST 6: Event keys normalization directly maps cleanly in both languages', () {
      expect(
        NotificationLocalizer.localizeRawTitle('NEW_SHIFT_ASSIGNED', language: AppLanguage.english),
        equals('New Shift Assigned'),
      );
      expect(
        NotificationLocalizer.localizeRawTitle('NEW SHIFT ASSIGNED', language: AppLanguage.marathi),
        equals('नवीन पाळी नेमणूक'),
      );
      expect(
        NotificationLocalizer.localizeRawTitle('shift-assigned', language: AppLanguage.marathi),
        equals('नवीन पाळी नेमणूक'),
      );
      expect(
        NotificationLocalizer.localizeRawTitle('HANDOVER_RECEIVED', language: AppLanguage.english),
        equals('Incoming Handover'),
      );
      expect(
        NotificationLocalizer.localizeRawTitle('HANDOVER RECEIVED', language: AppLanguage.marathi),
        equals('येणारे हस्तांतरण'),
      );
    });

    test('TEST 7: No Firestore mutation - NotificationModel preserves original title and message', () {
      final orig = NotificationModel(
        notificationId: 'n-orig',
        recipientUserId: 'g1',
        title: 'New Shift Assigned',
        message: 'You have been assigned a 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.',
        type: 'shift',
        createdAt: DateTime.now(),
      );

      final map = orig.toFirestore();
      // Stored fields remain in original English without mutation
      expect(map['title'], equals('New Shift Assigned'));
      expect(map['message'], equals('You have been assigned a 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM.'));
    });

    testWidgets('TEST 8: NotificationDialog renders localized headers, categories, and switches dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationDialog(userId: 'test-user-123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Marathi
      expect(find.text('सूचना'), findsOneWidget);
      expect(find.text('सर्व वाचले म्हणून चिन्हांकित करा'), findsOneWidget);
      expect(find.text('सर्व'), findsOneWidget);
      expect(find.text('माझी पाळी'), findsOneWidget);
      expect(find.text('रोख (Cash)'), findsOneWidget);
      expect(find.text('हस्तांतरण'), findsOneWidget);

      // Switch to English dynamically
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark All as Read'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('My Shift'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Handover'), findsOneWidget);
    });
  });
}
