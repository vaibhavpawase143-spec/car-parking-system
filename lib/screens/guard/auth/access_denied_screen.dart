import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/guard_model.dart';
import '../../../services/guard_auth_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/status_badge.dart';

/// Screen displayed when an authenticated Firebase user lacks active Guard role privileges.
class AccessDeniedScreen extends StatefulWidget {
  final User user;
  final GuardModel? guardProfile;

  const AccessDeniedScreen({
    super.key,
    required this.user,
    this.guardProfile,
  });

  @override
  State<AccessDeniedScreen> createState() => _AccessDeniedScreenState();
}

class _AccessDeniedScreenState extends State<AccessDeniedScreen> {
  final _guardAuthService = GuardAuthService();

  @override
  Widget build(BuildContext context) {
    final hasDoc = widget.guardProfile != null;
    final isInactive = hasDoc && !widget.guardProfile!.isActive;
    final isWrongRole = hasDoc && widget.guardProfile!.role.toLowerCase() != 'guard';

    String reason;
    if (isInactive) {
      reason = AppStrings.accountInactive;
    } else if (isWrongRole) {
      reason = 'This account is registered with role "${widget.guardProfile!.role}". Guard Portal access is restricted to Guard accounts only.';
    } else {
      reason = 'No Guard profile document was found in Firestore for this account.';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.gpp_bad_outlined,
                        color: AppColors.danger,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Access Restricted',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // User Details Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Authenticated User',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              StatusBadge(
                                label: hasDoc ? widget.guardProfile!.role.toUpperCase() : 'NO ROLE',
                                type: BadgeType.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Email: ${widget.user.email ?? 'Unknown'}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'UID: ${widget.user.uid}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),


                    AppButton(
                      label: 'Sign Out / Switch Account',
                      type: AppButtonType.outline,
                      icon: Icons.logout,
                      onPressed: () => _guardAuthService.signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
