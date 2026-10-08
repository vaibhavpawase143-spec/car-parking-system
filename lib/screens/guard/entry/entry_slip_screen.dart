import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/common/qr_view_widget.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/printer/bluetooth_printer_dialog.dart';

/// EntrySlipScreen displays the printable/viewable digital parking ticket with QR.
/// State machine:
/// - STATE 2: Entry Slip opened -> Shows ONLY [ Print Slip ].
/// - STATE 3: Print successful -> Shows [ Print Slip ] and [ Send WhatsApp ].
/// - STATE 4: WhatsApp prepared/opened -> Navigates DIRECTLY to Dashboard.
/// - STATE 5: Print cancel/failure -> Remains on slip with [ Print Slip ].
/// - STATE 6: WhatsApp open failure -> Remains on slip with [ Send WhatsApp ] and error feedback.
class EntrySlipScreen extends StatefulWidget {
  final ParkingRecord record;
  final VoidCallback? onReturnDashboard;

  const EntrySlipScreen({
    super.key,
    required this.record,
    this.onReturnDashboard,
  });

  @override
  State<EntrySlipScreen> createState() => _EntrySlipScreenState();
}

class _EntrySlipScreenState extends State<EntrySlipScreen> {
  bool _isPrintSuccessful = false;
  bool _isPrinting = false;
  bool _isSendingWhatsApp = false;

  ParkingRecord get record => widget.record;

  Future<void> _handlePrintSlip() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      final printTriggered = await ReceiptPrintService.print58mmEntrySlip(record);
      if (!mounted) return;

      setState(() {
        _isPrinting = false;
      });

      if (!printTriggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.printFailedNotice),
            backgroundColor: AppColors.danger,
            action: !kIsWeb
                ? SnackBarAction(
                    label: AppStrings.printer,
                    textColor: Colors.white,
                    onPressed: () => BluetoothPrinterDialog.show(context),
                  )
                : null,
          ),
        );
        return;
      }

      // Prompt Guard for acceptance of the physical/browser print
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.print, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                AppStrings.printConfirmation,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            AppStrings.printConfirmationDesc,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              key: const ValueKey('print_confirm_cancel_button'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancelRetry),
            ),
            ElevatedButton(
              key: const ValueKey('print_confirm_success_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.yesPrinted),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmed == true) {
        // STATE 3: PRINT SUCCESSFUL
        setState(() {
          _isPrintSuccessful = true;
          _isPrinting = false;
        });
      } else {
        // STATE 5: PRINT CANCEL / RETRY
        setState(() {
          _isPrintSuccessful = false;
          _isPrinting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.printCancelledNotice),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.error}: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleSendWhatsApp() async {
    final mobile = record.customerMobile.trim();
    if (!WhatsAppService.isValidCustomerMobile(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.invalidMobile),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSendingWhatsApp = true;
    });

    try {
      final opened = await WhatsAppService.openWhatsApp(context, record);
      if (!mounted) return;

      setState(() {
        _isSendingWhatsApp = false;
      });

      if (opened) {
        if (widget.onReturnDashboard != null) {
          widget.onReturnDashboard!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingWhatsApp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.error}: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypeLabel = record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    final advanceMethodLabel = record.advancePaymentMethod.toUpperCase() == 'CASH'
        ? AppStrings.cash
        : record.advancePaymentMethod.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.entrySlipTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
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
            constraints: const BoxConstraints(maxWidth: 420),
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
                        Flexible(
                          child: Text(
                            AppStrings.appName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.entryReceiptTitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Vector QR Code (Actual QR generated for this parking entry)
                    QrViewWidget(
                      data: record.qrReference ?? record.ticketNumber,
                      size: 160,
                      subtitle: record.ticketNumber,
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Number & Type
                    Container(
                      width: double.infinity,
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
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 18),

                    // Key-Value Ticket Details (All 14 Required Fields)
                    _buildDetailRow(AppStrings.ticketNumber, record.ticketNumber),
                    _buildDetailRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(record.entryTime)),
                    _buildDetailRow(AppStrings.guard, record.entryGuardName),
                    _buildDetailRow(AppStrings.shift, record.entryShift),
                    if (record.customerMobile.isNotEmpty)
                      _buildDetailRow(AppStrings.customerMobile, record.customerMobile),
                    _buildDetailRow(
                      AppStrings.advancePaid,
                      record.advanceAmount > 0
                          ? '${AppFormatters.formatCurrency(record.advanceAmount)} ($advanceMethodLabel)'
                          : '₹0',
                      highlight: record.advanceAmount > 0,
                    ),
                    _buildDetailRow(AppStrings.status, AppStrings.active, isBadge: true),
                    const SizedBox(height: 16),

                    // Vehicle photo preview thumbnail & Mandatory status
                    if (record.photoUrl != null && record.photoUrl!.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              record.photoUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: AppColors.surfaceVariant,
                                child: const Icon(Icons.broken_image, size: 24, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.mandatoryPhotoCaptured,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.storedSecurely,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      AppStrings.keepSlipSafe,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 18),

                    // Action: Print Slip (Always visible on slip)
                    ElevatedButton.icon(
                      key: const ValueKey('slip_print_button'),
                      onPressed: _isPrinting ? null : _handlePrintSlip,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print, size: 18, color: Colors.white),
                      label: Text(
                        _isPrinting ? AppStrings.printing : AppStrings.printSlip,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),

                    // Action: Send WhatsApp (ONLY visible after successful print)
                    if (_isPrintSuccessful) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        key: const ValueKey('slip_send_whatsapp_button'),
                        onPressed: _isSendingWhatsApp ? null : _handleSendWhatsApp,
                        icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                        label: Text(
                          _isSendingWhatsApp ? AppStrings.openingWhatsApp : AppStrings.sendWhatsApp,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.opensWhatsAppNotice,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false, bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
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
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                  color: highlight ? AppColors.successDark : AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
