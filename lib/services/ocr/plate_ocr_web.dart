// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../plate_scanner_service.dart';

/// Genuine Web implementation for OCR number plate recognition.
/// Uses browser hardware-accelerated TextDetector when available in Chromium,
/// falls back to in-browser Tesseract.js, or reads image text data.
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

      // 3. Try native browser Shape Detection API (window.TextDetector)
      final textDetectorText = await _recognizeWithTextDetector(imageBytes);
      if (textDetectorText != null && textDetectorText.isNotEmpty) {
        final evaluated = PlateScannerService.evaluateOcr(
          detectedText: textDetectorText,
          photoBytes: imageBytes,
        );
        if (evaluated.hasPlate) {
          return evaluated;
        }
      }

      // 4. Try in-browser Tesseract.js (window.Tesseract)
      final tesseractText = await _recognizeWithTesseract(imageBytes);
      if (tesseractText != null && tesseractText.isNotEmpty) {
        final evaluated = PlateScannerService.evaluateOcr(
          detectedText: tesseractText,
          photoBytes: imageBytes,
        );
        if (evaluated.hasPlate) {
          return evaluated;
        }
      }

      // If text was detected but didn't form a plate candidate:
      final rawAny = textDetectorText ?? tesseractText ?? embeddedText;
      return PlateScanResult(
        isOcr: true,
        confidence: 0.20,
        rawData: rawAny,
        photoBytes: imageBytes,
        errorMessage: rawAny != null && rawAny.isNotEmpty
            ? 'Text found but no valid Indian vehicle plate recognized.'
            : 'Number plate could not be recognized. Please align plate in frame.',
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

  /// Recognizes text using Chromium's native Shape Detection API (window.TextDetector).
  static Future<String?> _recognizeWithTextDetector(Uint8List imageBytes) async {
    if (!js.context.hasProperty('TextDetector')) return null;
    try {
      final base64Url = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      final imgElement = html.ImageElement(src: base64Url);
      await imgElement.onLoad.first;

      final detectorClass = js.context['TextDetector'] as js.JsFunction;
      final detector = js.JsObject(detectorClass);
      final promise = detector.callMethod('detect', [imgElement]);
      final detected = await (promise as Future<dynamic>);
      final list = detected as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final lines = <String>[];
        for (final item in list) {
          final raw = (item as dynamic)['rawValue'] as String?;
          if (raw != null && raw.trim().isNotEmpty) {
            lines.add(raw.trim());
          }
        }
        if (lines.isNotEmpty) {
          return lines.join('\n');
        }
      }
    } catch (e) {
      debugPrint('[PlateOcr Web] TextDetector notice: $e');
    }
    return null;
  }

  /// Recognizes text using in-browser Tesseract.js (window.Tesseract).
  static Future<String?> _recognizeWithTesseract(Uint8List imageBytes) async {
    if (!js.context.hasProperty('Tesseract')) return null;
    try {
      final base64Url = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      final tesseract = js.context['Tesseract'];
      final promise = tesseract.callMethod('recognize', [
        base64Url,
        'eng',
      ]);
      final result = await (promise as Future<dynamic>);
      final data = (result as dynamic)['data'];
      final text = (data as dynamic)['text'] as String?;
      return text?.trim();
    } catch (e) {
      debugPrint('[PlateOcr Web] Tesseract notice: $e');
    }
    return null;
  }
}
