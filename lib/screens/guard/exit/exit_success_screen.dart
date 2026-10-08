import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../widgets/common/app_button.dart';
import 'exit_receipt_screen.dart';

/// ExitSuccessScreen displayed immediately following successful settlement and slot release.
class ExitSuccessScreen extends StatelessWidget {
  final ParkingRecord record;
  final VoidCallback onReturnDashboard;
  final VoidCallback onExitAnotherVehicle;

  const ExitSuccessScreen({
    super.key,
    required this.record,
    required this.onReturnDashboard,
    required this.onExitAnotherVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleTypeLabel = record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    final hasRefund = (record.refundAmount ?? 0) > 0;
    final hasBalance = (record.balanceDue ?? 0) > 0;
    final paymentMethodLabel = (record.paymentMethod ?? 'CASH').toUpperCase() == 'CASH'
        ? AppStrings.cash
        : (record.paymentMethod ?? 'CASH').toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppStrings.vehicleExitSettledTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.vehicleExitSettledSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Settlement Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildRow(AppStrings.ticketNumber, record.ticketNumber, isBold: true),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.vehicleNumber, record.vehicleNumber, isHighlight: true),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.vehicleType, vehicleTypeLabel),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(record.entryTime)),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.exitDateTime, record.exitTime != null ? AppFormatters.formatDateTime(record.exitTime!) : 'N/A'),
                          const SizedBox(height: 8),
                          _buildRow(
                            AppStrings.stayDuration,
                            record.exitTime != null ? AppFormatters.formatDuration(record.exitTime!.difference(record.entryTime)) : 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.grossParkingCharge, AppFormatters.formatCurrency(record.grossCharge ?? 0.0)),
                          if (record.advanceAmount > 0) ...[
                            const SizedBox(height: 8),
                            _buildRow(AppStrings.advanceAdjusted, '- ${AppFormatters.formatCurrency(record.advanceAmount)}'),
                          ],
                          const SizedBox(height: 8),
                          if (hasBalance)
                            _buildRow(
                              AppStrings.finalBalancePaid,
                              '${AppFormatters.formatCurrency(record.balanceDue!)} ($paymentMethodLabel)',
                              isHighlight: true,
                            )
                          else if (hasRefund)
                            _buildRow(
                              AppStrings.refundHandedBack,
                              '${AppFormatters.formatCurrency(record.refundAmount!)} ($paymentMethodLabel)',
                              isHighlight: true,
                              color: AppColors.warningDark,
                            )
                          else
                            _buildRow(AppStrings.finalSettlement, '₹0', isHighlight: true),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.paymentMethod, paymentMethodLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons - ONLY View Final Exit Receipt
                    AppButton(
                      key: const ValueKey('view_final_exit_receipt_button'),
                      label: AppStrings.viewFinalExitReceipt,
                      icon: Icons.receipt_long,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExitReceiptScreen(
                              record: record,
                              onDone: onReturnDashboard,
                            ),
                          ),
                        );
                      },
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

  Widget _buildRow(String label, String value, {bool isBold = false, bool isHighlight = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: (isBold || isHighlight) ? FontWeight.w700 : FontWeight.w600,
              color: color ?? (isHighlight ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
