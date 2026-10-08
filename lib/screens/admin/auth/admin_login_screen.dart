import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/guard_auth_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/settings/language_settings_dialog.dart';
import '../../guard/auth/guard_login_screen.dart';

/// AdminLoginScreen provides secure authentication strictly for system administrators.
class AdminLoginScreen extends StatefulWidget {
  final VoidCallback? onSwitchToGuard;
  final GuardAuthService? authService;

  const AdminLoginScreen({
    super.key,
    this.onSwitchToGuard,
    this.authService,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final GuardAuthService _authService;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? GuardAuthService.instance;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('[ADMIN LOGIN] BUTTON PRESSED');
    FocusScope.of(context).unfocus();

    debugPrint('[ADMIN LOGIN] FORM VALIDATION START');
    final isValid = _formKey.currentState!.validate();
    debugPrint('[ADMIN LOGIN] FORM VALIDATION RESULT: $isValid');
    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      debugPrint('[ADMIN LOGIN] AUTH START');
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('User authentication failed.');
      }
      debugPrint('[ADMIN LOGIN] AUTH SUCCESS');
      debugPrint('[ADMIN LOGIN] AUTH UID: ${user.uid}');

      // Verify Admin role in Firestore
      debugPrint('[ADMIN LOGIN] PROFILE FETCH START');
      final profile = await _authService.getGuardProfile(user.uid, user.email);
      debugPrint('[ADMIN LOGIN] PROFILE FETCH RESULT: ${profile != null ? "found(role=${profile.role}, active=${profile.isActive})" : "null"}');

      debugPrint('[ADMIN LOGIN] ADMIN ROLE CHECK');
      if (profile == null || !profile.isAdmin) {
        debugPrint('[ADMIN LOGIN] ADMIN ROLE CHECK FAILED (isAdmin=${profile?.isAdmin})');
        // Guard account or unauthorized user attempting Admin login
        await _authService.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = AppStrings.unauthorizedAdminAccess;
          });
        }
        return;
      }

      if (!profile.isActive) {
        debugPrint('[ADMIN LOGIN] ADMIN ACTIVE CHECK FAILED');
        await _authService.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = 'This Admin account has been disabled by the system.';
          });
        }
        return;
      }

      debugPrint('[ADMIN LOGIN] NAVIGATION START');
      _authService.setCachedProfile(profile);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // Success: AuthGate will automatically route to AdminNavigationShell immediately
    } on FirebaseAuthException catch (e) {
      debugPrint('[ADMIN LOGIN] FirebaseAuthException: ${e.code} ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = GuardAuthService.mapAuthError(e);
        });
      }
    } catch (e) {
      debugPrint('[ADMIN LOGIN] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Login encountered an error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Language Switcher Row
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.language, size: 16),
                              label: Text(
                                AppLanguageController.instance.isMarathi ? 'मराठी' : 'English',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              onPressed: () => LanguageSettingsDialog.show(context),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Header Branding
                          Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            AppStrings.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            AppStrings.companyBrand,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                AppStrings.adminPortal,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.adminSignInSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Error Alert Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.dangerDark,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.dangerDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. Email input
                          AppTextField(
                            controller: _emailController,
                            labelText: AppStrings.emailLabel,
                            hintText: 'admin@parking.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppStrings.emailRequired;
                              }
                              final trimmed = value.trim();
                              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                                return AppStrings.invalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // 2. Password input
                          AppTextField(
                            controller: _passwordController,
                            labelText: AppStrings.passwordLabel,
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.passwordRequired;
                              }
                              if (value.length < 6) {
                                return AppStrings.passwordTooShort;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 4. Submit Button
                          AppButton(
                            label: AppStrings.adminLogin,
                            isLoading: _isLoading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 12),

                          // 5. Switch to Guard Login (Prominent, accessible outlined button)
                          OutlinedButton.icon(
                            onPressed: () {
                              if (widget.onSwitchToGuard != null) {
                                widget.onSwitchToGuard!();
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GuardLoginScreen(),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: Text(
                              AppStrings.switchToGuardPrompt,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
