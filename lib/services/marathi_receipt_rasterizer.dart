import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/config/business_profile.dart';
import '../core/localization/app_language.dart';
import '../core/utils/formatters.dart';
import '../models/parking_record_model.dart';

/// High-contrast, razor-sharp monochrome rasterizer for 58mm thermal printers (Caysn P58H50 / PSF58H).
///
/// Specifically optimized for Marathi Devanagari text on thermal printheads:
/// - 2x super-sampled canvas rendering with high-contrast thresholding eliminates blur & broken matras.
/// - Strict 39mm safe printable zone (312px width on a 384px printhead) with 64px reserved right margin
///   to prevent collision with pre-printed HDFC BANK vertical strip.
/// - Generates prominent 224x224 dot (28mm) QR code image centered inside safe print zone with optimal quiet zone.
/// - Exact font size configuration for crystal-clear Devanagari readability (+1.5 to +2pt increase):
///   - Normal Marathi body / key-value rows: 17.5 px logical (35 px on 2x raster), FontWeight.w700
///   - Section headings: 22 px logical (44 px on 2x raster), FontWeight.w900
///   - Vehicle number: 26 px logical (52 px on 2x raster), FontWeight.w900
///   - Total parking amount: 26 px logical (52 px on 2x raster), FontWeight.w900
///   - Footer text: 15.5 px logical (31 px on 2x raster), FontWeight.w700
class MarathiReceiptRasterizer {
  /// 58mm printer physical printhead width = 384 dots (8 dots/mm @ 203 DPI).
  static const double printableWidth = 384.0;

  /// Safe printable content width = 312 dots (~39mm).
  /// Leaving right 64 dots (8mm) empty ensures zero overlap with the pre-printed HDFC BANK vertical strip.
  static const double safeContentWidth = 312.0;

  /// Left margin for safe left alignment.
  static const double safeLeftMargin = 8.0;

