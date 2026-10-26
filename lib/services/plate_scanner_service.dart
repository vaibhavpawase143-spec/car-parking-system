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
    final normalized = AppFormatters.normalizeVehicleNumber(detectedText);
    final clean = normalized.startsWith('IND') && normalized.length > 3
        ? normalized.substring(3)
        : normalized;

    if (AppFormatters.isValidVehicleNumber(clean)) {
      return PlateScanResult(
        plateNumber: clean,
        confidence: conf,
        isOcr: true,
        rawData: detectedText,
        photoBytes: photoBytes,
      );
    }

    // 1. Attempt Indian state code regex extraction (handles "IND MH 12 AB 1234", "IND•MH12AB1234", etc.)
    final stateMatch = RegExp(
      r'(?:IND)?(AP|AR|AS|BR|CG|CH|DD|DL|DN|GA|GJ|HP|HR|JH|JK|KA|KL|LA|LD|MH|ML|MN|MP|MZ|NL|OD|OR|PB|PY|RJ|SK|TN|TR|TS|UA|UK|UP|WB)\d{1,2}[A-Z]{0,3}\d{1,4}',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (stateMatch != null) {
      final candidate = stateMatch.group(0)!;
      final cleanCandidate = candidate.startsWith('IND') && candidate.length > 3
          ? candidate.substring(3)
          : candidate;
      if (AppFormatters.isValidVehicleNumber(cleanCandidate)) {
        return PlateScanResult(
          plateNumber: cleanCandidate,
          confidence: conf * 0.90,
          isOcr: true,
          rawData: detectedText,
          photoBytes: photoBytes,
        );
      }
    }

    // 2. Bharat series match
    final bhMatch = RegExp(r'\d{2}BH\d{4}[A-Z]{1,2}', caseSensitive: false).firstMatch(normalized);
    if (bhMatch != null) {
      final candidate = bhMatch.group(0)!;
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

    // 3. General fallback regex extraction from noisy OCR text
    final standardMatch = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{1,5}[A-Z]?').firstMatch(clean);
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

    return PlateScanResult(
      isOcr: true,
      confidence: 0.30,
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
