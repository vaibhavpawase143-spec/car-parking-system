import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/guard_model.dart';
import '../../models/handover_model.dart';
import '../../services/financial_responsibility_service.dart';

/// Mandatory, non-dismissible modal popup shown to a receiving Guard
/// when there is a PENDING financial handover assigned to them.
///
/// Features:
/// - Blocking UI (PopScope canPop: false, barrierDismissible: false)
/// - Only ONE action button: [ ACCEPT ]
/// - Prevents double-accept / race conditions with isAccepting state
/// - Validates stale balance before transfer
/// - Fully localized in English and Marathi
class MandatoryHandoverPopup extends StatefulWidget {
  final HandoverModel handover;
  final GuardModel currentGuard;
  final FinancialResponsibilityService? financialService;
  final VoidCallback? onAccepted;

  const MandatoryHandoverPopup({
    super.key,
    required this.handover,
    required this.currentGuard,
    this.financialService,
    this.onAccepted,
  });

  @override
  State<MandatoryHandoverPopup> createState() => _MandatoryHandoverPopupState();
}

class _MandatoryHandoverPopupState extends State<MandatoryHandoverPopup> {
  bool _isAccepting = false;
  String? _errorMessage;

  FinancialResponsibilityService get _service =>
      widget.financialService ?? FinancialResponsibilityService.instance;

  Future<void> _handleAccept() async {
    if (_isAccepting) return;

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      await _service.respondToHandover(
        handoverId: widget.handover.handoverId,
        accept: true,
        guardUid: widget.currentGuard.uid,
        guardName: widget.currentGuard.name,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.handoverAcceptedSuccess),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onAccepted?.call();
      }
    } catch (e) {
      debugPrint('[MandatoryHandoverPopup] Error accepting handover: $e');

      // CRITICAL: After timeout or error, re-check the authoritative Handover document state
      // before deciding whether the operation actually failed.
      bool isActuallyAccepted = false;
      try {
        final authoritative = await _service.getHandover(widget.handover.handoverId);
        if (authoritative != null && authoritative.status == 'ACCEPTED') {
          isActuallyAccepted = true;
        }
      } catch (checkErr) {
        debugPrint('[MandatoryHandoverPopup] Error during fallback state check: $checkErr');
      }

      if (mounted) {
        if (isActuallyAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.handoverAcceptedSuccess),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onAccepted?.call();
        } else {
          setState(() {
            _isAccepting = false;
            final errStr = e.toString().replaceFirst('Exception: ', '').trim();
            _errorMessage = errStr.isNotEmpty ? errStr : AppStrings.unableToAcceptHandover;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.handover;
    final isCash = h.isCash;
    final methodLabel = isCash ? AppStrings.cashLabel : AppStrings.upiLabel;

    return PopScope(
      canPop: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      AppStrings.handoverReceived,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            label: AppStrings.from,
                            value: h.fromGuardName,
                            icon: Icons.person_outline,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: AppStrings.method,
                            value: methodLabel,
                            icon: isCash ? Icons.money : Icons.qr_code,
                            valueColor: isCash ? AppColors.successDark : AppColors.accent,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: AppStrings.amount,
                            value: AppFormatters.formatCurrency(h.amount),
                            icon: Icons.currency_rupee,
                            isBold: true,
                            valueColor: AppColors.primary,
                            fontSize: 18,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: AppStrings.status,
                            value: AppStrings.pending,
                            icon: Icons.hourglass_top,
                            valueColor: AppColors.warningDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Prompt Message
                    Text(
                      AppStrings.pleaseAcceptHandoverToContinue,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dangerDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ONLY ONE ACTION BUTTON: [ ACCEPT ]
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        key: const ValueKey('mandatory_accept_handover_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isAccepting ? null : _handleAccept,
                        child: _isAccepting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppStrings.accept,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
    Color? valueColor,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
