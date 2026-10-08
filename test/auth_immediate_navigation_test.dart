import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_parking_system/core/localization/app_language_controller.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/screens/admin/admin_navigation_shell.dart';
import 'package:car_parking_system/screens/admin/auth/admin_login_screen.dart';
import 'package:car_parking_system/screens/guard/auth/auth_gate.dart';
import 'package:car_parking_system/screens/guard/auth/guard_login_screen.dart';
import 'package:car_parking_system/screens/guard/guard_navigation_shell.dart';
import 'package:car_parking_system/services/guard_auth_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;

  FakeUser({required this.uid, this.email});
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  FakeUserCredential({this.user});
}

class TestGuardAuthService extends GuardAuthService {
  final StreamController<User?> _authController = StreamController<User?>.broadcast();
  User? _testCurrentUser;
  final Map<String, GuardModel> _guardDatabase = {};
  bool shouldFailAuth = false;
  String failAuthErrorCode = 'wrong-password';

  TestGuardAuthService() : super();

  void addGuard(GuardModel guard) {
    _guardDatabase[guard.uid] = guard;
    if (guard.email.isNotEmpty) {
      _guardDatabase[guard.email.toLowerCase()] = guard;
    }
  }

  void emitUser(User? user) {
    _testCurrentUser = user;
    _authController.add(user);
  }

  @override
  Stream<User?> get authStateChanges async* {
    yield _testCurrentUser;
    yield* _authController.stream;
  }

