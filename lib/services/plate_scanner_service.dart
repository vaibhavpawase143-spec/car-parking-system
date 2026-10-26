import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';
import '../models/vehicle_type.dart';

/// Result of scanning a QR code or performing ANPR/OCR number plate detection.
class PlateScanResult {
  final String? plateNumber;
  final VehicleType? vehicleType;
  final double confidence; // 0.0 to 1.0
  final bool isQr;
  final bool isOcr;
  final String? rawData;
  final Uint8List? photoBytes;
  final String? errorMessage;
  final bool isPermissionDenied;

  const PlateScanResult({
    this.plateNumber,
    this.vehicleType,
    this.confidence = 1.0,
    this.isQr = false,
    this.isOcr = false,
    this.rawData,
    this.photoBytes,
    this.errorMessage,
    this.isPermissionDenied = false,
  });

  bool get hasPlate => plateNumber != null && plateNumber!.trim().isNotEmpty;

  /// High confidence detection threshold is 75% (0.75).
  bool get isHighConfidence => confidence >= 0.75;
}

/// Service providing QR payload parsing, ANPR/OCR evaluation,
/// conflict detection, and testing hooks for vehicle entry.
class PlateScannerService {
  PlateScannerService._();
  static final PlateScannerService instance = PlateScannerService._();

  /// Testing hook: mock scan result for unit and widget tests.
  static PlateScanResult? mockScanResult;

  /// Testing hook: mock camera permission denied.
  static bool mockPermissionDenied = false;

  /// Testing hook: simulated confidence override.
  static double? mockConfidence;

