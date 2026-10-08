import 'dart:async';
import 'dart:io' show Platform;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../core/config/business_profile.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_language_controller.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_pass_model.dart';
import '../models/parking_record_model.dart';
import 'marathi_receipt_rasterizer.dart';

/// Connection state of the Bluetooth thermal printer.
enum BluetoothPrinterState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Mobile (Android) implementation for 58 mm Bluetooth thermal receipt printing.
/// Specifically tailored for MPT-II and POS58 Classic Bluetooth SPP/RFCOMM printers.
class ReceiptPlatformPrinter {
  static String? lastPrintedHtml;
  static bool shouldSucceed = true;
  static String? savedMacAddress;
  static String? savedPrinterName;
  static BluetoothPrinterState connectionState = BluetoothPrinterState.disconnected;
  static String? lastErrorMessage;

  /// Checks if device Bluetooth is switched on.
  static Future<bool> isBluetoothEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Checks if required Bluetooth runtime permissions are granted.
  static Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      debugPrint('[MPT-II Printer] Bluetooth runtime permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[MPT-II Printer] Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  /// Retrieves list of paired Bluetooth devices from the Android OS.
  static Future<List<BluetoothInfo>> getPairedPrinters() async {
    if (!Platform.isAndroid) return [];
    try {
      // First ensure runtime permissions on Android 12+
      final hasPerm = await isPermissionGranted();
      if (!hasPerm) {
        debugPrint('[MPT-II Printer] Requesting Bluetooth permissions before device retrieval...');
        lastErrorMessage = 'Bluetooth permission required. Please grant permission.';
      }

      final devices = await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('[MPT-II Printer] Paired devices retrieved: ${devices.length} device(s)');
      for (final d in devices) {
        debugPrint('[MPT-II Printer]   - Device: "${d.name}" | MAC: ${d.macAdress}');
      }

      // Auto-identify MPT-II or thermal printer if found and none explicitly saved
      if (savedMacAddress == null) {
        for (final d in devices) {
          final upper = d.name.toUpperCase();
          if (upper.contains('MPT') || upper.contains('POS58') || upper.contains('PRINTER')) {
            savedMacAddress = d.macAdress;
            savedPrinterName = d.name;
            debugPrint('[MPT-II Printer] Auto-identified default printer: "$savedPrinterName" ($savedMacAddress)');
            break;
          }
        }
      }
      return devices;
    } catch (e) {
      debugPrint('[MPT-II Printer] Error getting paired devices: $e');
      lastErrorMessage = 'Error listing devices: $e';
      return [];
    }
  }

  /// Checks if the SPP connection to the printer is currently active.
  static Future<bool> isConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      connectionState = status ? BluetoothPrinterState.connected : BluetoothPrinterState.disconnected;
      debugPrint('[MPT-II Printer] Socket connection status: ${status ? 'CONNECTED' : 'DISCONNECTED'}');
      return status;
    } catch (e) {
      debugPrint('[MPT-II Printer] Error checking connection status: $e');
      connectionState = BluetoothPrinterState.disconnected;
      return false;
    }
  }

  /// Connects to a paired printer by MAC address using Classic Bluetooth SPP.
  static Future<bool> connect(String macAddress, {String? printerName}) async {
    final displayName = printerName ?? savedPrinterName ?? 'MPT-II';
    debugPrint('[MPT-II Printer] ----------------------------------------');
    debugPrint('[MPT-II Printer] [CONNECT START] Target: "$displayName"');
    debugPrint('[MPT-II Printer] [CONNECT START] Address: $macAddress');
    debugPrint('[MPT-II Printer] ----------------------------------------');

    if (!Platform.isAndroid) {
      savedMacAddress = macAddress;
      savedPrinterName = displayName;
      connectionState = BluetoothPrinterState.connected;
      debugPrint('[MPT-II Printer] [CONNECT SUCCESS] Simulated connection (Desktop/Test host)');
      return true;
    }

    connectionState = BluetoothPrinterState.connecting;
    lastErrorMessage = null;

    try {
      // 1. Verify Bluetooth is enabled
      final isEnabled = await isBluetoothEnabled();
      if (!isEnabled) {
        connectionState = BluetoothPrinterState.error;
        lastErrorMessage = 'Bluetooth is turned off on the phone. Please enable Bluetooth.';
        debugPrint('[MPT-II Printer] [CONNECT FAILURE] Bluetooth adapter is disabled');
        return false;
      }

      // 2. Verify runtime permissions
      final hasPerm = await isPermissionGranted();
      if (!hasPerm) {
        connectionState = BluetoothPrinterState.error;
        lastErrorMessage = 'Bluetooth permission (Nearby devices) denied by user.';
        debugPrint('[MPT-II Printer] [CONNECT FAILURE] Bluetooth permission denied');
        return false;
      }

      // 3. Initiate Classic Bluetooth SPP RFCOMM connection via plugin
      debugPrint('[MPT-II Printer] Opening RFCOMM SPP socket to $macAddress...');
      final startTime = DateTime.now();
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (success) {
        savedMacAddress = macAddress;
        savedPrinterName = displayName;
        connectionState = BluetoothPrinterState.connected;
        debugPrint('[MPT-II Printer] [CONNECT SUCCESS] Connected to "$displayName" ($macAddress) in ${elapsed}ms');
        return true;
      } else {
        connectionState = BluetoothPrinterState.error;
        lastErrorMessage = 'Could not connect to $displayName ($macAddress). Ensure printer is ON, within range, and not connected to another phone.';
        debugPrint('[MPT-II Printer] [CONNECT FAILURE] Plugin returned false after ${elapsed}ms');
        return false;
      }
    } catch (e, stack) {
      connectionState = BluetoothPrinterState.error;
      lastErrorMessage = 'Connection exception: $e';
      debugPrint('[MPT-II Printer] [CONNECT EXCEPTION] Error connecting to $displayName ($macAddress): $e\n$stack');
      return false;
    }
  }

  /// Disconnects the active Bluetooth SPP socket.
  static Future<bool> disconnect({String reason = 'User requested disconnect'}) async {
    debugPrint('[MPT-II Printer] [DISCONNECT START] Reason: $reason');
    if (!Platform.isAndroid) {
      connectionState = BluetoothPrinterState.disconnected;
      debugPrint('[MPT-II Printer] [DISCONNECT SUCCESS] Simulated disconnect');
      return true;
    }

    try {
      final success = await PrintBluetoothThermal.disconnect;
      connectionState = BluetoothPrinterState.disconnected;
      debugPrint('[MPT-II Printer] [DISCONNECT SUCCESS] Socket closed cleanly (result=$success)');
      return success;
    } catch (e) {
      connectionState = BluetoothPrinterState.disconnected;
      debugPrint('[MPT-II Printer] [DISCONNECT ERROR] Error closing socket: $e');
      return false;
    }
  }

  /// Ensures an active SPP connection before printing.
  /// Reconnects to the saved printer or auto-connects to a paired MPT-II.
  static Future<bool> ensureConnected() async {
    debugPrint('[MPT-II Printer] Ensuring active connection before print...');
    if (await isConnected()) {
      debugPrint('[MPT-II Printer] Connection already active and verified.');
      return true;
    }

    if (savedMacAddress != null && savedMacAddress!.isNotEmpty) {
      debugPrint('[MPT-II Printer] Reconnecting to saved printer: $savedPrinterName ($savedMacAddress)');
      return await connect(savedMacAddress!, printerName: savedPrinterName);
    }

    // Try finding paired MPT-II automatically
    final paired = await getPairedPrinters();
    if (paired.isEmpty) {
      lastErrorMessage = 'No paired Bluetooth devices found. Please pair MPT-II in phone Settings.';
      debugPrint('[MPT-II Printer] [ENSURE FAILED] No paired devices found');
      return false;
    }

    BluetoothInfo? target = paired.firstWhere(
      (d) => d.name.toUpperCase().contains('MPT') || d.name.toUpperCase().contains('POS58'),
      orElse: () => paired.first,
    );

    debugPrint('[MPT-II Printer] Auto-selecting paired printer: "${target.name}" (${target.macAdress})');
    return await connect(target.macAdress, printerName: target.name);
  }

  /// Generates and prints the 58 mm thermal Entry Slip to MPT-II via Bluetooth.
  static Future<bool> printEntrySlip(ParkingRecord record, [String? htmlFallback]) async {
    lastPrintedHtml = htmlFallback;
    if (!Platform.isAndroid) {
      return shouldSucceed;
    }

    debugPrint('[MPT-II Printer] [PRINT ENTRY] Preparing entry slip for ticket ${record.ticketNumber}');
    final connected = await ensureConnected();
    if (!connected) {
      debugPrint('[MPT-II Printer] [PRINT ENTRY FAILED] Printer not connected: ${lastErrorMessage ?? 'Unknown'}');
      return false;
    }

    try {
      final bytes = await _buildEntrySlipEscPosBytes(record);
      debugPrint('[MPT-II Printer] [WRITE BYTES] Transmitting ${bytes.length} ESC/POS bytes to printer...');
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      if (sent) {
        debugPrint('[MPT-II Printer] [PRINT ENTRY SUCCESS] ${bytes.length} bytes transmitted successfully');
        return true;
      } else {
        lastErrorMessage = 'Failed to write bytes to thermal printer.';
        debugPrint('[MPT-II Printer] [PRINT ENTRY FAILED] writeBytes returned false');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[MPT-II Printer] [PRINT ENTRY EXCEPTION] Print error: $e\n$stack');
      lastErrorMessage = 'Print failed: $e';
      return false;
    }
  }

  /// Generates and prints the 58 mm thermal Final Exit Receipt to MPT-II via Bluetooth.
  static Future<bool> printExitReceipt(ParkingRecord record, [String? htmlFallback]) async {
    lastPrintedHtml = htmlFallback;
    if (!Platform.isAndroid) {
      return shouldSucceed;
    }

    debugPrint('[MPT-II Printer] [PRINT EXIT] Preparing exit receipt for ticket ${record.ticketNumber}');
    final connected = await ensureConnected();
    if (!connected) {
      debugPrint('[MPT-II Printer] [PRINT EXIT FAILED] Printer not connected: ${lastErrorMessage ?? 'Unknown'}');
      return false;
    }

    try {
      final bytes = await _buildExitReceiptEscPosBytes(record);
      debugPrint('[MPT-II Printer] [WRITE BYTES] Transmitting ${bytes.length} ESC/POS bytes to printer...');
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      if (sent) {
        debugPrint('[MPT-II Printer] [PRINT EXIT SUCCESS] ${bytes.length} bytes transmitted successfully');
        return true;
      } else {
        lastErrorMessage = 'Failed to write bytes to thermal printer.';
        debugPrint('[MPT-II Printer] [PRINT EXIT FAILED] writeBytes returned false');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[MPT-II Printer] [PRINT EXIT EXCEPTION] Print error: $e\n$stack');
      lastErrorMessage = 'Print failed: $e';
      return false;
    }
  }

  /// Generates and prints the 58 mm thermal Monthly Pass to MPT-II via Bluetooth.
  static Future<bool> printMonthlyPassReceipt(MonthlyPassModel pass, [String? htmlFallback]) async {
    lastPrintedHtml = htmlFallback;
    if (!Platform.isAndroid) {
      return shouldSucceed;
    }

    debugPrint('[MPT-II Printer] [PRINT PASS] Preparing monthly pass slip for ${pass.passNumber}');
    final connected = await ensureConnected();
    if (!connected) {
      debugPrint('[MPT-II Printer] [PRINT PASS FAILED] Printer not connected: ${lastErrorMessage ?? 'Unknown'}');
      return false;
    }

    try {
      final bytes = await _buildMonthlyPassEscPosBytes(pass);
      debugPrint('[MPT-II Printer] [WRITE BYTES] Transmitting ${bytes.length} ESC/POS bytes to printer...');
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      if (sent) {
        debugPrint('[MPT-II Printer] [PRINT PASS SUCCESS] ${bytes.length} bytes transmitted successfully');
        return true;
      } else {
        lastErrorMessage = 'Failed to write bytes to thermal printer.';
        debugPrint('[MPT-II Printer] [PRINT PASS FAILED] writeBytes returned false');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[MPT-II Printer] [PRINT PASS EXCEPTION] Print error: $e\n$stack');
      lastErrorMessage = 'Print failed: $e';
      return false;
    }
  }

  /// Prints a simple 58mm test receipt to confirm physical printing works.
  static Future<bool> printTestReceipt() async {
    if (!Platform.isAndroid) {
      return true;
    }

    debugPrint('[MPT-II Printer] [TEST PRINT] Preparing test receipt...');
    final connected = await ensureConnected();
    if (!connected) {
      debugPrint('[MPT-II Printer] [TEST PRINT FAILED] Not connected: ${lastErrorMessage ?? 'Unknown'}');
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];

      bytes.addAll(generator.text(
        'CAR PARKING SYSTEM',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
      ));
      bytes.addAll(generator.text(
        'MPT-II TEST PRINT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Printer: ${savedPrinterName ?? 'MPT-II'}'));
      bytes.addAll(generator.text('Date: ${AppFormatters.formatDate(DateTime.now())}'));
      bytes.addAll(generator.text('Time: ${AppFormatters.formatTime(DateTime.now())}'));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.qrcode('TEST-MPT-II-58MM', size: QRSize.size4, cor: QRCorrection.M, align: PosAlign.center));
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('58mm Thermal Print OK!', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());

      debugPrint('[MPT-II Printer] [TEST PRINT WRITE] Writing ${bytes.length} bytes to printer...');
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      debugPrint('[MPT-II Printer] [TEST PRINT RESULT] Sent = $sent');
      return sent;
    } catch (e, stack) {
      lastErrorMessage = 'Test print failed: $e';
      debugPrint('[MPT-II Printer] [TEST PRINT EXCEPTION] Error: $e\n$stack');
      return false;
    }
  }

  /// Builds ESC/POS commands for the 58 mm Entry Receipt.
  static Future<List<int>> _buildEntrySlipEscPosBytes(ParkingRecord record) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    final qrData = record.qrReference ?? record.ticketNumber;
    final bProfile = BusinessProfileController.instance.profile;
    final effectiveLang = AppLanguageController.instance.currentLanguage;

    if (effectiveLang == AppLanguage.marathi) {
      // 1. Header (Rasterized high-contrast Marathi Devanagari bitmap - 384px width, 44mm safe zone)
      final headerImg = await MarathiReceiptRasterizer.renderEntryHeader(profile: bProfile);
      bytes.addAll(generator.imageRaster(headerImg));
      bytes.addAll(generator.feed(1));

      // 2. Large 32mm (256px) QR Code Image (Prominent, centered, optimal quiet zone)
      final qrImg = MarathiReceiptRasterizer.renderQrImage(qrData, qrPixelSize: 256);
      bytes.addAll(generator.imageRaster(qrImg));
      bytes.addAll(generator.feed(1));

      // 3. Body Details & Notices (Razor-sharp Marathi Devanagari bitmap)
      final bodyImg = await MarathiReceiptRasterizer.renderEntryBody(record, profile: bProfile);
      bytes.addAll(generator.imageRaster(bodyImg));

      // 4. BizFlow Branding Footer (if enabled)
      if (bProfile.bizflowBrandingEnabled) {
        final footerImg = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.marathi);
        bytes.addAll(generator.imageRaster(footerImg));
      }

      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());
      return bytes;
    }

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final vehicleType = record.vehicleType.displayName;
    final entryDate = AppFormatters.formatDate(record.entryTime);
    final entryTime = AppFormatters.formatTime(record.entryTime);
    final entryGuard = record.entryGuardName;
    final entryShift = record.entryShift;
    final customerMobile = record.customerMobile.trim().isNotEmpty ? record.customerMobile.trim() : 'N/A';
    final advancePaid = 'Rs.${record.advanceAmount.toStringAsFixed(2)}';
    final advanceMethod = record.advanceAmount > 0 ? record.advancePaymentMethod.toUpperCase() : 'N/A';

    // Header (Safe 44mm printable area)
    bytes.addAll(generator.text(
      bProfile.englishName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      bProfile.englishLocation,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'Mo. ${bProfile.mobile}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'CAR PARKING SYSTEM',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'ENTRY RECEIPT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Large 32mm QR Code (256x256 dots centered)
    final qrImg = MarathiReceiptRasterizer.renderQrImage(qrData, qrPixelSize: 256);
    bytes.addAll(generator.imageRaster(qrImg));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(
      'TICKET: ${record.ticketNumber}',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Vehicle Details (Prominent Box)
    bytes.addAll(generator.text(
      'VEHICLE NUMBER',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      normalizedVehicleNumber,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      'Type: $vehicleType',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());

    // Details Rows (Safe 28-character width to avoid right HDFC strip)
    _addEscPosRow(bytes, generator, 'Entry Date:', entryDate);
    _addEscPosRow(bytes, generator, 'Entry Time:', entryTime);
    _addEscPosRow(bytes, generator, 'Entry Guard:', entryGuard);
    _addEscPosRow(bytes, generator, 'Entry Shift:', entryShift);
    _addEscPosRow(bytes, generator, 'Customer Mobile:', customerMobile);
    _addEscPosRow(bytes, generator, 'Advance Paid:', advancePaid);
    _addEscPosRow(bytes, generator, 'Payment:', advanceMethod);
    _addEscPosRow(bytes, generator, 'Status:', 'ACTIVE');
    _addEscPosRow(bytes, generator, 'Mandatory Photo:', 'CAPTURED');
    bytes.addAll(generator.hr());

    // Footer
    bytes.addAll(generator.text(
      'Please keep this slip safe.',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'Required at vehicle exit.',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // BizFlow Branding Footer (if enabled)
    if (bProfile.bizflowBrandingEnabled) {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Powered by', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('BIZFLOW', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text('Parking Management System', styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Builds ESC/POS commands for the 58 mm Exit Settlement Receipt.
  static Future<List<int>> _buildExitReceiptEscPosBytes(ParkingRecord record) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    final qrData = record.qrReference ?? record.ticketNumber;
    final bProfile = BusinessProfileController.instance.profile;
    final effectiveLang = AppLanguageController.instance.currentLanguage;

    if (effectiveLang == AppLanguage.marathi) {
      // 1. Header (Rasterized high-contrast Marathi Devanagari bitmap - 384px width, 44mm safe zone)
      final headerImg = await MarathiReceiptRasterizer.renderExitHeader(profile: bProfile);
      bytes.addAll(generator.imageRaster(headerImg));
      bytes.addAll(generator.feed(1));

      // 2. Large 32mm (256px) QR Code Image (Prominent, centered)
      final qrImg = MarathiReceiptRasterizer.renderQrImage(qrData, qrPixelSize: 256);
      bytes.addAll(generator.imageRaster(qrImg));
      bytes.addAll(generator.feed(1));

      // 3. Body Details & Financial Audit (Razor-sharp Marathi Devanagari bitmap)
      final bodyImg = await MarathiReceiptRasterizer.renderExitBody(record, profile: bProfile);
      bytes.addAll(generator.imageRaster(bodyImg));

      // 4. BizFlow Branding Footer (if enabled)
      if (bProfile.bizflowBrandingEnabled) {
        final footerImg = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.marathi);
        bytes.addAll(generator.imageRaster(footerImg));
      }

      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());
      return bytes;
    }

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final vehicleType = record.vehicleType.displayName;
    final exitTime = record.exitTime ?? DateTime.now();

    final entryStr = '${AppFormatters.formatDate(record.entryTime)} ${AppFormatters.formatTime(record.entryTime)}';
    final exitStr = '${AppFormatters.formatDate(exitTime)} ${AppFormatters.formatTime(exitTime)}';

    final totalMinutes = exitTime.difference(record.entryTime).inMinutes;
    final durationHours = totalMinutes ~/ 60;
    final durationMins = totalMinutes % 60;
    final durationStr = '${durationHours}h ${durationMins}m';

    final totalCharge = record.grossCharge ?? 0.0;
    final advancePaid = record.advanceAmount;
    final advanceAdjusted = (advancePaid > totalCharge ? totalCharge : advancePaid);
    final balanceCollected = record.balanceDue ?? 0.0;
    final refundHanded = record.refundAmount ?? 0.0;
    final paymentMethod = (record.paymentMethod ?? 'CASH').toUpperCase();
    final refundMethod = (record.paymentMethod ?? 'CASH').toUpperCase();

    // Header
    bytes.addAll(generator.text(
      bProfile.englishName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      bProfile.englishLocation,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'Mo. ${bProfile.mobile}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'CAR PARKING SYSTEM',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'EXIT SETTLEMENT RECEIPT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Large 32mm QR Code (256x256 dots centered)
    final qrImg = MarathiReceiptRasterizer.renderQrImage(qrData, qrPixelSize: 256);
    bytes.addAll(generator.imageRaster(qrImg));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(
      'TICKET: ${record.ticketNumber}',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Vehicle details (Prominent)
    bytes.addAll(generator.text(
      'VEHICLE NUMBER',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      normalizedVehicleNumber,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      'Type: $vehicleType',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());

    // Timing & Duration (Safe 28-char row budget)
    _addEscPosRow(bytes, generator, 'Entry Time:', entryStr);
    _addEscPosRow(bytes, generator, 'Exit Time:', exitStr);
    _addEscPosRow(bytes, generator, 'Duration:', durationStr);
    bytes.addAll(generator.hr());

    // Financial breakdown & Prominent Total Amount
    bytes.addAll(generator.text(
      'TOTAL AMOUNT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'Rs.${totalCharge.toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.hr());

    if (advancePaid > 0) {
      _addEscPosRow(bytes, generator, 'Advance Paid:', 'Rs.${advancePaid.toStringAsFixed(2)}');
      _addEscPosRow(bytes, generator, 'Advance Adjusted:', 'Rs.${advanceAdjusted.toStringAsFixed(2)}');
    }

    if (refundHanded > 0) {
      bytes.addAll(generator.text(
        'REFUND: Rs.${refundHanded.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ));
      _addEscPosRow(bytes, generator, 'REFUND METHOD:', refundMethod);
    } else if (balanceCollected > 0) {
      bytes.addAll(generator.text(
        'BALANCE: Rs.${balanceCollected.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ));
      _addEscPosRow(bytes, generator, 'PAYMENT METHOD:', paymentMethod);
    } else {
      bytes.addAll(generator.text(
        'FINAL AMOUNT: Rs.0.00',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ));
      _addEscPosRow(bytes, generator, 'PAYMENT METHOD:', paymentMethod);
    }

    bytes.addAll(generator.hr());

    // Audit Trail
    _addEscPosRow(bytes, generator, 'Entry Guard:', record.entryGuardName);
    if (record.advanceCollectorGuardName != null) {
      _addEscPosRow(bytes, generator, 'Advance Guard:', record.advanceCollectorGuardName!);
    }
    _addEscPosRow(bytes, generator, 'Exit Guard:', record.exitGuardName ?? 'Guard');
    _addEscPosRow(bytes, generator, 'Exit Shift:', record.exitShift ?? record.entryShift);
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Status: SETTLED & EXITED',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Footer
    bytes.addAll(generator.text(
      'Thank you for parking with us!',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'Have a safe journey.',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // BizFlow Branding Footer (if enabled)
    if (bProfile.bizflowBrandingEnabled) {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Powered by', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('BIZFLOW', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text('Parking Management System', styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Builds ESC/POS commands for the 58 mm Monthly Pass Receipt.
  static Future<List<int>> _buildMonthlyPassEscPosBytes(MonthlyPassModel pass) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    final bProfile = BusinessProfileController.instance.profile;
    final effectiveLang = AppLanguageController.instance.currentLanguage;

    if (effectiveLang == AppLanguage.marathi) {
      final passImg = await MarathiReceiptRasterizer.renderMonthlyPassSlip(pass, profile: bProfile);
      bytes.addAll(generator.imageRaster(passImg));
      if (bProfile.bizflowBrandingEnabled) {
        final footerImg = await MarathiReceiptRasterizer.renderBizFlowFooter(language: AppLanguage.marathi);
        bytes.addAll(generator.imageRaster(footerImg));
      }
      bytes.addAll(generator.feed(3));
      bytes.addAll(generator.cut());
      return bytes;
    }

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(pass.vehicleNumber);
    final vehicleType = pass.vehicleType.displayName;
    final startDateStr = AppFormatters.formatDate(pass.startDate);
    final endDateStr = AppFormatters.formatDate(pass.endDate);

    // Header
    bytes.addAll(generator.text(
      bProfile.englishName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      bProfile.englishLocation,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'Mo. ${bProfile.mobile}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'CAR PARKING SYSTEM',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'MONTHLY PASS',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(
      'PASS NO: ${pass.passNumber}',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Vehicle Details (Prominent Box)
    bytes.addAll(generator.text(
      'VEHICLE NUMBER',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      normalizedVehicleNumber,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      'Type: $vehicleType',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());

    // Details Rows
    _addEscPosRow(bytes, generator, 'Customer:', pass.customerName);
    _addEscPosRow(bytes, generator, 'Mobile:', pass.customerMobile);
    _addEscPosRow(bytes, generator, 'Validity:', '$startDateStr - $endDateStr');
    bytes.addAll(generator.hr());

    // Amount & Payment Status
    bytes.addAll(generator.text(
      'PASS AMOUNT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      'Rs.${pass.amount.toInt()}',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    _addEscPosRow(bytes, generator, 'Payment:', 'PAID (${pass.paymentMethod.toUpperCase()})');
    _addEscPosRow(bytes, generator, 'Fee in Validity:', 'Rs.0');
    bytes.addAll(generator.hr());

    // Footer
    bytes.addAll(generator.text(
      'Thank You!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    // BizFlow Branding Footer (if enabled)
    if (bProfile.bizflowBrandingEnabled) {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Powered by', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('BIZFLOW', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text('CAR PARKING SYSTEM', styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Appends a neatly formatted two-column key-value row fitting 26 columns (39mm safe zone).
  static void _addEscPosRow(List<int> bytes, Generator generator, String label, String value) {
    const int maxChars = 26;
    final int labelLen = label.length;
    final int valueLen = value.length;

    if (labelLen + valueLen + 1 <= maxChars) {
      final spaces = maxChars - (labelLen + valueLen);
      bytes.addAll(generator.text('$label${' ' * spaces}$value'));
    } else {
      bytes.addAll(generator.text(label));
      bytes.addAll(generator.text('  $value', styles: const PosStyles(align: PosAlign.right)));
    }
  }

  /// Stub fallback for raw HTML if ever called directly on mobile.
  static Future<bool> printHtml(String htmlContent) async {
    lastPrintedHtml = htmlContent;
    return shouldSucceed;
  }
}
