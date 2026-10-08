import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'qr_share_stub.dart'
    if (dart.library.html) 'qr_share_web.dart';

/// Service responsible for generating the actual QR image as a PNG
/// and general QR generation utilities.
class QrShareService {
  /// Generates crisp, scannable PNG bytes for the given QR string using QrPainter.
  /// Strictly reuses the exact same QR data displayed on the Digital Entry Slip.
  static Future<Uint8List> generateQrPng(String qrData, {double size = 400.0}) async {
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
    );
    final byteData = await painter.toImageData(size, format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to generate QR PNG image data');
    }
    return byteData.buffer.asUint8List();
  }

  /// Checks whether image clipboard writing is supported by the current browser.
  static bool canCopyQrImageToClipboard() {
    return QrPlatformShare.canWriteImageToClipboard();
  }

  /// Copies the raw QR PNG bytes to the system clipboard.
  /// Returns true only if the operation succeeded without throwing or being rejected.
  static Future<bool> copyQrImageToClipboard(Uint8List bytes) async {
    return await QrPlatformShare.copyImageToClipboard(bytes);
  }

  /// Downloads the QR PNG image directly to the user's device as a fallback.
  static void downloadQrImage(Uint8List bytes, String fileName) {
    QrPlatformShare.downloadImage(bytes, fileName);
  }
}
