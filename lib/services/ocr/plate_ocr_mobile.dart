import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/utils/formatters.dart';
import '../plate_scanner_service.dart';

/// Genuine On-Device OCR implementation using Google ML Kit Text Recognition.
/// Runs natively on Android and iOS devices.
class PlateOcrPlatform {
  PlateOcrPlatform._();

  static Future<PlateScanResult> recognizePlate({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    // When running in desktop test environments (Windows/macOS/Linux host VM),
    // native ML Kit channels are unavailable. Return graceful non-crashing result.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PlateScanResult(
        isOcr: true,
        confidence: 0.0,
        photoBytes: imageBytes,
        errorMessage: 'On-device OCR is available on Android and iOS devices.',
      );
    }

    File? tempFile;
    String? effectivePath = imagePath;

    try {
      if (effectivePath == null && imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        tempFile = File('${tempDir.path}/plate_ocr_$timestamp.jpg');
        await tempFile.writeAsBytes(imageBytes);
        effectivePath = tempFile.path;
      }

      if (effectivePath == null) {
        return const PlateScanResult(
          isOcr: true,
          confidence: 0.0,
          errorMessage: 'No image provided for OCR processing.',
        );
      }

      final inputImage = InputImage.fromFilePath(effectivePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText;
      try {
        recognizedText = await textRecognizer.processImage(inputImage);
      } finally {
        await textRecognizer.close();
      }

      final fullRawText = recognizedText.text;
      debugPrint('[PlateOcr] Raw recognized text:\n$fullRawText');

      // 1. Gather all line strings
      final List<String> lines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isNotEmpty) {
            lines.add(t);
          }
        }
      }

      // 2. Direct single-line matching
      for (final line in lines) {
        final cleaned = cleanOcrCandidate(line);
        if (AppFormatters.isValidVehicleNumber(cleaned)) {
          return PlateScanResult(
            plateNumber: AppFormatters.normalizeVehicleNumber(cleaned),
            confidence: 0.95,
            isOcr: true,
            rawData: fullRawText,
            photoBytes: imageBytes,
          );
        }
      }

      // 3. Adjacent 2-line combination matching (e.g. state code top line, series+digits bottom line)
      for (int i = 0; i < lines.length - 1; i++) {
        final combined = cleanOcrCandidate('${lines[i]} ${lines[i + 1]}');
        if (AppFormatters.isValidVehicleNumber(combined)) {
          return PlateScanResult(
            plateNumber: AppFormatters.normalizeVehicleNumber(combined),
            confidence: 0.90,
            isOcr: true,
            rawData: fullRawText,
            photoBytes: imageBytes,
          );
        }
      }

      // 4. Regex extraction from full text
      final evaluated = PlateScannerService.evaluateOcr(
        detectedText: fullRawText,
        photoBytes: imageBytes,
      );
      if (evaluated.hasPlate && evaluated.isHighConfidence) {
        return evaluated;
      }

      // 5. Intelligent OCR error correction for standard Indian plates
      for (final line in lines) {
        final corrected = attemptPlateCharacterCorrection(line);
        if (corrected != null && AppFormatters.isValidVehicleNumber(corrected)) {
          return PlateScanResult(
            plateNumber: AppFormatters.normalizeVehicleNumber(corrected),
            confidence: 0.82,
            isOcr: true,
            rawData: fullRawText,
            photoBytes: imageBytes,
          );
        }
      }

      if (evaluated.hasPlate) {
        return evaluated;
      }

      return PlateScanResult(
        isOcr: true,
        confidence: 0.20,
        rawData: fullRawText,
        photoBytes: imageBytes,
        errorMessage: 'Number plate could not be recognized. Please enter manually.',
      );
    } catch (e) {
      debugPrint('[PlateOcr] OCR recognition error: $e');
      return PlateScanResult(
        isOcr: true,
        confidence: 0.0,
        photoBytes: imageBytes,
        errorMessage: 'OCR recognition failed: $e',
      );
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Strips noise, "IND", "HSRP", spaces, and non-alphanumeric characters.
  static String cleanOcrCandidate(String raw) {
    var s = raw.toUpperCase();
    s = s.replaceAll(RegExp(r'\b(IND|INDIA|HSRP)\b'), '');
    s = s.replaceFirst(RegExp(r'^(IND|INDIA|HSRP)'), '');
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // If after stripping non-alphanumeric, it still starts with IND and is at least 8 chars long:
    if (s.startsWith('IND') && s.length >= 8) {
      final sub = s.substring(3);
      if (AppFormatters.isValidVehicleNumber(sub)) {
        return sub;
      }
    }
    return s;
  }

  /// Attempts character error correction for typical OCR confusion in license plates:
  /// e.g. '0' vs 'O', '1' vs 'I', '8' vs 'B', '5' vs 'S'.
  static String? attemptPlateCharacterCorrection(String raw) {
    final clean = cleanOcrCandidate(raw);
    if (clean.length < 8 || clean.length > 11) return null;

    final chars = clean.split('');

    // State code prefix: indices 0, 1 -> must be letters
    for (int i = 0; i < 2; i++) {
      if (chars[i] == '0') chars[i] = 'O';
      if (chars[i] == '1') chars[i] = 'I';
      if (chars[i] == '5') chars[i] = 'S';
      if (chars[i] == '8') chars[i] = 'B';
    }

    // District digits: indices 2, 3 -> must be digits
    for (int i = 2; i <= 3 && i < chars.length; i++) {
      if (chars[i] == 'O' || chars[i] == 'D' || chars[i] == 'Q') chars[i] = '0';
      if (chars[i] == 'I' || chars[i] == 'L') chars[i] = '1';
      if (chars[i] == 'Z') chars[i] = '2';
      if (chars[i] == 'S') chars[i] = '5';
      if (chars[i] == 'B') chars[i] = '8';
    }

    // Registration digits: last 4 characters -> must be digits
    final startDigits = chars.length - 4;
    if (startDigits >= 4) {
      for (int i = startDigits; i < chars.length; i++) {
        if (chars[i] == 'O' || chars[i] == 'D' || chars[i] == 'Q') chars[i] = '0';
        if (chars[i] == 'I' || chars[i] == 'L') chars[i] = '1';
        if (chars[i] == 'Z') chars[i] = '2';
        if (chars[i] == 'S') chars[i] = '5';
        if (chars[i] == 'B') chars[i] = '8';
      }
    }

    return chars.join('');
  }
}
