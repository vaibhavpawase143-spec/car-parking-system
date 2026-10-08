import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/parking_service.dart';
import '../../../widgets/common/status_badge.dart';
import 'exit_charge_screen.dart';

/// Dedicated verification screen shown AFTER vehicle lookup (QR scan, ticket search,
/// or active parking search) and BEFORE calculating fees or executing settlement.
/// Requires the Guard to confirm vehicle identity and active parking status.
class VehicleExitVerificationScreen extends StatelessWidget {
  final ParkingRecord record;
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final VoidCallback onExitAnotherVehicle;
  final ParkingService? parkingService;

  const VehicleExitVerificationScreen({
    super.key,
    required this.record,
    required this.currentGuard,
    required this.onReturnDashboard,
    required this.onExitAnotherVehicle,
    this.parkingService,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleTypeLabel = record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    final entryDateStr = AppFormatters.formatDate(record.entryTime);
    final entryTimeStr = AppFormatters.formatTime(record.entryTime);
    final advanceStr = record.advanceAmount > 0
        ? '${AppFormatters.formatCurrency(record.advanceAmount)} (${record.advancePaymentMethod.toUpperCase() == 'CASH' ? AppStrings.cash : record.advancePaymentMethod.toUpperCase()})'
        : '₹0';
    final mobileStr = record.customerMobile.trim().isNotEmpty
        ? record.customerMobile.trim()
        : 'N/A';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.verifyVehicleForExit),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Badge Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.exitVerification,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppColors.successDark),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.activeParking.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.successDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Mandatory Vehicle Photo Preview
                    if (record.photoUrl != null && record.photoUrl!.isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            record.photoUrl!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 120,
                              color: AppColors.surfaceVariant,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.no_photography_outlined, size: 26, color: AppColors.textMuted),
                                    const SizedBox(height: 6),
                                    Text(
                                      AppStrings.photoNoLongerAvailable,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.no_photography_outlined, size: 26, color: AppColors.textMuted),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.photoNoLongerAvailable,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Vehicle Number & Type Header Box
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppFormatters.normalizeVehicleNumber(record.vehicleNumber),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(record.vehicleType.icon, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                vehicleTypeLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Verified Vehicle Detail Rows
                    _buildDetailRow(AppStrings.ticketNumber, record.ticketNumber, isBold: true),
                    _buildDetailRow(AppStrings.entryDate, entryDateStr),
                    _buildDetailRow(AppStrings.entryTime, entryTimeStr),
                    _buildDetailRow(AppStrings.guard, record.entryGuardName),
                    _buildDetailRow(AppStrings.shift, record.entryShift),
                    _buildDetailRow(AppStrings.customerMobile, mobileStr),
                    if (record.isMonthlyPass)
                      _buildDetailRow(
                        AppStrings.monthlyPass,
                        '${AppStrings.yes} (${AppStrings.parkingFee}: ₹0)',
                        isBold: true,
                        color: AppColors.successDark,
                      )
                    else
                      _buildDetailRow(
                        AppStrings.advancePaid,
                        advanceStr,
                        isBold: record.advanceAmount > 0,
                        color: record.advanceAmount > 0 ? AppColors.successDark : null,
                      ),
                    _buildDetailRow(AppStrings.status, AppStrings.active, isBadge: true),
                    const SizedBox(height: 16),

                    Text(
                      AppStrings.verifyVehicleNotice,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 20),

                    // Primary Action: Confirm Vehicle
                    ElevatedButton.icon(
                      key: const ValueKey('confirm_vehicle_exit_button'),
                      icon: const Icon(Icons.check, size: 20, color: Colors.white),
                      label: Text(
                        AppStrings.confirmVehicle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExitChargeScreen(
                              record: record,
                              currentGuard: currentGuard,
                              onReturnDashboard: onReturnDashboard,
                              onExitAnotherVehicle: onExitAnotherVehicle,
                              parkingService: parkingService,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Cancel / Back Button
                    OutlinedButton(
                      key: const ValueKey('cancel_vehicle_verification_button'),
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(AppStrings.cancelSearchAgain),
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color, bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          if (isBadge)
            StatusBadge(label: AppStrings.active, type: BadgeType.active)
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
