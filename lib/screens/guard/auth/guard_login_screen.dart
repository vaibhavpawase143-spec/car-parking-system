import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/guard_auth_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/settings/language_settings_dialog.dart';
import '../../admin/auth/admin_login_screen.dart';
import 'forgot_password_screen.dart';

/// GuardLoginScreen provides secure email & password authentication for guards.
class GuardLoginScreen extends StatefulWidget {
  final VoidCallback? onSwitchToAdmin;
  final GuardAuthService? authService;

  const GuardLoginScreen({
    super.key,
    this.onSwitchToAdmin,
    this.authService,
  });

  @override
  State<GuardLoginScreen> createState() => _GuardLoginScreenState();
}

class _GuardLoginScreenState extends State<GuardLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final GuardAuthService _guardAuthService;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _guardAuthService = widget.authService ?? GuardAuthService.instance;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    debugPrint('========================================');
    debugPrint('[LOGIN DEBUG] Login form submission started');
    debugPrint('[LOGIN DEBUG] Email: $email');

    try {
      final credential = await _guardAuthService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        debugPrint('[LOGIN DEBUG] Fetching guard profile for UID: ${user.uid} (email: ${user.email})');
        final profile = await _guardAuthService.getGuardProfile(user.uid, user.email);
        if (profile != null) {
          if (!profile.isActive) {
            debugPrint('[LOGIN DEBUG] Guard account inactive for: ${profile.name}');
            await _guardAuthService.signOut();
            if (mounted) {
              setState(() {
                _errorMessage = AppStrings.accountInactive;
              });
            }
            return;
          }
          _guardAuthService.setCachedProfile(profile);
        }
      }
      debugPrint('[LOGIN DEBUG] Login succeeded for UID: ${user?.uid}');
      debugPrint('========================================');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // AuthGate automatically detects authenticated user and routes immediately
    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN DEBUG] FirebaseAuthException caught: code=${e.code}, message=${e.message}');
      debugPrint('========================================');
      if (mounted) {
        setState(() {
          _errorMessage = GuardAuthService.mapAuthError(e);
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('[LOGIN DEBUG] FirebaseException caught: plugin=${e.plugin}, code=${e.code}, message=${e.message}');
      debugPrint('========================================');
      if (mounted) {
        setState(() {
          _errorMessage = 'Firebase service error (${e.code}): ${e.message ?? 'Please retry.'}';
        });
      }
    } catch (e, st) {
      debugPrint('[LOGIN DEBUG] Non-Firebase exception during login: ${e.runtimeType}: $e\n$st');
      debugPrint('========================================');
      if (mounted) {
        setState(() {
          _errorMessage = 'Login encountered an unexpected error (${e.runtimeType}). Please try again.';
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
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_parking,
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
                      Text(
                        AppStrings.signInSubtitle,
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
                        hintText: 'guard@parking.com',
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
                      const SizedBox(height: 4),

                      // 3. Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Submit Button
                      AppButton(
                        label: AppStrings.signIn,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),

                      // 5. Switch to Admin Login (Prominent, accessible outlined button)
                      OutlinedButton.icon(
                        onPressed: () {
                          if (widget.onSwitchToAdmin != null) {
                            widget.onSwitchToAdmin!();
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminLoginScreen(),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                        label: Text(
                          AppStrings.switchToAdminPrompt,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primaryLight),
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
  }
}
