import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/services/guard_auth_service.dart';
import 'package:car_parking_system/widgets/common/app_text_field.dart';
import 'package:car_parking_system/screens/guard/auth/guard_login_screen.dart';
import 'package:car_parking_system/screens/guard/auth/forgot_password_screen.dart';

class TestMockGuardAuthService extends GuardAuthService {
  String? lastResetEmail;
  bool shouldThrowAuthException = false;
  String authExceptionCode = 'user-not-found';
  bool shouldThrowGenericException = false;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastResetEmail = email;
    if (shouldThrowAuthException) {
      throw FirebaseAuthException(code: authExceptionCode, message: 'Auth test error');
    }
    if (shouldThrowGenericException) {
      throw Exception('Generic network timeout');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
    AppStrings.setLanguage(AppLanguage.english);
  });

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('GUARD LOGIN & FORGOT PASSWORD — UX & Flow Tests', () {
    testWidgets('1. GuardLoginScreen renders Email, Password, Login button, and localized Forgot Password link', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Email and Password form fields are present
      expect(find.byType(AppTextField), findsNWidgets(2));
      expect(find.text(AppStrings.guardPortalTitle), findsOneWidget);

      // 2. Login button is present
      expect(find.text(AppStrings.signIn), findsOneWidget);

      // 3. Localized Forgot Password? link is present
      expect(find.text(AppStrings.forgotPassword), findsOneWidget);
    });

    testWidgets('2. GuardLoginScreen shows validation errors on empty submission', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In without typing credentials
      await tester.tap(find.text(AppStrings.signIn));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.emailRequired), findsOneWidget);
      expect(find.text(AppStrings.passwordRequired), findsOneWidget);
    });

    testWidgets('3. ForgotPasswordScreen renders title, subtitle, email field, submit button and back link', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.resetPasswordTitle), findsNWidgets(2)); // AppBar + Card
      expect(find.text(AppStrings.resetPasswordSubtitle), findsOneWidget);
      expect(find.text(AppStrings.sendResetLink), findsOneWidget);
      expect(find.text(AppStrings.backToLogin), findsOneWidget);

      // Tap Submit with empty email
      await tester.tap(find.text(AppStrings.sendResetLink));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.emailRequired), findsOneWidget);
    });

    testWidgets('4. ForgotPasswordScreen validates invalid email format', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField).first, 'invalidemail');
      await tester.tap(find.text(AppStrings.sendResetLink));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.invalidEmail), findsOneWidget);
    });

    testWidgets('5. ForgotPasswordScreen successfully sends password reset email and shows confirmation card', (tester) async {
      setTestSurfaceSize(tester);
      final mockAuth = TestMockGuardAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid email
      await tester.enterText(find.byType(TextFormField).first, 'guard1@parking.com');
      await tester.tap(find.text(AppStrings.sendResetLink));
      await tester.pumpAndSettle();

      expect(mockAuth.lastResetEmail, 'guard1@parking.com');
      expect(find.text(AppStrings.resetLinkSent), findsOneWidget);
      expect(find.text('guard1@parking.com'), findsOneWidget);
      expect(find.text(AppStrings.backToLogin), findsOneWidget);
    });

    testWidgets('6. ForgotPasswordScreen handles FirebaseAuthException error cleanly', (tester) async {
      setTestSurfaceSize(tester);
      final mockAuth = TestMockGuardAuthService()..shouldThrowAuthException = true..authExceptionCode = 'user-not-found';

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'unknown@parking.com');
      await tester.tap(find.text(AppStrings.sendResetLink));
      await tester.pumpAndSettle();

      expect(find.textContaining('No user account found'), findsOneWidget);
    });

    testWidgets('7. ForgotPasswordScreen renders seamlessly in Marathi localization', (tester) async {
      setTestSurfaceSize(tester);
      AppStrings.setLanguage(AppLanguage.marathi);
      await AppLanguageController.instance.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('पासवर्ड रीसेट करा'), findsNWidgets(2));
      expect(find.text('तुमचा नोंदणीकृत ईमेल टाका. पासवर्ड रीसेट करण्याची लिंक पाठवली जाईल.'), findsOneWidget);
      expect(find.text('रीसेट लिंक पाठवा'), findsOneWidget);
      expect(find.text('लॉगिनकडे परत जा'), findsOneWidget);
    });

    test('8. GuardAuthService.mapAuthError accurately differentiates all error codes', () {
      final netErr = FirebaseAuthException(code: 'network-request-failed', message: 'A network error occurred');
      expect(GuardAuthService.mapAuthError(netErr), contains('Automatic'));
      expect(GuardAuthService.mapAuthError(netErr), contains('Network connection error'));

      final credErr = FirebaseAuthException(code: 'invalid-credential');
      expect(GuardAuthService.mapAuthError(credErr), contains('Incorrect email or password'));

      final userErr = FirebaseAuthException(code: 'user-not-found');
      expect(GuardAuthService.mapAuthError(userErr), contains('No user account found'));

      final disabledErr = FirebaseAuthException(code: 'user-disabled');
      expect(GuardAuthService.mapAuthError(disabledErr), contains('disabled'));

      final rateErr = FirebaseAuthException(code: 'too-many-requests');
      expect(GuardAuthService.mapAuthError(rateErr), contains('Too many failed login attempts'));

      final permErr = FirebaseAuthException(code: 'permission-denied');
      expect(GuardAuthService.mapAuthError(permErr), contains('Access permission denied'));
    });
  });
}