  /// Valid 67-byte 1x1 transparent PNG bytes for mock photos and test frames.
  static final Uint8List kTransparent1x1Png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ]);

  /// Sample valid non-placeholder image bytes for testing real photo capture (167 bytes).
  static final Uint8List kTestSamplePhotoBytes = Uint8List.fromList([
    ...kTransparent1x1Png,
    ...List.generate(100, (i) => i % 256),
  ]);

  /// Returns true if the byte buffer is null, empty, or represents the 1x1 transparent PNG placeholder.
  /// Used to ensure placeholders are never treated or saved as genuine photos.
  static bool isPlaceholder(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return true;
    if (bytes.length <= 67) return true;
    if (bytes.length == kTransparent1x1Png.length) {
      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i] != kTransparent1x1Png[i]) return false;
      }
      return true;
    }
    return false;
  }

  /// Clears all test mocks.
  static void resetMocks() {
    mockScanResult = null;
    mockPermissionDenied = false;
    mockConfidence = null;
  }

  /// Parses a raw QR payload.
  /// Strictly extracts plate number and vehicle type only when genuine data is present.
  /// Never fakes OCR results or claims vehicle type is present when omitted.
  static PlateScanResult parseQrData(String raw, {Uint8List? frameBytes}) {
    if (mockScanResult != null) {
      return mockScanResult!;
    }

    final clean = raw.trim();
    if (clean.isEmpty) {
      return const PlateScanResult(errorMessage: 'Empty QR payload');
    }

    String? extractedPlate;
    VehicleType? extractedType;

    // 1. Try parsing JSON payload
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map<String, dynamic>) {
          // Look for vehicle registration number
          final dynamic rawPlate = decoded['vehicleNumber'] ??
              decoded['plate'] ??
              decoded['vehicleNo'] ??
              decoded['registration'] ??
              decoded['numberPlate'];

          if (rawPlate != null && rawPlate.toString().trim().isNotEmpty) {
            extractedPlate = AppFormatters.normalizeVehicleNumber(rawPlate.toString());
          }

          // Look for explicit vehicle type ONLY if present
          final dynamic rawType = decoded['vehicleType'] ?? decoded['type'] ?? decoded['category'];
          if (rawType != null) {
            final tStr = rawType.toString().toLowerCase();
            if (tStr.contains('two') || tStr.contains('2') || tStr == 'bike' || tStr == 'scooter') {
              extractedType = VehicleType.twoWheeler;
            } else if (tStr.contains('four') || tStr.contains('4') || tStr == 'car') {
              extractedType = VehicleType.fourWheeler;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Try parsing plain-text or key-value format (e.g., "MH12AB1234" or "PLATE:MH12AB1234;TYPE:CAR")
    if (extractedPlate == null) {
      // Check for key-value pairs
      if (clean.contains(':') || clean.contains('=')) {
        final parts = clean.split(RegExp(r'[;,\n&]'));
        for (final p in parts) {
          final kv = p.split(RegExp(r'[:=]'));
          if (kv.length == 2) {
            final k = kv[0].trim().toLowerCase();
            final v = kv[1].trim();
            if (k.contains('plate') || k.contains('vehicle') || k.contains('reg')) {
              if (AppFormatters.isValidVehicleNumber(v)) {
                extractedPlate = AppFormatters.normalizeVehicleNumber(v);
              }
            } else if (k.contains('type')) {
              final tStr = v.toLowerCase();
              if (tStr.contains('two') || tStr.contains('2') || tStr == 'bike') {
                extractedType = VehicleType.twoWheeler;
              } else if (tStr.contains('four') || tStr.contains('4') || tStr == 'car') {
                extractedType = VehicleType.fourWheeler;
              }
            }
          }
        }
      }

      // Check if entire raw text is directly a valid Indian vehicle number
      if (extractedPlate == null && AppFormatters.isValidVehicleNumber(clean)) {
        extractedPlate = AppFormatters.normalizeVehicleNumber(clean);
      }
    }

    if (extractedPlate != null && extractedPlate.isNotEmpty) {
      return PlateScanResult(
        plateNumber: extractedPlate,
        vehicleType: extractedType,
        confidence: 1.0,
        isQr: true,
        rawData: clean,
        photoBytes: frameBytes,
      );
    }

    return PlateScanResult(
      rawData: clean,
      isQr: true,
      errorMessage: 'QR scanned successfully but does not contain a valid vehicle number.',
    );
  }

  /// Cleans noise, "IND", "INDIA", "HSRP", spaces, and non-alphanumeric characters.
  static String cleanOcrCandidate(String raw) {
    var s = raw.toUpperCase();
    s = s.replaceAll(RegExp(r'\b(IND|INDIA|HSRP)\b'), '');
    s = s.replaceFirst(RegExp(r'^(IND|INDIA|HSRP)'), '');
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (s.startsWith('IND') && s.length >= 8) {
      final sub = s.substring(3);
      if (AppFormatters.isValidVehicleNumber(sub)) {
        return sub;
      }
    }
    return s;
  }

  /// Detects whether a token is an HSRP laser-etched serial number rather than a vehicle plate.
  /// HSRP laser serial numbers typically consist of 1-3 letters followed by 8-12 digits
  /// (e.g. AA2039485721) or 8+ consecutive digits, which do not correspond to any valid state RTO registration.
  static bool isLaserSerialNumber(String token) {
    final clean = token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (clean.length >= 10 && RegExp(r'^[A-Z]{1,3}\d{7,}$').hasMatch(clean)) {
      return true;
    }
    if (RegExp(r'^\d{8,}$').hasMatch(clean)) {
      return true;
    }
    return false;
  }

  /// Attempts character error correction for typical OCR confusion in license plates:
  /// e.g. '0' vs 'O'/'D'/'Q', '1' vs 'I'/'L', '8' vs 'B', '5' vs 'S', '2' vs 'Z'.
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

  /// Evaluates ANPR/OCR text from a camera snapshot or photo frame.
  /// Returns a [PlateScanResult] with confidence evaluation.
  static PlateScanResult evaluateOcr({
    String detectedText = '',
    Uint8List? photoBytes,
    double defaultConfidence = 0.90,
  }) {
    if (mockScanResult != null) {
      return mockScanResult!;
    }

    final double conf = mockConfidence ?? defaultConfidence;
    if (detectedText.trim().isEmpty) {
      return PlateScanResult(
        isOcr: true,
        confidence: 0.0,
        photoBytes: photoBytes,
        errorMessage: 'No text recognized in image.',
      );
    }

    // 1. Split detected text into separate lines and tokens
    final rawLines = detectedText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 2. Direct line evaluation (ignoring laser serial lines and noise words)
    for (final line in rawLines) {
      if (isLaserSerialNumber(line)) continue;
      final clean = cleanOcrCandidate(line);
      if (clean.isEmpty || clean == 'IND' || clean == 'INDIA' || clean == 'HSRP') continue;

      if (AppFormatters.isValidVehicleNumber(clean)) {
        return PlateScanResult(
          plateNumber: clean,
          confidence: conf,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 3. Adjacent multi-line combination (e.g. "MH 12" on line 1, "AB 1234" on line 2)
    final filteredLines = rawLines
        .where((l) => !isLaserSerialNumber(l))
        .map(cleanOcrCandidate)
        .where((l) => l.isNotEmpty && l != 'IND' && l != 'INDIA' && l != 'HSRP')
        .toList();

    for (int i = 0; i < filteredLines.length - 1; i++) {
      final combined = '${filteredLines[i]}${filteredLines[i + 1]}';
      if (AppFormatters.isValidVehicleNumber(combined)) {
        return PlateScanResult(
          plateNumber: combined,
          confidence: conf * 0.95,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 4. Remove laser serial numbers from full text before global regex match
    var textWithoutLaser = detectedText;
    final laserMatches = RegExp(r'\b[A-Z]{1,3}\d{7,}\b').allMatches(textWithoutLaser);
    for (final m in laserMatches) {
      textWithoutLaser = textWithoutLaser.replaceFirst(m.group(0)!, '');
    }

    final normalized = AppFormatters.normalizeVehicleNumber(textWithoutLaser);
    final cleanFull = cleanOcrCandidate(normalized);

    if (AppFormatters.isValidVehicleNumber(cleanFull)) {
      return PlateScanResult(
        plateNumber: cleanFull,
        confidence: conf,
        isOcr: true,
        rawData: detectedText,
        photoBytes: photoBytes,
      );
    }

    // 5. Standard State code match
    final stateMatch = RegExp(
      r'(?:IND)?(AP|AR|AS|BR|CG|CH|DD|DL|DN|GA|GJ|HP|HR|JH|JK|KA|KL|LA|LD|MH|ML|MN|MP|MZ|NL|OD|OR|PB|PY|RJ|SK|TN|TR|TS|UA|UK|UP|WB)\d{1,2}[A-Z]{0,3}\d{1,4}',
      caseSensitive: false,
    ).firstMatch(cleanFull);
    if (stateMatch != null) {
      final candidate = cleanOcrCandidate(stateMatch.group(0)!);
      if (AppFormatters.isValidVehicleNumber(candidate)) {
        return PlateScanResult(
          plateNumber: candidate,
          confidence: conf * 0.90,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 6. Bharat series match
    final bhMatch = RegExp(r'\d{2}BH\d{4}[A-Z]{1,2}', caseSensitive: false).firstMatch(cleanFull);
    if (bhMatch != null) {
      final candidate = cleanOcrCandidate(bhMatch.group(0)!);
      if (AppFormatters.isValidVehicleNumber(candidate)) {
        return PlateScanResult(
          plateNumber: candidate,
          confidence: conf * 0.90,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 7. General fallback regex extraction from clean text
    final standardMatch = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{1,5}[A-Z]?').firstMatch(cleanFull);
    if (standardMatch != null) {
      final candidate = standardMatch.group(0)!;
      if (AppFormatters.isValidVehicleNumber(candidate)) {
        return PlateScanResult(
          plateNumber: candidate,
          confidence: conf * 0.85,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 8. Intelligent character correction on lines
    for (final line in rawLines) {
      if (isLaserSerialNumber(line)) continue;
      final corrected = attemptPlateCharacterCorrection(line);
      if (corrected != null && AppFormatters.isValidVehicleNumber(corrected)) {
        return PlateScanResult(
          plateNumber: corrected,
          confidence: conf * 0.85,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    return PlateScanResult(
      isOcr: true,
      confidence: 0.20,
      rawData: detectedText,
      photoBytes: photoBytes,
      errorMessage: 'Number plate could not be recognized with sufficient confidence.',
    );
  }

  /// Checks if QR scan and OCR scan readings conflict.
  /// Returns true only when both readings are present, non-empty, and differ.
  static bool hasConflict(String? qrPlate, String? ocrPlate) {
    if (qrPlate == null || ocrPlate == null) return false;
    final cleanQr = AppFormatters.normalizeVehicleNumber(qrPlate);
    final cleanOcr = AppFormatters.normalizeVehicleNumber(ocrPlate);
    if (cleanQr.isEmpty || cleanOcr.isEmpty) return false;
    return cleanQr != cleanOcr;
  }
}
