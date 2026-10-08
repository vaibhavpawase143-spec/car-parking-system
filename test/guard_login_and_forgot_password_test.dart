import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/services/guard_auth_service.dart';
import 'package:car_parking_system/widgets/common/app_text_field.dart';
import 'package:car_parking_system/screens/guard/auth/guard_login_screen.dart';
import 'package:car_parking_system/screens/guard/auth/forgot_password_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();
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
    testWidgets('1. GuardLoginScreen renders ONLY Email, Password, Login button, and Forgot Password link', (tester) async {
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

      // 3. Forgot Password? link is present
      expect(find.text('Forgot Password?'), findsOneWidget);

      // 4. Demo Login & Register buttons are completely REMOVED
      expect(find.textContaining('Demo Guard'), findsNothing);
      expect(find.textContaining('Register Guard Account'), findsNothing);
      expect(find.textContaining('First time setup'), findsNothing);
      expect(find.textContaining('⚡ Quick Login'), findsNothing);
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

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('3. ForgotPasswordScreen starts with Step 1 (Enter Email)', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guard Password Recovery'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);

      // Tap Continue with empty email
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('4. ForgotPasswordScreen components and step verification', (tester) async {
      setTestSurfaceSize(tester);
      ForgotPasswordScreen.mockOtp = '654321';

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Type email
      await tester.enterText(find.byType(TextFormField).first, 'guard@test.com');
      await tester.pumpAndSettle();

      // Verify widget layout and components
      expect(find.text('Continue'), findsOneWidget);
    });

    test('5. GuardAuthService.mapAuthError accurately differentiates all error codes', () {
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
