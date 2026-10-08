import 'dart:math';
import 'package:flutter/services.dart';

/// Utility functions for displaying currency, dates, times, ticket IDs, and vehicle registrations.
class AppFormatters {
  AppFormatters._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Normalizes an Indian vehicle registration number:
  /// - Removes all whitespace (spaces, tabs, newlines)
  /// - Removes all hyphens
  /// - Converts all alphabetic characters to uppercase
  /// E.g.: "mh 12 ab 1234" -> "MH12AB1234"
  ///       "MH-12-AB-1234" -> "MH12AB1234"
  static String normalizeVehicleNumber(String? vehicleNumber) {
    if (vehicleNumber == null) return '';
    return vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }

  /// Detects whether a search query is a numeric-only ticket query (1 or more digits).
  static bool isNumericTicketQuery(String? query) {
    if (query == null) return false;
    final clean = query.trim();
    return clean.isNotEmpty && RegExp(r'^\d+$').hasMatch(clean);
  }

  /// Detects whether a search query looks like a legacy parking ticket number
  /// (e.g. starts with "TKT-" case-insensitively or matches TKT-YYYYMMDD-XXXX pattern).
  static bool isLegacyTicketQuery(String? query) {
    if (query == null) return false;
    final clean = query.trim().toUpperCase();
    return clean.startsWith('TKT-') || RegExp(r'^TKT-?\d{8}-?[A-Z0-9]+$').hasMatch(clean);
  }

  /// Detects whether a search query looks like a parking ticket number
  /// (either numeric-only ticket or legacy TKT- ticket).
  static bool isTicketQuery(String? query) {
    return isNumericTicketQuery(query) || isLegacyTicketQuery(query);
  }

  /// Normalizes a search query for Active Parking search based on query type:
  /// - Numeric-only query -> numeric ticket search (trimmed directly, preserving digits/leading zeros like '04').
  /// - Legacy ticket query (TKT-YYYYMMDD-XXXX) -> normalize ONLY by trim + uppercase (preserving hyphens).
  /// - Otherwise -> vehicle-number search using vehicle-number normalization.
  /// Do NOT pass numeric ticket queries through vehicle-number normalization.
  static String normalizeActiveSearchQuery(String? query) {
    if (query == null) return '';
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';

    if (isNumericTicketQuery(trimmed)) {
      return trimmed;
    }
    if (isLegacyTicketQuery(trimmed)) {
      return trimmed.toUpperCase();
    }
    return normalizeVehicleNumber(trimmed);
  }

  /// Validates an Indian vehicle registration number.
  /// Accepts standard state-code registrations (e.g. MH12AB1234, MH12A1234, MH12AB123, MH12AB12345)
  /// and Bharat (BH) series registrations (e.g. 22BH1234AA).
  /// Rejects empty values and obviously invalid patterns like ABC, 123456, @@@###, MH, 12AB, RANDOM123.
  static bool isValidVehicleNumber(String? value) {
    if (value == null) return false;
    final normalized = normalizeVehicleNumber(value);
    if (normalized.length < 5 || normalized.length > 13) return false;

    // Standard Indian format:
    // State/UT code (2 letters) + RTO code (1-2 digits) + Series (0-3 letters) + Number (1-5 digits) + Optional sub-series (1 letter)
    final standardPattern = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{1,5}[A-Z]?$');

    // Bharat (BH) series format:
    // Year (2 digits) + BH + 4 digits + 1-2 letters (e.g. 22BH1234AA)
    final bhPattern = RegExp(r'^\d{2}BH\d{4}[A-Z]{1,2}$');

    return standardPattern.hasMatch(normalized) || bhPattern.hasMatch(normalized);
  }

  /// Validates a customer's local Indian mobile number:
  /// - Exactly 10 numeric digits
  /// - First digit must be 6, 7, 8, or 9
  /// - Rejects country codes (+91, 91), spaces, letters, and special characters
  static bool isValidCustomerMobile(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.length != 10) return false;
    final pattern = RegExp(r'^[6-9]\d{9}$');
    return pattern.hasMatch(trimmed);
  }

  /// Formats currency with Indian Rupee symbol: e.g., ₹180
  static String formatCurrency(double amount) {
    if (amount % 1 == 0) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Formats date and time: e.g., 21 Sep 2026, 04:30 PM
  static String formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    final year = dt.year;
    final timeStr = formatTime(dt);
    return '$day $month $year, $timeStr';
  }

  /// Formats time in 12-hour AM/PM: e.g., 04:30 PM
  static String formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hourStr:$minuteStr $period';
  }

  static const List<String> _marathiMonths = [
    'जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून',
    'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर'
  ];

  /// Formats date only: e.g., 21 Sep 2026 (or 21 सप्टेंबर 2026 in Marathi)
  static String formatDate(DateTime dt, {bool isMarathi = false}) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = isMarathi ? _marathiMonths[dt.month - 1] : _months[dt.month - 1];
    final year = dt.year;
    return '$day $month $year';
  }

  /// Formats duration into human readable text: e.g., 2h 15m, 5 min, 0 min
  static String formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '0 min';
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 1) {
      return '1 min';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    if (minutes == 0) {
      return '$hours hr${hours == 1 ? '' : 's'}';
    }
    return '$hours hr${hours == 1 ? '' : 's'} $minutes min';
  }

  /// Generates a unique, formatted Ticket Number: e.g., TKT-20260921-A8F2
  static String generateTicketNumber() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random();
    final rand = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'TKT-$year$month$day-$rand';
  }

  /// Generates a unique Monthly Pass Number: e.g., PASS-202609-5481
  static String generatePassNumber() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final rand = (1000 + Random().nextInt(9000)).toString();
    return 'PASS-$year$month-$rand';
  }
}

/// A [TextInputFormatter] that automatically converts all alphabetic characters
/// to UPPERCASE in real time, while preserving cursor position and supporting
/// normal typing, backspace, deletion, selection, and pasting.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
