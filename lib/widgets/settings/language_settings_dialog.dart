// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/config/business_profile.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_language_controller.dart';
import '../../core/theme/app_colors.dart';

/// Modal dialog for configuring global application language, BizFlow branding footer,
/// and viewing business profile identity.
class LanguageSettingsDialog extends StatefulWidget {
  const LanguageSettingsDialog({super.key});

  /// Displays the settings dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LanguageSettingsDialog(),
    );
  }

  @override
  State<LanguageSettingsDialog> createState() => _LanguageSettingsDialogState();
}

class _LanguageSettingsDialogState extends State<LanguageSettingsDialog> {
  late AppLanguage _selectedAppLang;
  late bool _bizflowBranding;

  @override
  void initState() {
    super.initState();
    _selectedAppLang = AppLanguageController.instance.currentLanguage;
    _bizflowBranding = BusinessProfileController.instance.profile.bizflowBrandingEnabled;
  }

  Future<void> _saveAndClose() async {
    await AppLanguageController.instance.setLanguage(_selectedAppLang);
    await BusinessProfileController.instance.updateProfile(
      bizflowBrandingEnabled: _bizflowBranding,
    );

    if (mounted) {
      Navigator.pop(context);
      final s = AppLanguageController.instance.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.settingsSavedNotice),
          backgroundColor: AppColors.successDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLanguageController.instance.strings;
    final bp = BusinessProfileController.instance.profile;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.language, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.languageSettingsTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. App UI Language Selection (Controls entire app & receipts globally)
            Text(
              s.appUiLanguageSection,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  RadioListTile<AppLanguage>(
                    dense: true,
                    title: const Text('English', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      _selectedAppLang == AppLanguage.english ? 'Selected' : 'English UI & Receipts',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: AppLanguage.english,
                    groupValue: _selectedAppLang,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAppLang = val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<AppLanguage>(
                    dense: true,
                    title: const Text('मराठी (Marathi)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _selectedAppLang == AppLanguage.marathi ? 'निवडले आहे' : 'मराठी युझर इंटरफेस व पावत्या',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: AppLanguage.marathi,
                    groupValue: _selectedAppLang,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAppLang = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. BizFlow Branding Toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                dense: true,
                title: Text(
                  s.bizflowBrandingSwitch,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Powered by BIZFLOW Parking Management System',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                value: _bizflowBranding,
                onChanged: (val) => setState(() => _bizflowBranding = val),
              ),
            ),
            const SizedBox(height: 18),

            // 3. Business Identity Card Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        s.businessProfileSection,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${bp.marathiName} / ${bp.englishName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${bp.marathiLocation} (${bp.englishLocation})',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${s.businessMobileLabel} ${bp.marathiMobile} (${bp.mobile})',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton.icon(
          onPressed: _saveAndClose,
          icon: const Icon(Icons.check, size: 16),
          label: Text(s.save),
        ),
      ],
    );
  }
}
