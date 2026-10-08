import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/parking_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/status_badge.dart';
import 'exit_success_screen.dart';

/// ExitChargeScreen calculates the live parking charge, adjusts for advance payments,
/// supports Cash tender calculation and UPI receipt confirmation, and executes atomic settlement.
class ExitChargeScreen extends StatefulWidget {
  final ParkingRecord record;
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final VoidCallback onExitAnotherVehicle;
  final ParkingService? parkingService;

  const ExitChargeScreen({
    super.key,
    required this.record,
    required this.currentGuard,
    required this.onReturnDashboard,
    required this.onExitAnotherVehicle,
    this.parkingService,
  });

  @override
  State<ExitChargeScreen> createState() => _ExitChargeScreenState();
}

class _ExitChargeScreenState extends State<ExitChargeScreen> {
  late final ParkingService _parkingService;
  final _tenderController = TextEditingController();

  late DateTime _exitTime;
  late FeeCalculationResult _calculation;

  String _paymentMethod = 'cash'; // 'cash' or 'upi'
  bool _upiConfirmed = false;
  bool _refundConfirmed = false;
  bool _isSettling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _parkingService = widget.parkingService ?? ParkingService();
    _exitTime = DateTime.now();
    _calculation = FeeCalculator.calculate(
      vehicleType: widget.record.vehicleType,
      entryTime: widget.record.entryTime,
      exitTime: _exitTime,
      advancePaid: widget.record.advanceAmount,
      isMonthlyPass: widget.record.isMonthlyPass,
    );
    _tenderController.text = _calculation.balanceDue > 0 ? _calculation.balanceDue.toInt().toString() : '0';
  }

  @override
  void dispose() {
    _tenderController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _exitTime = DateTime.now();
      _calculation = FeeCalculator.calculate(
        vehicleType: widget.record.vehicleType,
        entryTime: widget.record.entryTime,
        exitTime: _exitTime,
        advancePaid: widget.record.advanceAmount,
        isMonthlyPass: widget.record.isMonthlyPass,
      );
      _tenderController.text = _calculation.balanceDue > 0 ? _calculation.balanceDue.toInt().toString() : '0';
    });
  }

  Future<void> _executeSettlement() async {
    // 1. Validation for UPI payment
    if (_calculation.balanceDue > 0 && _paymentMethod == 'upi' && !_upiConfirmed) {
      setState(() {
        _errorMessage = AppStrings.confirmUpiReceivedNotice;
      });
      return;
    }

    // 2. Validation for Refund
    if (_calculation.refundAmount > 0 && !_refundConfirmed) {
      setState(() {
        _errorMessage = AppStrings.confirmRefundHandedNotice;
      });
      return;
    }

    setState(() {
      _isSettling = true;
      _errorMessage = null;
    });

    try {
      final settledRecord = await _parkingService.settleVehicleExit(
        ticketId: widget.record.ticketNumber,
        vehicleNumber: widget.record.vehicleNumber,
        vehicleType: widget.record.vehicleType,
        entryTime: widget.record.entryTime,
        exitTime: _exitTime,
        grossCharge: _calculation.grossCharge,
        advancePaid: widget.record.advanceAmount,
        balanceDue: _calculation.balanceDue,
        refundAmount: _calculation.refundAmount,
        paymentMethod: _paymentMethod,
        exitGuardUid: widget.currentGuard.uid,
        exitGuardName: widget.currentGuard.name,
        exitGuardShift: widget.currentGuard.currentShift,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExitSuccessScreen(
              record: settledRecord,
              onReturnDashboard: widget.onReturnDashboard,
              onExitAnotherVehicle: widget.onExitAnotherVehicle,
            ),
          ),
        );
      }
    } on VehicleAlreadyExitedException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppStrings.error}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypeLabel = widget.record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;
    final shortTypeLabel = widget.record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.bikes
        : AppStrings.cars;

    final hasBalance = _calculation.balanceDue > 0;
    final hasRefund = _calculation.refundAmount > 0;
    final isZeroSettlement = !hasBalance && !hasRefund;

    final tenderAmount = double.tryParse(_tenderController.text.trim()) ?? 0.0;
    final changeDue = (tenderAmount - _calculation.balanceDue).clamp(0.0, 99999.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.exitFeeSettlement),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.recalculate,
            onPressed: _isSettling ? null : _recalculate,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error Alert Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
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
                  ),
                ],

                // Historical Vehicle Details Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle Photo (if available)
                        if (widget.record.photoUrl != null && widget.record.photoUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.record.photoUrl!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 100,
                                width: double.infinity,
                                color: AppColors.surfaceVariant,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.no_photography_outlined, color: AppColors.textMuted, size: 20),
                                    const SizedBox(width: 8),
                                    Text(AppStrings.photoNoLongerAvailable, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 140,
                                  color: AppColors.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(widget.record.vehicleType.icon, size: 22, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  widget.record.vehicleNumber,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(label: shortTypeLabel, type: BadgeType.info),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        _buildInfoRow(AppStrings.ticketNumber, widget.record.ticketNumber),
                        _buildInfoRow(AppStrings.vehicleType, vehicleTypeLabel),
                        _buildInfoRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(widget.record.entryTime)),
                        _buildInfoRow(AppStrings.guard, widget.record.entryGuardName),
                        _buildInfoRow(AppStrings.shift, widget.record.entryShift),
                        if (widget.record.advanceAmount > 0) ...[
                          _buildInfoRow(
                            AppStrings.advancePaid,
                            '${AppFormatters.formatCurrency(widget.record.advanceAmount)} (${widget.record.advancePaymentMethod.toUpperCase() == 'CASH' ? AppStrings.cash : widget.record.advancePaymentMethod.toUpperCase()})',
                            color: AppColors.successDark,
                            isBold: true,
                          ),
                          _buildInfoRow(
                            AppStrings.advanceCollector,
                            widget.record.advanceCollectorGuardName ?? widget.record.entryGuardName,
                          ),
                          _buildInfoRow(
                            AppStrings.advanceShift,
                            widget.record.advanceCollectorShift ?? widget.record.entryShift,
                          ),
                        ] else ...[
                          _buildInfoRow(AppStrings.advancePaid, '₹0'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Calculation & Fee Breakdown Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.stayDurationAndCharges,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (widget.record.isMonthlyPass) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: AppColors.successDark, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${AppStrings.monthlyPass} ✓',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.successDark, fontSize: 13),
                                      ),
                                      Text(
                                        '${AppStrings.parkingFee}: ₹0',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.successDark, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppStrings.stayDuration, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.formatDuration(_calculation.duration),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(AppStrings.billableHours, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_calculation.billableHours} ${AppStrings.hoursSuffix}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(AppStrings.grossParkingCharge, AppFormatters.formatCurrency(_calculation.grossCharge)),
                        if (widget.record.advanceAmount > 0)
                          _buildInfoRow(
                            AppStrings.advanceAdjusted,
                            '- ${AppFormatters.formatCurrency(widget.record.advanceAmount)}',
                            color: AppColors.successDark,
                          ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Final Financial Outcome
                        if (hasBalance) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.balanceDue}:',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                AppFormatters.formatCurrency(_calculation.balanceDue),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ] else if (hasRefund) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.currency_exchange, color: AppColors.warningDark, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${AppStrings.refund}:',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warningDark, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppFormatters.formatCurrency(_calculation.refundAmount),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.warningDark),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.successDark, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.fullyCoveredSettled,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.successDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Mode & Collection Section
                if (hasBalance) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.selectSettlementMode,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaymentMethodTile(
                                  label: AppStrings.cash,
                                  value: 'cash',
                                  icon: Icons.money,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaymentMethodTile(
                                  label: AppStrings.upi,
                                  value: 'upi',
                                  icon: Icons.qr_code_2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Cash Tender Calculator
                          if (_paymentMethod == 'cash') ...[
                            TextField(
                              controller: _tenderController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '${AppStrings.cashReceived} (₹)',
                                prefixIcon: const Icon(Icons.payments_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${AppStrings.changeToReturn}:', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                Text(
                                  AppFormatters.formatCurrency(changeDue),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.successDark),
                                ),
                              ],
                            ),
                          ],

                          // UPI Confirmation Check
                          if (_paymentMethod == 'upi') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  '${AppStrings.confirmUpiReceived} (${AppFormatters.formatCurrency(_calculation.balanceDue)})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                value: _upiConfirmed,
                                onChanged: (val) {
                                  setState(() {
                                    _upiConfirmed = val ?? false;
                                    if (_upiConfirmed) _errorMessage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Refund Confirmation Section
                if (hasRefund) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${AppStrings.confirmRefundHanded} (${AppFormatters.formatCurrency(_calculation.refundAmount)})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        value: _refundConfirmed,
                        onChanged: (val) {
                          setState(() {
                            _refundConfirmed = val ?? false;
                            if (_refundConfirmed) _errorMessage = null;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Final Settlement Button
                AppButton(
                  label: isZeroSettlement
                      ? AppStrings.confirmExitReleaseSlot
                      : (hasRefund ? AppStrings.handoverRefundComplete : AppStrings.completeSettlementRelease),
                  icon: Icons.check_circle,
                  isLoading: _isSettling,
                  onPressed: _executeSettlement,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == value;

    return Card(
      elevation: 0,
      color: isSelected ? AppColors.primarySurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _paymentMethod = value;
            _errorMessage = null;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
