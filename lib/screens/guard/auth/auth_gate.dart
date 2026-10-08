import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/guard_model.dart';
import '../../../services/guard_auth_service.dart';
import '../../admin/admin_navigation_shell.dart';
import '../../admin/auth/admin_login_screen.dart';
import '../guard_navigation_shell.dart';
import 'access_denied_screen.dart';
import 'guard_login_screen.dart';

/// Portal selector for unauthenticated state in AuthGate.
enum AuthPortal { guard, admin }

/// AuthGate enforces session routing:
/// - Unauthenticated -> GuardLoginScreen or AdminLoginScreen (switched in-place without destroying AuthGate)
/// - Authenticated + Valid Active Admin -> AdminNavigationShell
/// - Authenticated + Valid Active Guard -> GuardNavigationShell
/// - Authenticated + Non-Guard/Inactive -> AccessDeniedScreen
class AuthGate extends StatefulWidget {
  final AuthPortal initialPortal;
  final GuardAuthService? authService;

  const AuthGate({
    super.key,
    this.initialPortal = AuthPortal.guard,
    this.authService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late AuthPortal _currentPortal;
  late final GuardAuthService _guardAuthService;

  @override
  void initState() {
    super.initState();
    _currentPortal = widget.initialPortal;
    _guardAuthService = widget.authService ?? GuardAuthService.instance;
  }

  void _switchToAdmin() {
    if (mounted) {
      setState(() {
        _currentPortal = AuthPortal.admin;
      });
    }
  }

  void _switchToGuard() {
    if (mounted) {
      setState(() {
        _currentPortal = AuthPortal.guard;
      });
    }
  }

  Widget _buildShellForProfile(GuardModel guard, User user) {
    if (!guard.isActive) {
      debugPrint('[AUTH DEBUG] Inactive account for: ${guard.name} (${guard.uid}). Showing AccessDeniedScreen.');
      return AccessDeniedScreen(user: user, guardProfile: guard);
    }

    if (guard.isAdmin) {
      debugPrint('[AUTH DEBUG] Routing immediately to AdminNavigationShell for: ${guard.name} (${guard.uid})');
      return AdminNavigationShell(currentAdmin: guard);
    }

    if (guard.isGuard) {
      debugPrint('[AUTH DEBUG] Routing immediately to GuardNavigationShell for: ${guard.name} (${guard.uid})');
      return GuardNavigationShell(currentGuard: guard);
    }

    debugPrint('[AUTH DEBUG] User has neither admin nor guard role: ${guard.role}. Showing AccessDeniedScreen.');
    return AccessDeniedScreen(user: user, guardProfile: guard);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _guardAuthService.authStateChanges,
      builder: (context, authSnapshot) {
        // Checking Firebase Auth session
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Initializing session...');
        }

        final user = authSnapshot.data;

        // Not authenticated: render active portal without replacing AuthGate
        if (user == null) {
          if (_currentPortal == AuthPortal.admin) {
            return AdminLoginScreen(
              key: const ValueKey('AdminLoginPortal'),
              authService: _guardAuthService,
              onSwitchToGuard: _switchToGuard,
            );
          }
          return GuardLoginScreen(
            key: const ValueKey('GuardLoginPortal'),
            authService: _guardAuthService,
            onSwitchToAdmin: _switchToAdmin,
          );
        }

        // Authenticated: Fast path via synchronously cached profile
        return ValueListenableBuilder<GuardModel?>(
          valueListenable: _guardAuthService.currentProfileNotifier,
          builder: (context, cachedProfile, _) {
            if (cachedProfile != null &&
                (cachedProfile.uid == user.uid ||
                 (user.email != null && cachedProfile.email.toLowerCase() == user.email!.toLowerCase()))) {
              return _buildShellForProfile(cachedProfile, user);
            }

            // Fallback: Stream guard profile from Firestore (e.g. cold page refresh / session restore)
            return StreamBuilder<GuardModel?>(
              stream: _guardAuthService.watchGuardProfile(user.uid, user.email),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState == ConnectionState.waiting &&
                    !profileSnapshot.hasData) {
                  return const _LoadingScreen(message: 'Verifying credentials...');
                }

                if (profileSnapshot.hasError) {
                  debugPrint('[AUTH DEBUG] Firestore profile lookup error: ${profileSnapshot.error}');
                  return Scaffold(
                    backgroundColor: AppColors.background,
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync_problem, size: 54, color: AppColors.danger),
                            const SizedBox(height: 16),
                            const Text(
                              'Unable to Load Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${profileSnapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _guardAuthService.signOut(),
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign Out & Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final guard = profileSnapshot.data;
                if (guard == null) {
                  debugPrint('[AUTH DEBUG] Profile missing in Firestore for UID: ${user.uid}. Showing AccessDeniedScreen.');
                  return AccessDeniedScreen(
                    user: user,
                    guardProfile: null,
                  );
                }

                return _buildShellForProfile(guard, user);
              },
            );
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;

  const _LoadingScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
