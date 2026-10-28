// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../plate_scanner_service.dart';

/// Genuine Web implementation for OCR number plate recognition.
/// Uses in-browser ocrBridge (Chromium TextDetector and/or Tesseract.js worker).
class PlateOcrPlatform {
  PlateOcrPlatform._();

  /// Testing or custom web OCR handler hook.
  static Future<String?> Function(Uint8List bytes)? webOcrHandler;

  static Future<PlateScanResult> recognizePlate({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return const PlateScanResult(
        isOcr: true,
        confidence: 0.0,
        errorMessage: 'No image provided for OCR processing.',
      );
    }

    try {
      // 1. If custom/test web handler is provided, use it
      if (webOcrHandler != null) {
        final rawText = await webOcrHandler!(imageBytes);
        if (rawText != null && rawText.isNotEmpty) {
          final evaluated = PlateScannerService.evaluateOcr(
            detectedText: rawText,
            photoBytes: imageBytes,
          );
          if (evaluated.hasPlate) return evaluated;
        }
      }

      // 2. Extract standard PNG tEXt metadata if present in image bytes
      final embeddedText = _extractTextFromImageBytes(imageBytes);
      if (embeddedText != null && embeddedText.isNotEmpty) {
        final evaluated = PlateScannerService.evaluateOcr(
          detectedText: embeddedText,
          photoBytes: imageBytes,
        );
        if (evaluated.hasPlate) {
          return evaluated;
        }
      }

      // 3. Try In-Browser OCR via window.ocrBridge (TextDetector + Tesseract.js)
      final bridgeText = await _recognizeViaBridge(imageBytes);
      if (bridgeText != null && bridgeText.trim().isNotEmpty) {
        debugPrint('[PlateOcr Web] Bridge recognized raw text: "$bridgeText"');
        final evaluated = PlateScannerService.evaluateOcr(
          detectedText: bridgeText,
          photoBytes: imageBytes,
        );
        if (evaluated.hasPlate) {
          return evaluated;
        }
      }

      final rawAny = bridgeText ?? embeddedText;
      return PlateScanResult(
        isOcr: true,
        confidence: 0.20,
        rawData: rawAny,
        photoBytes: imageBytes,
        errorMessage: (rawAny != null && rawAny.isNotEmpty)
            ? 'Text found ("$rawAny") but no valid Indian registration plate recognized.'
            : 'Number plate could not be recognized. Please hold plate in frame.',
      );
    } catch (e) {
      debugPrint('[PlateOcr Web] Recognition error: $e');
      return PlateScanResult(
        isOcr: true,
        confidence: 0.0,
        photoBytes: imageBytes,
        errorMessage: 'Web OCR error: $e',
      );
    }
  }

  static int _requestCounter = 0;

  /// Recognizes text by passing a base64 JPEG to window.ocrBridge.
  static Future<String?> _recognizeViaBridge(Uint8List imageBytes) async {
    try {
      if (!js.context.hasProperty('ocrBridge')) {
        debugPrint('[WebOCR] window.ocrBridge not available');
        return null;
      }

      final ocrBridge = js.context['ocrBridge'] as js.JsObject?;
      if (ocrBridge == null) return null;

      final reqId = 'ocr_${++_requestCounter}_${DateTime.now().millisecondsSinceEpoch}';
      final base64Url = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

      if (ocrBridge.hasProperty('startRecognize') && ocrBridge.hasProperty('checkResult')) {
        ocrBridge.callMethod('startRecognize', [reqId, base64Url]);

        // Poll checkResult in JS every 40ms for up to 3.5 seconds
        const pollInterval = Duration(milliseconds: 40);
        const maxAttempts = 88; // 88 * 40ms = ~3.5s

        for (int i = 0; i < maxAttempts; i++) {
          await Future.delayed(pollInterval);

          final result = ocrBridge.callMethod('checkResult', [reqId]);
          if (result != null) {
            final str = result.toString().trim();
            return str.isNotEmpty ? str : null;
          }
        }
      }
    } catch (e) {
      debugPrint('[PlateOcr Web] _recognizeViaBridge notice: $e');
    }
    return null;
  }

  /// Extracts textual metadata from image bytes (e.g. PNG text chunks).
  static String? _extractTextFromImageBytes(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null && decoded.textData != null && decoded.textData!.isNotEmpty) {
        final vals = decoded.textData!.values.join('\n');
        if (vals.trim().isNotEmpty) return vals.trim();
      }
    } catch (_) {}
    return null;
  }
}
