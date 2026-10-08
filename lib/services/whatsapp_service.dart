import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_language_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_pass_model.dart';
import '../models/parking_record_model.dart';
import '../models/vehicle_type.dart';

/// Single source of truth for parking entry WhatsApp text messaging.
/// Opens direct wa.me chat with normalized customer mobile and pre-filled text message.
class WhatsAppService {
  /// Validates customer mobile according to Indian mobile number specifications:
  /// Exactly 10 digits starting with 6, 7, 8, or 9.
  static bool isValidCustomerMobile(String? mobile) {
    if (mobile == null) return false;
    final trimmed = mobile.trim();
    return RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed);
  }

  /// Builds the customer-friendly entry confirmation message using exact slip details.
  static String buildEntryMessage(ParkingRecord record, {AppLanguage? language}) =>
      buildEntryConfirmationMessage(record, language: language);

  static String buildEntryConfirmationMessage(ParkingRecord record, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;
    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final vehicleTypeLabel = isMarathi
        ? (record.vehicleType == VehicleType.twoWheeler ? 'दुचाकी' : 'चारचाकी')
        : record.vehicleType.displayName;
    final entryTimeStr = AppFormatters.formatDateTime(record.entryTime);
    final qrRef = record.qrReference ?? record.ticketNumber;

    if (isMarathi) {
      final advanceLine = record.advanceAmount > 0
          ? '\nआगाऊ रक्कम: ${AppFormatters.formatCurrency(record.advanceAmount)} (${record.advancePaymentMethod.toUpperCase() == 'CASH' ? 'रोख' : record.advancePaymentMethod.toUpperCase()})'
          : '';
      return '''वाहन पार्किंग प्रवेश पावती

तिकीट क्र.: ${record.ticketNumber}
वाहन क्र.: $normalizedVehicleNumber
वाहन प्रकार: $vehicleTypeLabel
प्रवेश वेळ: $entryTimeStr$advanceLine

कृपया ही माहिती आपल्या नोंदीसाठी जपून ठेवा.

QR / प्रवेश पावती:
$qrRef''';
    }

    final advanceLine = record.advanceAmount > 0
        ? '\nAdvance Paid: ${AppFormatters.formatCurrency(record.advanceAmount)} (${record.advancePaymentMethod.toUpperCase()})'
        : '';

    return '''Car Parking Entry Confirmation

Ticket No: ${record.ticketNumber}
Vehicle No: $normalizedVehicleNumber
Vehicle Type: $vehicleTypeLabel
Entry Time: $entryTimeStr$advanceLine

Please keep this message for your parking record.

QR / Entry Slip:
$qrRef''';
  }

  /// Builds the wa.me click-to-chat URL with country code 91, customer mobile, and encoded message.
  static String buildClickToChatUrl(ParkingRecord record, {AppLanguage? language}) {
    final message = buildEntryConfirmationMessage(record, language: language);
    final encodedMsg = Uri.encodeComponent(message);
    final mobile = record.customerMobile.trim();

    if (isValidCustomerMobile(mobile)) {
      return 'https://wa.me/91$mobile?text=$encodedMsg';
    }
    return 'https://wa.me/?text=$encodedMsg';
  }

  /// Opens the WhatsApp direct click-to-chat URL in an external application / browser.
  /// Used uniformly on Android and Web for text-only messaging.
  /// Validates customer mobile before attempting launch.
  /// WhatsApp failure never affects or rolls back the parking record.
  static Future<bool> openWhatsApp(BuildContext context, ParkingRecord record) async {
    final mobile = record.customerMobile.trim();
    if (!isValidCustomerMobile(mobile)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer mobile number is invalid.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }

    final url = buildClickToChatUrl(record);
    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Defensive direct launch attempt in case of atypical OS package visibility filtering
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return true;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Parking entry is already confirmed.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Parking entry is already confirmed.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return false;
    }
  }

  /// Builds the customer-friendly exit confirmation message using exact slip details.
  static String buildExitMessage(ParkingRecord record, {AppLanguage? language}) =>
      buildExitConfirmationMessage(record, language: language);

  static String buildExitConfirmationMessage(ParkingRecord record, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;
    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final entryTimeStr = AppFormatters.formatTime(record.entryTime);
    final exitTimeStr = record.exitTime != null ? AppFormatters.formatTime(record.exitTime!) : 'N/A';
    final duration = record.exitTime != null
        ? record.exitTime!.difference(record.entryTime)
        : Duration.zero;
    final durationStr = AppFormatters.formatDuration(duration);
    final grossChargeStr = AppFormatters.formatCurrency(record.grossCharge ?? 0.0);
    final advanceStr = AppFormatters.formatCurrency(record.advanceAmount);
    final balanceDue = record.balanceDue ?? 0.0;
    final refundAmount = record.refundAmount ?? 0.0;
    final paymentMethodRaw = (record.paymentMethod ?? 'CASH').toUpperCase();
    final paymentMethodStr = isMarathi
        ? (paymentMethodRaw == 'CASH' ? 'रोख' : paymentMethodRaw)
        : paymentMethodRaw;

    if (isMarathi) {
      final settlementLine = refundAmount > 0
          ? 'परतावा रक्कम: ${AppFormatters.formatCurrency(refundAmount)}'
          : 'अंतिम भरणा: ${AppFormatters.formatCurrency(balanceDue)}';

      return '''CAR PARKING SYSTEM - BIZFLOW

वाहन: $normalizedVehicleNumber
तिकीट: ${record.ticketNumber}

प्रवेश: $entryTimeStr
बाहेर: $exitTimeStr
कालावधी: $durationStr

पार्किंग शुल्क: $grossChargeStr
आगाऊ रक्कम: $advanceStr
$settlementLine

पेमेंट: $paymentMethodStr

CAR PARKING SYSTEM वापरल्याबद्दल धन्यवाद!''';
    }

    final settlementLine = refundAmount > 0
        ? 'Refund: ${AppFormatters.formatCurrency(refundAmount)}'
        : 'Final Paid: ${AppFormatters.formatCurrency(balanceDue)}';

    return '''CAR PARKING SYSTEM - BIZFLOW

Vehicle: $normalizedVehicleNumber
Ticket: ${record.ticketNumber}

Entry: $entryTimeStr
Exit: $exitTimeStr
Duration: $durationStr

Parking Fee: $grossChargeStr
Advance: $advanceStr
$settlementLine

Payment: $paymentMethodRaw

Thank you for using CAR PARKING SYSTEM.''';
  }

  /// Builds the wa.me click-to-chat URL with country code 91, customer mobile, and encoded exit message.
  static String buildExitClickToChatUrl(ParkingRecord record, {AppLanguage? language}) {
    final message = buildExitConfirmationMessage(record, language: language);
    final encodedMsg = Uri.encodeComponent(message);
    final mobile = record.customerMobile.trim();

    if (isValidCustomerMobile(mobile)) {
      return 'https://wa.me/91$mobile?text=$encodedMsg';
    }
    return 'https://wa.me/?text=$encodedMsg';
  }

  /// Opens the exit WhatsApp direct click-to-chat URL in an external application / browser.
  static Future<bool> openExitWhatsApp(BuildContext context, ParkingRecord record) async {
    final mobile = record.customerMobile.trim();
    if (!isValidCustomerMobile(mobile)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer mobile number is invalid or not provided.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }

    final url = buildExitClickToChatUrl(record);
    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return true;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return false;
    }
  }

  /// Builds a text-only WhatsApp message for a Monthly Pass.
  static String buildMonthlyPassMessage(MonthlyPassModel pass, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;
    final normalized = AppFormatters.normalizeVehicleNumber(pass.vehicleNumber);
    final vehicleTypeLabel = isMarathi
        ? (pass.vehicleType == VehicleType.twoWheeler ? 'दुचाकी' : 'चारचाकी')
        : pass.vehicleType.displayName;
    final paymentMethodStr = pass.paymentMethod.toUpperCase() == 'UPI'
        ? 'UPI'
        : (isMarathi ? 'रोख' : 'CASH');
    final paymentStatusStr = pass.paymentStatus.toUpperCase() == 'PAID'
        ? (isMarathi ? 'भरलेले' : 'PAID')
        : pass.paymentStatus;

    if (isMarathi) {
      return '''JAY GANESH PAY & PARK
मासिक पास

पास क्र.: ${pass.passNumber}
वाहन क्र.: $normalized
वाहन प्रकार: $vehicleTypeLabel
ग्राहक: ${pass.customerName}
वैधता: ${AppFormatters.formatDate(pass.startDate, isMarathi: true)} → ${AppFormatters.formatDate(pass.endDate, isMarathi: true)}
पास रक्कम: ₹${pass.amount.toInt()}
पेमेंट: $paymentStatusStr ($paymentMethodStr)
वैधता कालावधीत पार्किंग शुल्क: ₹०

धन्यवाद!

----------------------------
BIZFLOW द्वारे समर्थित
CAR PARKING SYSTEM''';
    }

    return '''JAY GANESH PAY & PARK
Monthly Pass

Pass No: ${pass.passNumber}
Vehicle No: $normalized
Vehicle Type: $vehicleTypeLabel
Customer: ${pass.customerName}
Validity: ${AppFormatters.formatDate(pass.startDate)} → ${AppFormatters.formatDate(pass.endDate)}
Pass Amount: ₹${pass.amount.toInt()}
Payment: $paymentStatusStr ($paymentMethodStr)
Parking Fee During Validity: ₹0

Thank You!

----------------------------
Powered by BIZFLOW
CAR PARKING SYSTEM''';
  }

  /// Opens direct WhatsApp click-to-chat with text-only pass confirmation.
  static Future<bool> shareMonthlyPassConfirmation(MonthlyPassModel pass, {AppLanguage? language}) async {
    final mobile = pass.customerMobile.trim();
    final message = buildMonthlyPassMessage(pass, language: language);
    final encoded = Uri.encodeComponent(message);
    String url;
    if (isValidCustomerMobile(mobile)) {
      url = 'https://wa.me/91$mobile?text=$encoded';
    } else {
      url = 'https://wa.me/?text=$encoded';
    }
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
