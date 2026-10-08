import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/guard_auth_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';

/// ForgotPasswordScreen enables guards and staff to securely request a password reset email
/// via standard Firebase Authentication.
class ForgotPasswordScreen extends StatefulWidget {
  final GuardAuthService? authService;

  const ForgotPasswordScreen({
    super.key,
    this.authService,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final GuardAuthService _guardAuthService;

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  String? _sentEmailAddress;

  @override
  void initState() {
    super.initState();
    _guardAuthService = widget.authService ?? GuardAuthService.instance;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Sends Firebase Authentication password reset email.
  Future<void> _handleSendResetEmail() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      await _guardAuthService.sendPasswordResetEmail(email);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _emailSent = true;
        _sentEmailAddress = email;
        _errorMessage = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = GuardAuthService.mapAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppLanguageController.instance.isMarathi
            ? 'नेटवर्क एरर. कृपया तुमचे इंटरनेट कनेक्शन तपासा.'
            : 'Could not send password reset email. Please verify connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMarathi = AppLanguageController.instance.isMarathi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.resetPasswordTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: _emailSent ? _buildSuccessView(isMarathi) : _buildFormView(isMarathi),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isMarathi) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon Header
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset,
                color: AppColors.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            AppStrings.resetPasswordTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            AppStrings.resetPasswordSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Error Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Email Field
          AppTextField(
            controller: _emailController,
            labelText: AppStrings.emailLabel,
            hintText: AppStrings.emailHint,
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
          const SizedBox(height: 20),

          // Submit Button
          AppButton(
            label: AppStrings.sendResetLink,
            isLoading: _isLoading,
            onPressed: _handleSendResetEmail,
          ),
          const SizedBox(height: 12),

          // Back to Login Link
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.backToLogin,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isMarathi) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.resetLinkSent,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_sentEmailAddress != null) ...[
          Text(
            _sentEmailAddress!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          isMarathi
              ? 'कृपया तुमचा इनबॉक्स आणि स्पॅम फोल्डर तपासा. दिलेल्या लिंकवर क्लिक करून नवीन पासवर्ड सेट करा.'
              : 'Please check your inbox and spam folder. Click the link in the email to set a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: AppStrings.backToLogin,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
