import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/shift_model.dart';
import '../../../models/system_settings_model.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/common/app_button.dart';
import '../audit/admin_audit_log_screen.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/settings/language_settings_dialog.dart';

/// Admin Settings Screen displaying parking rates, capacities, business profile,
/// language controls, and operational configurations, backed by Firestore.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _settingsService = SettingsService.instance;

  void _openEditSettingsModal(SystemSettingsModel current) {
    final formKey = GlobalKey<FormState>();

    // Controllers
    final carCapController = TextEditingController(text: current.carTotalCapacity.toString());
    final bikeCapController = TextEditingController(text: current.twoWheelerTotalCapacity.toString());

    final bikeFirstRateController = TextEditingController(text: current.twoWheelerFirstHourRate.toStringAsFixed(0));
    final bikeAddRateController = TextEditingController(text: current.twoWheelerAdditionalHourRate.toStringAsFixed(0));
    final bikeCapRateController = TextEditingController(text: current.twoWheeler12HourCap.toStringAsFixed(0));
    final bikeMonthRateController = TextEditingController(text: current.twoWheelerMonthlyRate.toStringAsFixed(0));

    final carFirstRateController = TextEditingController(text: current.fourWheelerFirstHourRate.toStringAsFixed(0));
    final carAddRateController = TextEditingController(text: current.fourWheelerAdditionalHourRate.toStringAsFixed(0));
    final carCapRateController = TextEditingController(text: current.fourWheeler12HourCap.toStringAsFixed(0));
    final carMonthRateController = TextEditingController(text: current.fourWheelerMonthlyRate.toStringAsFixed(0));

    final enNameController = TextEditingController(text: current.englishName);
    final mrNameController = TextEditingController(text: current.marathiName);
    final enLocController = TextEditingController(text: current.englishLocation);
    final mrLocController = TextEditingController(text: current.marathiLocation);
    final mobileController = TextEditingController(text: current.mobile);
    final mrMobileController = TextEditingController(text: current.marathiMobile);

    int selectedDefaultDuration = current.defaultShiftDurationHours;
    List<int> selectedAllowedDurations = List<int>.from(
      current.allowedShiftDurations.where((d) => ShiftModel.allowedShiftDurations.contains(d)),
    );
    if (selectedAllowedDurations.isEmpty) {
      selectedAllowedDurations = List<int>.from(ShiftModel.allowedShiftDurations);
    }
    if (!selectedAllowedDurations.contains(selectedDefaultDuration)) {
      selectedDefaultDuration = selectedAllowedDurations.first;
    }
    bool cashEnabled = current.cashEnabled;
    bool upiEnabled = current.upiEnabled;
    bool advanceEnabled = current.advanceEnabled;
    bool singleActiveDeviceEnabled = current.singleActiveDeviceEnabled;

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.edit,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Section 1: Capacities
                        Text(AppStrings.capacitySettings, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: carCapController,
                                labelText: AppStrings.fourWheelerCapacity,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setModalState(() {}),
                                validator: (v) {
                                  final val = int.tryParse(v ?? '');
                                  if (val == null || val <= 0) return AppStrings.mustBeGreaterThanZero;
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: bikeCapController,
                                labelText: AppStrings.twoWheelerCapacity,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setModalState(() {}),
                                validator: (v) {
                                  final val = int.tryParse(v ?? '');
                                  if (val == null || val <= 0) return AppStrings.mustBeGreaterThanZero;
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${AppStrings.totalCalculatedCapacity}:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                '${(int.tryParse(carCapController.text) ?? 0) + (int.tryParse(bikeCapController.text) ?? 0)} ${AppStrings.slots}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 2: Shift Settings
                        Text(AppStrings.shiftSettings, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 10),
                        Text(AppStrings.allowedShiftDurations, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ShiftModel.allowedShiftDurations.map((hrs) {
                            final isAllowed = selectedAllowedDurations.contains(hrs);
                            return FilterChip(
                              label: Text(AppStrings.formatShiftDuration(hrs)),
                              selected: isAllowed,
                              selectedColor: AppColors.primaryLight.withValues(alpha: 0.3),
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) {
                                    if (!selectedAllowedDurations.contains(hrs)) {
                                      selectedAllowedDurations.add(hrs);
                                      selectedAllowedDurations.sort();
                                    }
                                  } else {
                                    if (selectedAllowedDurations.length > 1) {
                                      selectedAllowedDurations.remove(hrs);
                                      if (!selectedAllowedDurations.contains(selectedDefaultDuration)) {
                                        selectedDefaultDuration = selectedAllowedDurations.first;
                                      }
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: selectedAllowedDurations.contains(selectedDefaultDuration)
                              ? selectedDefaultDuration
                              : selectedAllowedDurations.first,
                          decoration: InputDecoration(
                            labelText: AppStrings.defaultShiftDuration,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: selectedAllowedDurations.map((d) {
                            return DropdownMenuItem(value: d, child: Text('$d ${AppStrings.hours}'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedDefaultDuration = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Section 3: Payment Settings
                        Text(AppStrings.paymentOperations, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(AppStrings.cashCollectionEnabled, style: const TextStyle(fontSize: 14)),
                            value: cashEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setModalState(() => cashEnabled = v),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(AppStrings.upiCollectionEnabled, style: const TextStyle(fontSize: 14)),
                            value: upiEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setModalState(() => upiEnabled = v),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(AppStrings.advanceFeeEnabled, style: const TextStyle(fontSize: 14)),
                            value: advanceEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setModalState(() => advanceEnabled = v),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(AppStrings.singleActiveDeviceMode, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(AppStrings.singleActiveDeviceSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            value: singleActiveDeviceEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setModalState(() => singleActiveDeviceEnabled = v),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 4: Two-Wheeler Rates
                        Text('${AppStrings.twoWheeler} ${AppStrings.rateChart}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: bikeFirstRateController,
                                    labelText: '${AppStrings.firstHour} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: bikeAddRateController,
                                    labelText: '${AppStrings.additionalHour} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: bikeCapRateController,
                                    labelText: '${AppStrings.twelveHourCap} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: bikeMonthRateController,
                                    labelText: '${AppStrings.monthlyPass} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 5: Four-Wheeler Rates
                        Text('${AppStrings.fourWheeler} ${AppStrings.rateChart}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: carFirstRateController,
                                    labelText: '${AppStrings.firstHour} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: carAddRateController,
                                    labelText: '${AppStrings.additionalHour} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: carCapRateController,
                                    labelText: '${AppStrings.twelveHourCap} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: carMonthRateController,
                                    labelText: '${AppStrings.monthlyPass} (₹)',
                                    keyboardType: TextInputType.number,
                                    validator: (v) => (double.tryParse(v ?? '') == null || double.parse(v!) < 0) ? AppStrings.invalidAmount : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 6: Business Profile
                        Text(AppStrings.businessProfileSection, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: enNameController,
                          labelText: AppStrings.facilityNameEnglish,
                          validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: mrNameController,
                          labelText: AppStrings.facilityNameMarathi,
                          validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: enLocController,
                          labelText: AppStrings.addressEnglish,
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: mrLocController,
                          labelText: AppStrings.addressMarathi,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: mobileController,
                                labelText: AppStrings.contactPhone,
                                keyboardType: TextInputType.phone,
                                validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: mrMobileController,
                                labelText: AppStrings.contactPhoneMarathi,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                                child: Text(AppStrings.cancel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setModalState(() => isSaving = true);
                                        final nav = Navigator.of(ctx);
                                        final messenger = ScaffoldMessenger.of(context);

                                        try {
                                          final updated = current.copyWith(
                                            carTotalCapacity: int.parse(carCapController.text.trim()),
                                            twoWheelerTotalCapacity: int.parse(bikeCapController.text.trim()),
                                            twoWheelerFirstHourRate: double.parse(bikeFirstRateController.text.trim()),
                                            twoWheelerAdditionalHourRate: double.parse(bikeAddRateController.text.trim()),
                                            twoWheeler12HourCap: double.parse(bikeCapRateController.text.trim()),
                                            twoWheelerMonthlyRate: double.parse(bikeMonthRateController.text.trim()),
                                            fourWheelerFirstHourRate: double.parse(carFirstRateController.text.trim()),
                                            fourWheelerAdditionalHourRate: double.parse(carAddRateController.text.trim()),
                                            fourWheeler12HourCap: double.parse(carCapRateController.text.trim()),
                                            fourWheelerMonthlyRate: double.parse(carMonthRateController.text.trim()),
                                            englishName: enNameController.text.trim(),
                                            marathiName: mrNameController.text.trim(),
                                            englishLocation: enLocController.text.trim(),
                                            marathiLocation: mrLocController.text.trim(),
                                            mobile: mobileController.text.trim(),
                                            marathiMobile: mrMobileController.text.trim(),
                                            defaultShiftDurationHours: selectedDefaultDuration,
                                            allowedShiftDurations: selectedAllowedDurations,
                                            cashEnabled: cashEnabled,
                                            upiEnabled: upiEnabled,
                                            advanceEnabled: advanceEnabled,
                                            singleActiveDeviceEnabled: singleActiveDeviceEnabled,
                                          );

                                          await _settingsService.saveSettings(
                                            settings: updated,
                                            adminUid: 'admin',
                                            adminName: 'Admin',
                                          );

                                          nav.pop();
                                          messenger.showSnackBar(
                                            SnackBar(content: Text(AppStrings.profileUpdatedSuccess)),
                                          );
                                        } catch (e) {
                                          setModalState(() => isSaving = false);
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('${AppStrings.error}: $e')),
                                          );
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(AppStrings.save),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCapacityDialog(SystemSettingsModel settings) {
    final formKey = GlobalKey<FormState>();
    final carCapCtrl = TextEditingController(text: settings.carTotalCapacity.toString());
    final bikeCapCtrl = TextEditingController(text: settings.twoWheelerTotalCapacity.toString());
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final carVal = int.tryParse(carCapCtrl.text) ?? 0;
            final bikeVal = int.tryParse(bikeCapCtrl.text) ?? 0;
            final total = carVal + bikeVal;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.local_parking, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(AppStrings.editCapacity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMsg!,
                            style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      AppTextField(
                        controller: carCapCtrl,
                        labelText: AppStrings.fourWheelerCapacity,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.directions_car,
                        onChanged: (_) => setDialogState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: bikeCapCtrl,
                        labelText: AppStrings.twoWheelerCapacity,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.two_wheeler,
                        onChanged: (_) => setDialogState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${AppStrings.totalCalculatedCapacity}:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('$total ${AppStrings.slots}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSaving = true;
                            errorMsg = null;
                          });
                          try {
                            await _settingsService.updateCapacity(
                              fourWheelerCapacity: int.parse(carCapCtrl.text.trim()),
                              twoWheelerCapacity: int.parse(bikeCapCtrl.text.trim()),
                              adminUid: 'admin',
                              adminName: 'Admin',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppStrings.capacityUpdatedSuccess)),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMsg = '$e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<SystemSettingsModel>(
        stream: _settingsService.watchSettings(),
        initialData: _settingsService.currentSettings,
        builder: (context, snapshot) {
          final settings = snapshot.data ?? const SystemSettingsModel();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Edit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.adminSettings,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openEditSettingsModal(settings),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(AppStrings.edit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Language & Display
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.languageSettingsTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppStrings.appUiLanguageSection, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          AppLanguageController.instance.isMarathi ? 'मराठी (Marathi)' : 'English',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => LanguageSettingsDialog.show(context),
                          child: Text(AppStrings.languageSettingsTitle),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Parking Capacity Settings
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_parking, color: AppColors.accent, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.capacitySettings,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openCapacityDialog(settings),
                            icon: const Icon(Icons.edit, size: 14),
                            label: Text(AppStrings.editCapacity, style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSettingRow(
                        AppStrings.fourWheelerCapacity,
                        '${settings.carTotalCapacity} ${AppStrings.slots}',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        AppStrings.twoWheelerCapacity,
                        '${settings.twoWheelerTotalCapacity} ${AppStrings.slots}',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        AppStrings.totalParkingCapacity,
                        '${settings.carTotalCapacity + settings.twoWheelerTotalCapacity} ${AppStrings.slots}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Shift Settings Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.shiftConfiguration,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSettingRow(
                        AppStrings.defaultShiftDuration,
                        '${settings.defaultShiftDurationHours} ${AppStrings.hours}',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        AppStrings.allowedShiftDurations,
                        settings.allowedShiftDurations.map((d) => '$d ${AppStrings.hours}').join(', '),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Operations Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: AppColors.accent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.paymentOperations,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSettingRow(
                        AppStrings.cashCollectionEnabled,
                        settings.cashEnabled ? AppStrings.enabled : AppStrings.disabled,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        AppStrings.upiCollectionEnabled,
                        settings.upiEnabled ? AppStrings.enabled : AppStrings.disabled,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        AppStrings.advanceFeeEnabled,
                        settings.advanceEnabled ? AppStrings.enabled : AppStrings.disabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Device Security & Session Control Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.devices, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.singleActiveDeviceMode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AppStrings.singleActiveDeviceMode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            AppStrings.singleActiveDeviceSubtitle,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          value: settings.singleActiveDeviceEnabled,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) async {
                            try {
                              final updated = settings.copyWith(singleActiveDeviceEnabled: val);
                              await _settingsService.saveSettings(
                                settings: updated,
                                adminUid: 'admin',
                                adminName: 'Admin',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(val
                                        ? '${AppStrings.singleActiveDeviceMode}: ${AppStrings.enabled}'
                                        : '${AppStrings.singleActiveDeviceMode}: ${AppStrings.disabled}'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${AppStrings.error}: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Official Parking Rate Chart
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.currency_rupee, color: AppColors.success, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.rateChart,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        '${AppStrings.twoWheeler}:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      _buildRateItem(AppStrings.firstHour, AppFormatters.formatCurrency(settings.twoWheelerFirstHourRate)),
                      _buildRateItem(AppStrings.additionalHour, '${AppFormatters.formatCurrency(settings.twoWheelerAdditionalHourRate)} / hr'),
                      _buildRateItem(AppStrings.twelveHourCap, AppFormatters.formatCurrency(settings.twoWheeler12HourCap)),
                      _buildRateItem(AppStrings.monthlyPass, AppFormatters.formatCurrency(settings.twoWheelerMonthlyRate)),
                      const SizedBox(height: 14),
                      Text(
                        '${AppStrings.fourWheeler}:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      _buildRateItem(AppStrings.firstHour, AppFormatters.formatCurrency(settings.fourWheelerFirstHourRate)),
                      _buildRateItem(AppStrings.additionalHour, '${AppFormatters.formatCurrency(settings.fourWheelerAdditionalHourRate)} / hr'),
                      _buildRateItem(AppStrings.twelveHourCap, AppFormatters.formatCurrency(settings.fourWheeler12HourCap)),
                      _buildRateItem(AppStrings.monthlyPass, AppFormatters.formatCurrency(settings.fourWheelerMonthlyRate)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Business Profile
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, color: AppColors.primaryDark, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.businessProfileSection,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSettingRow(AppStrings.facilityNameEnglish, settings.englishName),
                      const SizedBox(height: 10),
                      _buildSettingRow(AppStrings.facilityNameMarathi, settings.marathiName),
                      const SizedBox(height: 10),
                      _buildSettingRow(AppStrings.addressEnglish, settings.englishLocation),
                      const SizedBox(height: 10),
                      _buildSettingRow(AppStrings.addressMarathi, settings.marathiLocation),
                      const SizedBox(height: 10),
                      _buildSettingRow(AppStrings.contactPhone, settings.mobile),
                      const SizedBox(height: 10),
                      _buildSettingRow(AppStrings.contactPhoneMarathi, settings.marathiMobile),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. System Audit Trail
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.systemSecurityAuditTrail,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        AppStrings.auditTrailDescription,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: AppStrings.viewAuditLogs,
                        icon: Icons.history,
                        type: AppButtonType.outline,
                        onPressed: () => AdminAuditLogScreen.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
      ],
    );
  }

  Widget _buildRateItem(String tier, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tier, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(rate, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
