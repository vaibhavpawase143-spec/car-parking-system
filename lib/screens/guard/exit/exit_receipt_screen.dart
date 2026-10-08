import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/qr_view_widget.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/printer/bluetooth_printer_dialog.dart';

/// ExitReceiptScreen displays the comprehensive digital exit invoice,
/// detailing duration, rates, advance adjustments, final settlement, and full cross-shift audit trails.
class ExitReceiptScreen extends StatelessWidget {
  final ParkingRecord record;
  final VoidCallback onDone;

  const ExitReceiptScreen({
    super.key,
    required this.record,
    required this.onDone,
  });

  void _handleDone(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypeLabel = record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    final duration = record.exitTime != null
        ? record.exitTime!.difference(record.entryTime)
        : Duration.zero;

    final advanceMethodLabel = record.advancePaymentMethod.toUpperCase() == 'CASH'
        ? (AppLanguageController.instance.isMarathi ? 'रोख' : 'CASH')
        : record.advancePaymentMethod.toUpperCase();

    final paymentMethodLabel = (record.paymentMethod ?? 'CASH').toUpperCase() == 'CASH'
        ? (AppLanguageController.instance.isMarathi ? 'रोख' : 'CASH')
        : (record.paymentMethod ?? 'CASH').toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.exitReceiptTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleDone(context),
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: AppStrings.printer,
              onPressed: () => BluetoothPrinterDialog.show(context),
            ),
        ],
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
                  children: [
                    // Facility Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_parking, color: AppColors.primary, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.exitReceiptTitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),

                    // Vector QR Code
                    QrViewWidget(
                      data: record.qrReference ?? record.ticketNumber,
                      size: 140,
                      subtitle: record.ticketNumber,
                    ),
                    const SizedBox(height: 18),

                    // Vehicle Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                    ),
                    const SizedBox(height: 16),

                    // Parking Stay & Timing Details
                    _buildDetailRow(AppStrings.ticketNumber, record.ticketNumber),
                    _buildDetailRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(record.entryTime)),
                    if (record.exitTime != null)
                      _buildDetailRow(AppStrings.exitDateTime, AppFormatters.formatDateTime(record.exitTime!)),
                    _buildDetailRow(AppStrings.stayDuration, AppFormatters.formatDuration(duration), isHighlight: true),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Financial Accounting & Fee Settlement
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.stayDurationAndCharges,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(AppStrings.grossParkingCharge, AppFormatters.formatCurrency(record.grossCharge ?? 0.0)),
                    if (record.advanceAmount > 0) ...[
                      _buildDetailRow(
                        AppStrings.advancePaid,
                        '${AppFormatters.formatCurrency(record.advanceAmount)} ($advanceMethodLabel)',
                      ),
                      _buildDetailRow(
                        AppStrings.advanceAdjusted,
                        '- ${AppFormatters.formatCurrency(record.advanceAmount)}',
                        color: AppColors.successDark,
                      ),
                    ],
                    if ((record.balanceDue ?? 0) > 0)
                      _buildDetailRow(
                        AppStrings.finalBalancePaid,
                        '${AppFormatters.formatCurrency(record.balanceDue!)} ($paymentMethodLabel)',
                        isHighlight: true,
                      ),
                    if ((record.refundAmount ?? 0) > 0)
                      _buildDetailRow(
                        AppStrings.refundHandedBack,
                        '${AppFormatters.formatCurrency(record.refundAmount!)} ($paymentMethodLabel)',
                        color: AppColors.warningDark,
                        isHighlight: true,
                      ),
                    if ((record.balanceDue ?? 0) == 0 && (record.refundAmount ?? 0) == 0)
                      _buildDetailRow(AppStrings.finalSettlement, '₹0', isHighlight: true),
                    _buildDetailRow(AppStrings.paymentMethod, paymentMethodLabel),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Cross-Shift Audit Log
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.crossShiftAudit,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAuditRow(AppStrings.entryGuard, '${record.entryGuardName} (${record.entryShift})'),
                    if (record.advanceAmount > 0 && record.advanceCollectorShift != null)
                      _buildAuditRow(AppStrings.advanceCollector, '${record.advanceCollectorGuardName ?? record.entryGuardName} (${record.advanceCollectorShift})'),
                    if (record.exitGuardName != null)
                      _buildAuditRow(AppStrings.exitGuard, '${record.exitGuardName} (${record.exitShift ?? 'Shift 1'})'),

                    const SizedBox(height: 16),
                    StatusBadge(label: AppStrings.settledAndExited, type: BadgeType.exited),
                    const SizedBox(height: 20),

                    // Send WhatsApp Exit Receipt
                    AppButton(
                      key: const ValueKey('exit_send_whatsapp_button'),
                      label: AppStrings.sendWhatsApp,
                      icon: Icons.chat,
                      type: AppButtonType.secondary,
                      onPressed: () => WhatsAppService.openExitWhatsApp(context, record),
                    ),
                    const SizedBox(height: 12),

                    // Print Exit Receipt (58mm Thermal)
                    AppButton(
                      key: const ValueKey('print_exit_receipt_button'),
                      label: AppStrings.printExitReceipt,
                      icon: Icons.print,
                      onPressed: () async {
                        final success = await ReceiptPrintService.print58mmExitReceipt(record);
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.printSuccessNotice),
                                backgroundColor: AppColors.successDark,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.printFailedNotice),
                                backgroundColor: AppColors.danger,
                                duration: const Duration(seconds: 4),
                                action: !kIsWeb
                                    ? SnackBarAction(
                                        label: AppStrings.printer,
                                        textColor: Colors.white,
                                        onPressed: () => BluetoothPrinterDialog.show(context),
                                      )
                                    : null,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Done Button returning to Guard Dashboard
                    AppButton(
                      key: const ValueKey('exit_receipt_done_button'),
                      label: AppStrings.done,
                      type: AppButtonType.outline,
                      icon: Icons.check,
                      onPressed: () => _handleDone(context),
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

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: color ?? (isHighlight ? AppColors.primary : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