  /// Converts a CustomPainter to a razor-sharp monochrome [img.Image] using 2x super-sampling.
  static Future<img.Image> painterToImage(CustomPainter painter, Size size, {double superSampleScale = 2.0}) async {
    final renderWidth = (size.width * superSampleScale).toInt();
    final renderHeight = (size.height * superSampleScale).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, renderWidth.toDouble(), renderHeight.toDouble()));

    // Fill solid white background
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, renderWidth.toDouble(), renderHeight.toDouble()), bgPaint);

    // Scale canvas for 2x super-sampling
    canvas.scale(superSampleScale, superSampleScale);

    // Paint content inside the safe printable zone
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(renderWidth, renderHeight);
    final ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw Exception('Failed to obtain raw byte data from rendered canvas.');
    }

    // Convert raw super-sampled RGBA to target 384 x (H) monochrome image with high-contrast thresholding
    final targetWidth = size.width.toInt();
    final targetHeight = size.height.toInt();
    final outImage = img.Image(width: targetWidth, height: targetHeight, numChannels: 4);

    final srcBytes = byteData.buffer.asUint8List();
    final scaleInt = superSampleScale.round();

    for (int ty = 0; ty < targetHeight; ty++) {
      for (int tx = 0; tx < targetWidth; tx++) {
        // Average luminance across super-sampled sub-pixel block
        int totalLum = 0;
        int count = 0;
        for (int dy = 0; dy < scaleInt; dy++) {
          final sy = ty * scaleInt + dy;
          if (sy >= renderHeight) continue;
          for (int dx = 0; dx < scaleInt; dx++) {
            final sx = tx * scaleInt + dx;
            if (sx >= renderWidth) continue;
            final offset = (sy * renderWidth + sx) * 4;
            final r = srcBytes[offset];
            final g = srcBytes[offset + 1];
            final b = srcBytes[offset + 2];
            final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
            totalLum += lum;
            count++;
          }
        }
        final avgLum = count > 0 ? (totalLum ~/ count) : 255;
        // Thermal printhead threshold: If avg luminance < 215, mark solid black
        if (avgLum < 215) {
          outImage.setPixelRgba(tx, ty, 0, 0, 0, 255);
        } else {
          outImage.setPixelRgba(tx, ty, 255, 255, 255, 255);
        }
      }
    }

    return outImage;
  }

  /// Generates a crisp, prominent 224x224 monochrome QR code bitmap centered inside the safe print area on the 384px thermal width.
  /// 224 dots @ 8 dots/mm = 28mm physical QR code.
  static img.Image renderQrImage(String data, {int qrPixelSize = 224, int totalWidth = 384}) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;

    final outImage = img.Image(width: totalWidth, height: qrPixelSize + 16, numChannels: 4);
    // Fill white
    for (int y = 0; y < outImage.height; y++) {
      for (int x = 0; x < outImage.width; x++) {
        outImage.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }

    final moduleSize = qrPixelSize ~/ moduleCount;
    final actualQrSize = moduleCount * moduleSize;
    // Center inside safe width (startX within safe zone [safeLeftMargin, safeLeftMargin + safeContentWidth])
    final startX = (safeContentWidth - actualQrSize) ~/ 2 + safeLeftMargin.toInt();
    const startY = 8;

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (qrImage.isDark(r, c)) {
          for (int my = 0; my < moduleSize; my++) {
            for (int mx = 0; mx < moduleSize; mx++) {
              final px = startX + (c * moduleSize) + mx;
              final py = startY + (r * moduleSize) + my;
              if (px >= 0 && px < totalWidth && py >= 0 && py < outImage.height) {
                outImage.setPixelRgba(px, py, 0, 0, 0, 255);
              }
            }
          }
        }
      }
    }
    return outImage;
  }

  /// Renders the Marathi Entry Receipt Header.
  static Future<img.Image> renderEntryHeader({BusinessProfile? profile}) async {
    final p = profile ?? BusinessProfileController.instance.profile;
    final painter = _MarathiEntryHeaderPainter(profile: p);
    final height = painter.measureHeight(safeContentWidth);
    return await painterToImage(painter, Size(printableWidth, height));
  }

  /// Renders the Marathi Entry Receipt Body (Ticket, Vehicle Box, Timings, Guard details, notices).
  static Future<img.Image> renderEntryBody(ParkingRecord record, {BusinessProfile? profile}) async {
    final p = profile ?? BusinessProfileController.instance.profile;
    final painter = _MarathiEntryBodyPainter(record: record, profile: p);
    final height = painter.measureHeight(safeContentWidth);
    return await painterToImage(painter, Size(printableWidth, height));
  }

  /// Renders the Marathi Exit Receipt Header.
  static Future<img.Image> renderExitHeader({BusinessProfile? profile}) async {
    final p = profile ?? BusinessProfileController.instance.profile;
    final painter = _MarathiExitHeaderPainter(profile: p);
    final height = painter.measureHeight(safeContentWidth);
    return await painterToImage(painter, Size(printableWidth, height));
  }

  /// Renders the Marathi Exit Receipt Body (Ticket, Vehicle Box, Timings, Duration, Total Amount, Breakdown, Audit trail).
  static Future<img.Image> renderExitBody(ParkingRecord record, {BusinessProfile? profile}) async {
    final p = profile ?? BusinessProfileController.instance.profile;
    final painter = _MarathiExitBodyPainter(record: record, profile: p);
    final height = painter.measureHeight(safeContentWidth);
    return await painterToImage(painter, Size(printableWidth, height));
  }

  /// Renders the BizFlow Branding Footer for 58mm thermal receipts.
  static Future<img.Image> renderBizFlowFooter({required AppLanguage language}) async {
    final painter = _BizFlowFooterPainter(language: language);
    final height = painter.measureHeight(safeContentWidth);
    return await painterToImage(painter, Size(printableWidth, height));
  }
}

// -----------------------------------------------------------------------------
// PAINTER IMPLEMENTATIONS
// -----------------------------------------------------------------------------

class _MarathiEntryHeaderPainter extends CustomPainter {
  final BusinessProfile profile;
  _MarathiEntryHeaderPainter({required this.profile});

