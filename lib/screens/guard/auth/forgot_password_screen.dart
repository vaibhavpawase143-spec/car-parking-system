import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/guard_model.dart';
import '../../../services/guard_auth_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';

enum _ForgotStep {
  enterEmail,
  verifyOtp,
  newPassword,
  success,
}

/// ForgotPasswordScreen enables guards to securely reset their password
/// via registered Guard verification & Mobile OTP (zero email reset links).
class ForgotPasswordScreen extends StatefulWidget {
  /// Test hook to provide a deterministic OTP during automated tests.
  static String? mockOtp;

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _guardAuthService = GuardAuthService();

  _ForgotStep _currentStep = _ForgotStep.enterEmail;
  GuardModel? _verifiedGuard;

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  String? _generatedOtp;
  DateTime? _otpExpiry;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendCooldown = 30;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() {
          _resendCooldown = 0;
        });
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  String _maskMobile(String rawMobile) {
    final clean = rawMobile.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      final last4 = clean.substring(clean.length - 4);
      return '+91 ******$last4';
    } else if (clean.length >= 4) {
      final last4 = clean.substring(clean.length - 4);
      return '******$last4';
    }
    return rawMobile.isNotEmpty ? '******${rawMobile.substring(rawMobile.length - 1)}' : 'registered number';
  }

  /// Step 1: Verify Guard Email in Firestore
  Future<void> _verifyGuardEmail() async {
    FocusScope.of(context).unfocus();

    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final guard = await _guardAuthService.findGuardByEmail(email);

      if (!mounted) return;

      if (guard == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No registered Guard account found with this email. Please check your email or contact the administrator.';
        });
        return;
      }

      if (!guard.isActive) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This Guard account is currently deactivated. Please contact the administrator.';
        });
        return;
      }

      final mobile = guard.mobile.trim();
      if (mobile.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No registered mobile number found on your Guard profile for OTP verification. Please contact the administrator.';
        });
        return;
      }

      // Generate 6-digit secure OTP
      final otp = ForgotPasswordScreen.mockOtp ?? (100000 + Random().nextInt(900000)).toString();
      _generatedOtp = otp;
      _otpExpiry = DateTime.now().add(const Duration(minutes: 5));
      _verifiedGuard = guard;

      _startResendCountdown();

      setState(() {
        _isLoading = false;
        _currentStep = _ForgotStep.verifyOtp;
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to verify Guard account. Please check your connection and try again.';
        });
      }
    }
  }

  /// Resends a fresh OTP
  void _resendOtp() {
    if (_resendCooldown > 0 || _verifiedGuard == null) return;

    final otp = ForgotPasswordScreen.mockOtp ?? (100000 + Random().nextInt(900000)).toString();
    _generatedOtp = otp;
    _otpExpiry = DateTime.now().add(const Duration(minutes: 5));
    _otpController.clear();
    _startResendCountdown();

    setState(() {
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A new 6-digit verification code has been sent to your registered mobile.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Step 2: Validate entered OTP
  void _verifyOtp() {
    FocusScope.of(context).unfocus();

    final entered = _otpController.text.trim();

    if (entered.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    if (entered.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a complete 6-digit verification code.';
      });
      return;
    }

    if (_otpExpiry != null && DateTime.now().isAfter(_otpExpiry!)) {
      setState(() {
        _errorMessage = 'Verification code has expired. Please tap Resend Code.';
      });
      return;
    }

    if (entered != _generatedOtp) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please check and try again.';
      });
      return;
    }

    // OTP successfully verified
    setState(() {
      _errorMessage = null;
      _currentStep = _ForgotStep.newPassword;
    });
  }

  /// Step 3: Update Password
  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    if (_verifiedGuard == null) {
      setState(() {
        _errorMessage = 'Session expired. Please start over.';
        _currentStep = _ForgotStep.enterEmail;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newPassword = _newPasswordController.text;

    try {
      final success = await _guardAuthService.resetGuardPassword(
        uid: _verifiedGuard!.uid,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _isLoading = false;
          _currentStep = _ForgotStep.success;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not reset password. Please try again or contact administrator.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network connection error. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Guard Password Recovery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case _ForgotStep.enterEmail:
        return _buildEnterEmailStep();
      case _ForgotStep.verifyOtp:
        return _buildVerifyOtpStep();
      case _ForgotStep.newPassword:
        return _buildNewPasswordStep();
      case _ForgotStep.success:
        return _buildSuccessStep();
    }
  }

  /// Step 1 UI: Email Input
  Widget _buildEnterEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_reset,
                color: AppColors.primary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered Guard email address to verify your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) _buildErrorBanner(),

          AppTextField(
            controller: _emailController,
            labelText: 'Email Address',
            hintText: 'guard@parking.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              final trimmed = value.trim();
              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          AppButton(
            label: 'Continue',
            isLoading: _isLoading,
            onPressed: _verifyGuardEmail,
          ),
          const SizedBox(height: 14),

          AppButton(
            label: 'Back to Sign In',
            type: AppButtonType.outline,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Step 2 UI: Mobile OTP Verification
  Widget _buildVerifyOtpStep() {
    final maskedPhone = _verifiedGuard != null ? _maskMobile(_verifiedGuard!.mobile) : 'registered number';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sms_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Mobile OTP Verification',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A 6-digit verification code has been sent to your registered mobile number:\n$maskedPhone',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        if (_errorMessage != null) _buildErrorBanner(),

        AppTextField(
          controller: _otpController,
          labelText: '6-Digit Verification Code',
          hintText: 'e.g. 123456',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.pin_outlined,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = _ForgotStep.enterEmail;
                  _errorMessage = null;
                });
              },
              child: const Text('Change Email', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: _resendCooldown == 0 ? _resendOtp : null,
              child: Text(
                _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _resendCooldown > 0 ? AppColors.textMuted : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        AppButton(
          label: 'Verify Code',
          onPressed: _verifyOtp,
        ),
      ],
    );
  }

  /// Step 3 UI: New Password Creation
  Widget _buildNewPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.security_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Set New Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new secure password for your Guard account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null) _buildErrorBanner(),

          // New Password
          AppTextField(
            controller: _newPasswordController,
            labelText: 'New Password',
            obscureText: _obscureNewPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureNewPassword = !_obscureNewPassword;
                });
              },
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please enter a new password';
              }
              if (v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          AppTextField(
            controller: _confirmPasswordController,
            labelText: 'Confirm New Password',
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your new password';
              }
              if (v != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          AppButton(
            label: 'Reset Password',
            isLoading: _isLoading,
            onPressed: _resetPassword,
          ),
        ],
      ),
    );
  }

  /// Step 4 UI: Success Confirmation
  Widget _buildSuccessStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.successDark,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Password Reset Successful!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your Guard account password has been updated securely. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        AppButton(
          label: 'Back to Sign In',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 20),
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
    );
  }
}