  @override
  User? get currentUser => _testCurrentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldFailAuth) {
      throw FirebaseAuthException(code: failAuthErrorCode, message: 'Invalid credentials');
    }
    final cleanEmail = email.trim().toLowerCase();
    final guard = _guardDatabase[cleanEmail] ??
        _guardDatabase.values.firstWhere(
          (g) => g.email.toLowerCase() == cleanEmail,
          orElse: () => GuardModel(
            uid: 'test_uid_fallback',
            name: 'Test Fallback',
            email: email,
            role: 'guard',
            isActive: true,
          ),
        );
    final user = FakeUser(uid: guard.uid, email: guard.email);
    _testCurrentUser = user;
    _authController.add(user);
    return FakeUserCredential(user: user);
  }

  @override
  Future<GuardModel?> getGuardProfile(String uid, [String? email]) async {
    final cleanUid = uid.trim();
    final cleanEmail = email?.trim().toLowerCase();
    if (_guardDatabase.containsKey(cleanUid)) {
      final g = _guardDatabase[cleanUid]!;
      setCachedProfile(g);
      return g;
    }
    if (cleanEmail != null && _guardDatabase.containsKey(cleanEmail)) {
      final g = _guardDatabase[cleanEmail]!;
      setCachedProfile(g);
      return g;
    }
    return null;
  }

  @override
  Stream<GuardModel?> watchGuardProfile(String uid, [String? email]) async* {
    final profile = await getGuardProfile(uid, email);
    yield profile;
  }

  @override
  Future<void> signOut() async {
    _testCurrentUser = null;
    setCachedProfile(null);
    _authController.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGuardAuthService authService;
  late GuardModel validGuard;
  late GuardModel validAdmin;
  late GuardModel inactiveGuard;
  late GuardModel inactiveAdmin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageController.instance.init();

    // In unit widget tests without live Firebase, ignore background stream connection warnings
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exception.toString();
      if (msg.contains('no-app') || msg.contains('Firebase App') || msg.contains('core/no-app')) {
        return;
      }
      FlutterError.presentError(details);
    };

    authService = TestGuardAuthService();

    validGuard = GuardModel(
      uid: 'guard_123',
      name: 'Ramesh Guard',
      email: 'guard@system.com',
      role: 'guard',
      isActive: true,
    );

    validAdmin = GuardModel(
      uid: 'admin_456',
      name: 'Super Admin',
      email: 'admin@system.com',
      role: 'admin',
      isActive: true,
    );

    inactiveGuard = GuardModel(
      uid: 'inactive_guard_789',
      name: 'Inactive Guard',
      email: 'inactive_guard@system.com',
      role: 'guard',
      isActive: false,
    );

    inactiveAdmin = GuardModel(
      uid: 'inactive_admin_999',
      name: 'Inactive Admin',
      email: 'inactive_admin@system.com',
      role: 'admin',
      isActive: false,
    );

    authService.addGuard(validGuard);
    authService.addGuard(validAdmin);
    authService.addGuard(inactiveGuard);
    authService.addGuard(inactiveAdmin);
  });

  void setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestApp({AuthPortal portal = AuthPortal.guard}) {
    return MaterialApp(
      home: AuthGate(
        initialPortal: portal,
        authService: authService,
      ),
    );
  }

  Future<void> pumpShellTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    tester.takeException();
  }

  group('AUTHENTICATION & IMMEDIATE NAVIGATION REGRESSION TEST SUITE', () {
    testWidgets('1. Guard valid login -> Guard Dashboard immediately without refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      expect(find.byType(GuardLoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);

      expect(find.byType(GuardNavigationShell), findsOneWidget);
      expect(find.byType(GuardLoginScreen), findsNothing);
    });

    testWidgets('2. Admin valid login -> Admin Dashboard immediately without refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.admin));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.adminLogin));
      await pumpShellTransition(tester);

      expect(find.byType(AdminNavigationShell), findsOneWidget);
      expect(find.byType(AdminLoginScreen), findsNothing);
    });

    testWidgets('3. Guard invalid login -> stays on Guard Login with error message', (tester) async {
      setTestSurfaceSize(tester);
      authService.shouldFailAuth = true;

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong_password');
      await tester.tap(find.text(AppStrings.signIn));
      await tester.pumpAndSettle();

      expect(find.byType(GuardLoginScreen), findsOneWidget);
      expect(find.byType(GuardNavigationShell), findsNothing);
      expect(find.text(GuardAuthService.mapAuthError(FirebaseAuthException(code: 'wrong-password'))), findsOneWidget);
    });

    testWidgets('4. Admin invalid login -> stays on Admin Login with error message', (tester) async {
      setTestSurfaceSize(tester);
      authService.shouldFailAuth = true;

      await tester.pumpWidget(createTestApp(portal: AuthPortal.admin));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong_password');
      await tester.tap(find.text(AppStrings.adminLogin));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminNavigationShell), findsNothing);
      expect(find.text(GuardAuthService.mapAuthError(FirebaseAuthException(code: 'wrong-password'))), findsOneWidget);
    });

    testWidgets('5. Guard account cannot access Admin Portal', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.admin));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.adminLogin));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminNavigationShell), findsNothing);
      expect(find.text(AppStrings.unauthorizedAdminAccess), findsOneWidget);
    });

    testWidgets('6. Admin account logging into Guard portal routes to AdminNavigationShell', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);

      expect(find.byType(AdminNavigationShell), findsOneWidget);
      expect(find.byType(GuardNavigationShell), findsNothing);
    });

    testWidgets('7. Inactive account blocked on login', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'inactive_guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await tester.pumpAndSettle();

      expect(find.byType(GuardLoginScreen), findsOneWidget);
      expect(find.byType(GuardNavigationShell), findsNothing);
      expect(find.text(AppStrings.accountInactive), findsOneWidget);
    });

    testWidgets('8. Auth session restoration after page refresh', (tester) async {
      setTestSurfaceSize(tester);

      authService.emitUser(FakeUser(uid: validAdmin.uid, email: validAdmin.email));

      await tester.pumpWidget(createTestApp());
      await pumpShellTransition(tester);

      expect(find.byType(AdminNavigationShell), findsOneWidget);
      expect(find.byType(AdminLoginScreen), findsNothing);
      expect(find.byType(GuardLoginScreen), findsNothing);
    });

    testWidgets('9. No duplicate dashboard navigation', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);

      expect(find.byType(GuardNavigationShell), findsOneWidget);
    });

    testWidgets('10. Login state changes without requiring refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.admin));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.adminLogin));
      await pumpShellTransition(tester);

      expect(find.byType(AdminNavigationShell), findsOneWidget);
    });

    testWidgets('11. Logout returns to login screen', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);

      expect(find.byType(GuardNavigationShell), findsOneWidget);

      await authService.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(GuardLoginScreen), findsOneWidget);
      expect(find.byType(GuardNavigationShell), findsNothing);
    });

    testWidgets('12. Login -> logout -> login again works immediately without refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      // First login
      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);
      expect(find.byType(GuardNavigationShell), findsOneWidget);

      // Logout
      await authService.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(GuardLoginScreen), findsOneWidget);

      // Second login
      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);
      expect(find.byType(GuardNavigationShell), findsOneWidget);
    });

    testWidgets('13. Admin login -> logout -> Guard login works immediately without refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.admin));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      // Admin Login
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.adminLogin));
      await pumpShellTransition(tester);
      expect(find.byType(AdminNavigationShell), findsOneWidget);

      // Logout
      await authService.signOut();
      await tester.pumpAndSettle();

      // Switch to Guard portal if on Admin
      if (find.text(AppStrings.switchToGuardPrompt).evaluate().isNotEmpty) {
        await tester.tap(find.text(AppStrings.switchToGuardPrompt));
        await tester.pumpAndSettle();
      }

      expect(find.byType(GuardLoginScreen), findsOneWidget);

      // Guard Login
      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);
      expect(find.byType(GuardNavigationShell), findsOneWidget);
    });

    testWidgets('14. Guard login -> logout -> Admin login works immediately without refresh', (tester) async {
      setTestSurfaceSize(tester);

      await tester.pumpWidget(createTestApp(portal: AuthPortal.guard));
      authService.emitUser(null);
      await tester.pumpAndSettle();

      // Guard Login
      await tester.enterText(find.byType(TextFormField).at(0), 'guard@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.signIn));
      await pumpShellTransition(tester);
      expect(find.byType(GuardNavigationShell), findsOneWidget);

      // Logout
      await authService.signOut();
      await tester.pumpAndSettle();

      // Switch to Admin portal
      await tester.tap(find.text(AppStrings.switchToAdminPrompt));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);

      // Admin Login
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@system.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text(AppStrings.adminLogin));
      await pumpShellTransition(tester);
      expect(find.byType(AdminNavigationShell), findsOneWidget);
    });
  });
}