  double measureHeight(double width) {
    double total = 8;
    total += _measureText(profile.marathiHeaderTag, 20, bold: true, width: width); // ॥ श्री ॥ (20px)
    total += 6;
    total += _measureText(profile.marathiGovernmentTag, 15.5, bold: true, width: width); // अधिकृत वाहनतळ (15.5px)
    total += 8;
    total += _measureText(profile.businessNameMarathi, 26, bold: true, width: width); // CAR PARKING SYSTEM (26px)
    total += 6;
    total += _measureText(profile.locationMarathi, 17.5, bold: true, width: width); // संगमनेर बसस्थानक (17.5px)
    total += 4;
    total += _measureText(profile.mobileMarathi, 17.5, bold: true, width: width); // मो. ९६९०७९३४३४ (17.5px)
    total += 8;
    total += 12; // divider
    total += _measureText('प्रवेश पावती', 22, bold: true, width: width); // प्रवेश पावती (22px)
    total += 8;
    return total;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double y = 8;
    const safeW = MarathiReceiptRasterizer.safeContentWidth;
    y = _drawCenteredText(canvas, profile.marathiHeaderTag, y, 20, bold: true, width: safeW);
    y += 6;
    y = _drawCenteredText(canvas, profile.marathiGovernmentTag, y, 15.5, bold: true, width: safeW);
    y += 8;
    y = _drawCenteredText(canvas, profile.businessNameMarathi, y, 26, bold: true, width: safeW);
    y += 6;
    y = _drawCenteredText(canvas, profile.locationMarathi, y, 17.5, bold: true, width: safeW);
    y += 4;
    y = _drawCenteredText(canvas, profile.mobileMarathi, y, 17.5, bold: true, width: safeW);
    y += 8;
    _drawDashedLine(canvas, y, safeW);
    y += 8;
    y = _drawCenteredText(canvas, 'प्रवेश पावती', y, 22, bold: true, width: safeW);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MarathiEntryBodyPainter extends CustomPainter {
  final ParkingRecord record;
  final BusinessProfile profile;

  _MarathiEntryBodyPainter({required this.record, required this.profile});

  double measureHeight(double width) {
    double total = 6;
    total += _measureText('पावती क्र: ${record.ticketNumber}', 20, bold: true, width: width);
    total += 8;
    total += 94; // Vehicle box (84px box + margin)
    total += 12; // divider
    total += 36 * 7; // 7 key-value rows at 17.5px logical font
    total += 12; // divider
    total += _measureText('कृपया ही पावती सांभाळून ठेवा.', 15.5, bold: false, width: width);
    total += 4;
    total += _measureText('वाहन बाहेर काढताना आवश्यक.', 15.5, bold: false, width: width);
    total += 14;
    return total;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double y = 6;
    const safeW = MarathiReceiptRasterizer.safeContentWidth;
    const leftMargin = MarathiReceiptRasterizer.safeLeftMargin;

    // Ticket Number (20px logical, bold w900)
    y = _drawCenteredText(canvas, 'पावती क्र: ${record.ticketNumber}', y, 20, bold: true, width: safeW);
    y += 6;

    // Vehicle Box (Prominent Bold Box, 84px height)
    final vehicleBoxRect = Rect.fromLTWH(leftMargin + 4, y, safeW - 8, 84);
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(vehicleBoxRect, borderPaint);

    final normalizedVeh = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    _drawCenteredText(canvas, 'वाहन क्रमांक', y + 4, 17.5, bold: true, width: safeW);
    _drawCenteredText(canvas, normalizedVeh, y + 24, 26, bold: true, width: safeW);
    final vehTypeMarathi = record.vehicleType.displayName == 'Two-Wheeler' ? 'प्रकार: दुचाकी' : 'प्रकार: चारचाकी';
    _drawCenteredText(canvas, vehTypeMarathi, y + 56, 17.5, bold: true, width: safeW);
    y += 92;

    _drawDashedLine(canvas, y, safeW);
    y += 8;

    // Key-Value rows: 17.5px logical font size (35px raster), FontWeight.w700 label, FontWeight.w900 value
    final entryDate = AppFormatters.formatDate(record.entryTime);
    final entryTime = AppFormatters.formatTime(record.entryTime);
    final customerMob = record.customerMobile.trim().isNotEmpty ? record.customerMobile.trim() : 'लागू नाही';
    final advancePaid = '₹${record.advanceAmount.toStringAsFixed(2)}';
    final advanceMethod = record.advanceAmount > 0
        ? (record.advancePaymentMethod.toUpperCase() == 'CASH' ? 'रोख' : 'यूपीआय')
        : 'लागू नाही';

    y = _drawKeyValueRow(canvas, 'प्रवेश दिनांक:', entryDate, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'प्रवेश वेळ:', entryTime, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'ग्राहक मो.:', customerMob, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'आगाऊ रक्कम:', advancePaid, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'पेमेंट पद्धत:', advanceMethod, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'सुरक्षा रक्षक:', record.entryGuardName, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'पाळी:', record.entryShift, y, safeW, fontSize: 17.5);

    y += 4;
    _drawDashedLine(canvas, y, safeW);
    y += 8;

    // Instructions: 15.5px logical font size
    y = _drawCenteredText(canvas, 'कृपया ही पावती सांभाळून ठेवा.', y, 15.5, bold: false, width: safeW);
    y += 4;
    y = _drawCenteredText(canvas, 'वाहन बाहेर काढताना आवश्यक.', y, 15.5, bold: false, width: safeW);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MarathiExitHeaderPainter extends CustomPainter {
  final BusinessProfile profile;
  _MarathiExitHeaderPainter({required this.profile});

  double measureHeight(double width) {
    double total = 8;
    total += _measureText(profile.marathiHeaderTag, 20, bold: true, width: width); // ॥ श्री ॥ (20px)
    total += 6;
    total += _measureText(profile.marathiGovernmentTag, 15.5, bold: true, width: width); // अधिकृत वाहनतळ (15.5px)
    total += 8;
    total += _measureText(profile.businessNameMarathi, 26, bold: true, width: width); // CAR PARKING SYSTEM (26px)
    total += 6;
    total += _measureText(profile.locationMarathi, 17.5, bold: true, width: width); // संगमनेर बसस्थानक (17.5px)
    total += 4;
    total += _measureText(profile.mobileMarathi, 17.5, bold: true, width: width); // मो. ९६९०७९३४३४ (17.5px)
    total += 8;
    total += 12; // divider
    total += _measureText('निर्गमन पावती', 22, bold: true, width: width); // निर्गमन पावती (22px)
    total += 8;
    return total;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double y = 8;
    const safeW = MarathiReceiptRasterizer.safeContentWidth;
    y = _drawCenteredText(canvas, profile.marathiHeaderTag, y, 20, bold: true, width: safeW);
    y += 6;
    y = _drawCenteredText(canvas, profile.marathiGovernmentTag, y, 15.5, bold: true, width: safeW);
    y += 8;
    y = _drawCenteredText(canvas, profile.businessNameMarathi, y, 26, bold: true, width: safeW);
    y += 6;
    y = _drawCenteredText(canvas, profile.locationMarathi, y, 17.5, bold: true, width: safeW);
    y += 4;
    y = _drawCenteredText(canvas, profile.mobileMarathi, y, 17.5, bold: true, width: safeW);
    y += 8;
    _drawDashedLine(canvas, y, safeW);
    y += 8;
    y = _drawCenteredText(canvas, 'निर्गमन पावती', y, 22, bold: true, width: safeW);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MarathiExitBodyPainter extends CustomPainter {
  final ParkingRecord record;
  final BusinessProfile profile;

  _MarathiExitBodyPainter({required this.record, required this.profile});

  double measureHeight(double width) {
    double total = 6;
    total += _measureText('पावती क्र: ${record.ticketNumber}', 20, bold: true, width: width);
    total += 8;
    total += 94; // Vehicle box (84px box + margin)
    total += 12; // divider
    total += 36 * 3; // Timings & duration (17.5px font)
    total += 12; // divider
    total += 82; // TOTAL AMOUNT box (72px box + margin)
    total += 12; // divider
    total += 36 * 4; // Financial breakdown (17.5px font)
    total += 12; // divider
    total += 36 * 3; // Guards audit trail (17.5px font)
    total += 12; // divider
    total += _measureText('स्थिती: शुल्क जमा व निर्गमन पूर्ण', 17.5, bold: true, width: width);
    total += 6;
    total += _measureText('धन्यवाद! पुन्हा भेट द्या.', 17.5, bold: true, width: width);
    total += 14;
    return total;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double y = 6;
    const safeW = MarathiReceiptRasterizer.safeContentWidth;
    const leftMargin = MarathiReceiptRasterizer.safeLeftMargin;

    // Ticket ID (20px logical, bold w900)
    y = _drawCenteredText(canvas, 'पावती क्र: ${record.ticketNumber}', y, 20, bold: true, width: safeW);
    y += 6;

    // Vehicle Box (Prominent Bold Box, 84px height)
    final vehicleBoxRect = Rect.fromLTWH(leftMargin + 4, y, safeW - 8, 84);
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(vehicleBoxRect, borderPaint);

    final normalizedVeh = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    _drawCenteredText(canvas, 'वाहन क्रमांक', y + 4, 17.5, bold: true, width: safeW);
    _drawCenteredText(canvas, normalizedVeh, y + 24, 26, bold: true, width: safeW);
    final vehTypeMarathi = record.vehicleType.displayName == 'Two-Wheeler' ? 'प्रकार: दुचाकी' : 'प्रकार: चारचाकी';
    _drawCenteredText(canvas, vehTypeMarathi, y + 56, 17.5, bold: true, width: safeW);
    y += 92;

    _drawDashedLine(canvas, y, safeW);
    y += 8;

    final exitTime = record.exitTime ?? DateTime.now();
    final entryStr = '${AppFormatters.formatDate(record.entryTime)} ${AppFormatters.formatTime(record.entryTime)}';
    final exitStr = '${AppFormatters.formatDate(exitTime)} ${AppFormatters.formatTime(exitTime)}';
    final durationStr = AppFormatters.formatDuration(exitTime.difference(record.entryTime));

    // Timings: 17.5px logical font size (35px raster), FontWeight.w700 label, FontWeight.w900 value
    y = _drawKeyValueRow(canvas, 'प्रवेश वेळ:', entryStr, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'बाहेर पडण्याची वेळ:', exitStr, y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'पार्किंग कालावधी:', durationStr, y, safeW, fontSize: 17.5);

    y += 4;
    _drawDashedLine(canvas, y, safeW);
    y += 8;

    final grossCharge = '₹${(record.grossCharge ?? 0.0).toStringAsFixed(2)}';
    final advancePaid = '₹${record.advanceAmount.toStringAsFixed(2)}';
    final hasRefund = (record.refundAmount ?? 0) > 0;
    final hasBalance = (record.balanceDue ?? 0) > 0;
    final paymentMethod = (record.paymentMethod ?? 'CASH').toUpperCase() == 'CASH' ? 'रोख' : 'यूपीआय';

    // TOTAL AMOUNT Box (Prominent Bold Box, 72px height)
    final amountBoxRect = Rect.fromLTWH(leftMargin + 4, y, safeW - 8, 72);
    canvas.drawRect(amountBoxRect, borderPaint);
    _drawCenteredText(canvas, 'एकूण पार्किंग शुल्क', y + 4, 17.5, bold: true, width: safeW);
    _drawCenteredText(canvas, grossCharge, y + 28, 26, bold: true, width: safeW);
    y += 80;

    _drawDashedLine(canvas, y, safeW);
    y += 8;

    // Financial breakdown: 17.5px logical font size (35px raster), FontWeight.w700
    if (record.advanceAmount > 0) {
      y = _drawKeyValueRow(canvas, 'आगाऊ भरलेली रक्कम:', advancePaid, y, safeW, fontSize: 17.5);
      y = _drawKeyValueRow(canvas, 'आगाऊ वजावट:', '-$advancePaid', y, safeW, fontSize: 17.5);
    }

    if (hasRefund) {
      final refundAmt = '₹${record.refundAmount!.toStringAsFixed(2)}';
      y = _drawKeyValueRow(canvas, 'परतावा दिलेली रक्कम:', refundAmt, y, safeW, fontSize: 17.5, isBold: true);
      y = _drawKeyValueRow(canvas, 'परतावा पद्धत:', paymentMethod, y, safeW, fontSize: 17.5);
    } else if (hasBalance) {
      final balAmt = '₹${record.balanceDue!.toStringAsFixed(2)}';
      y = _drawKeyValueRow(canvas, 'वसूल केलेली शिल्लक:', balAmt, y, safeW, fontSize: 17.5, isBold: true);
      y = _drawKeyValueRow(canvas, 'पेमेंट पद्धत:', paymentMethod, y, safeW, fontSize: 17.5);
    } else {
      y = _drawKeyValueRow(canvas, 'अंतिम रक्कम:', '₹०.००', y, safeW, fontSize: 17.5, isBold: true);
      y = _drawKeyValueRow(canvas, 'पेमेंट पद्धत:', paymentMethod, y, safeW, fontSize: 17.5);
    }

    y += 4;
    _drawDashedLine(canvas, y, safeW);
    y += 8;

    // Audit Trail: 17.5px logical font size (35px raster), FontWeight.w700
    y = _drawKeyValueRow(canvas, 'प्रवेश रक्षक:', '${record.entryGuardName} (${record.entryShift})', y, safeW, fontSize: 17.5);
    if (record.advanceCollectorGuardName != null) {
      y = _drawKeyValueRow(canvas, 'आगाऊ स्वीकारक:', record.advanceCollectorGuardName!, y, safeW, fontSize: 17.5);
    }
    y = _drawKeyValueRow(canvas, 'निर्गमन रक्षक:', record.exitGuardName ?? 'सुरक्षा रक्षक', y, safeW, fontSize: 17.5);
    y = _drawKeyValueRow(canvas, 'निर्गमन पाळी:', record.exitShift ?? record.entryShift, y, safeW, fontSize: 17.5);

    y += 6;
    _drawDashedLine(canvas, y, safeW);
    y += 8;

    // Status: 17.5px logical font size (35px raster), FontWeight.w900
    y = _drawCenteredText(canvas, 'स्थिती: शुल्क जमा व निर्गमन पूर्ण', y, 17.5, bold: true, width: safeW);
    y += 6;
    // Notice: 17.5px logical font size (35px raster), FontWeight.w900
    y = _drawCenteredText(canvas, 'धन्यवाद! पुन्हा भेट द्या.', y, 17.5, bold: true, width: safeW);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BizFlowFooterPainter extends CustomPainter {
  final AppLanguage language;
  _BizFlowFooterPainter({required this.language});

  double measureHeight(double width) {
    double total = 10;
    total += 8; // divider
    if (language == AppLanguage.marathi) {
      total += _measureText('द्वारे संचालित', 15.5, bold: false, width: width);
      total += 4;
      total += _measureText('BIZFLOW', 20, bold: true, width: width);
      total += 4;
      total += _measureText('पार्किंग व्यवस्थापन प्रणाली', 15.5, bold: false, width: width);
    } else {
      total += _measureText('Powered by', 15.5, bold: false, width: width);
      total += 4;
      total += _measureText('BIZFLOW', 20, bold: true, width: width);
      total += 4;
      total += _measureText('Parking Management System', 14.5, bold: false, width: width);
    }
    total += 14;
    return total;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double y = 6;
    const safeW = MarathiReceiptRasterizer.safeContentWidth;
    _drawDashedLine(canvas, y, safeW);
    y += 8;

    if (language == AppLanguage.marathi) {
      y = _drawCenteredText(canvas, 'द्वारे संचालित', y, 15.5, bold: false, width: safeW);
      y += 4;
      y = _drawCenteredText(canvas, 'BIZFLOW', y, 20, bold: true, width: safeW);
      y += 4;
      y = _drawCenteredText(canvas, 'पार्किंग व्यवस्थापन प्रणाली', y, 15.5, bold: false, width: safeW);
    } else {
      y = _drawCenteredText(canvas, 'Powered by', y, 15.5, bold: false, width: safeW);
      y += 4;
      y = _drawCenteredText(canvas, 'BIZFLOW', y, 20, bold: true, width: safeW);
      y += 4;
      y = _drawCenteredText(canvas, 'Parking Management System', y, 14.5, bold: false, width: safeW);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// TEXT DRAWING HELPERS
// -----------------------------------------------------------------------------

double _measureText(String text, double fontSize, {required bool bold, required double width}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: Colors.black,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Mangal', 'Lohit Devanagari', 'Roboto', 'Arial'],
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  painter.layout(maxWidth: width);
  return painter.height;
}

double _drawCenteredText(
  Canvas canvas,
  String text,
  double y,
  double fontSize, {
  required bool bold,
  required double width,
  double leftOffset = MarathiReceiptRasterizer.safeLeftMargin,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: Colors.black,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Mangal', 'Lohit Devanagari', 'Roboto', 'Arial'],
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  painter.layout(maxWidth: width);
  final x = leftOffset + (width - painter.width) / 2;
  painter.paint(canvas, Offset(x, y));
  return y + painter.height;
}

double _drawKeyValueRow(
  Canvas canvas,
  String label,
  String value,
  double y,
  double width, {
  bool isBold = false,
  double fontSize = 17.5,
  double leftOffset = MarathiReceiptRasterizer.safeLeftMargin,
}) {
  final labelPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
        color: Colors.black,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Mangal', 'Lohit Devanagari', 'Roboto', 'Arial'],
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  labelPainter.layout(maxWidth: width * 0.50);

  final valuePainter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Mangal', 'Lohit Devanagari', 'Roboto', 'Arial'],
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.right,
  );
  valuePainter.layout(maxWidth: width * 0.50);

  labelPainter.paint(canvas, Offset(leftOffset + 4, y));
  valuePainter.paint(canvas, Offset(leftOffset + width - 4 - valuePainter.width, y));

  final rowHeight = labelPainter.height > valuePainter.height ? labelPainter.height : valuePainter.height;
  return y + rowHeight + 6;
}

void _drawDashedLine(Canvas canvas, double y, double width, {double leftOffset = MarathiReceiptRasterizer.safeLeftMargin}) {
  final paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 1.5;
  const dashWidth = 5.0;
  const dashSpace = 4.0;
  double startX = leftOffset + 2.0;
  final endX = leftOffset + width - 2.0;

  while (startX < endX) {
    canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
    startX += dashWidth + dashSpace;
  }
}
