import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../widgets/common/app_button.dart';
import 'entry_slip_screen.dart';

/// EntrySuccessScreen displayed immediately after a vehicle entry record is successfully created in Firestore.
/// STATE 1 — ENTRY CONFIRMED:
/// Shows ONLY [ View Entry Slip & QR ].
/// All other actions (Send WhatsApp, Print Slip, Active Parking, New Entry, Dashboard) remain strictly hidden.
class EntrySuccessScreen extends StatelessWidget {
  final ParkingRecord record;
  final VoidCallback onReturnDashboard;
  final VoidCallback onViewActiveParking;
  final VoidCallback onNewEntry;

  const EntrySuccessScreen({
    super.key,
    required this.record,
    required this.onReturnDashboard,
    required this.onViewActiveParking,
    required this.onNewEntry,
  });

  Future<void> _viewEntrySlipAndQr(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntrySlipScreen(
          record: record,
          onReturnDashboard: () {
            Navigator.pop(context); // Pop EntrySlipScreen
            onReturnDashboard();   // Pop EntrySuccessScreen and switch tab to Dashboard
          },
        ),
      ),
    );

    if (result == true) {
      onReturnDashboard();
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
                      AppStrings.entryConfirmedTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.entryConfirmedSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Key details container (Ticket, Vehicle, Type, Time, Mobile, Advance)
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
                          _buildRow(
                            AppStrings.vehicleNumber,
                            AppFormatters.normalizeVehicleNumber(record.vehicleNumber),
                            isHighlight: true,
                          ),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.vehicleType, vehicleTypeLabel),
                          const SizedBox(height: 8),
                          _buildRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(record.entryTime)),
                          if (record.customerMobile.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildRow(AppStrings.customerMobile, record.customerMobile),
                          ],
                          if (record.advanceAmount > 0) ...[
                            const SizedBox(height: 8),
                            _buildRow(
                              AppStrings.advancePaid,
                              '${AppFormatters.formatCurrency(record.advanceAmount)} ($advanceMethodLabel)',
                              isBold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // STATE 1: ONLY [ View Entry Slip & QR ]
                    AppButton(
                      key: const ValueKey('view_entry_slip_button'),
                      label: AppStrings.viewSlipAndQr,
                      icon: Icons.receipt_long,
                      onPressed: () => _viewEntrySlipAndQr(context),
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

  Widget _buildRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: (isBold || isHighlight) ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
