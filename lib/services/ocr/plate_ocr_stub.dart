import 'dart:typed_data';
import '../plate_scanner_service.dart';

/// Platform stub for OCR plate recognition.
class PlateOcrPlatform {
  PlateOcrPlatform._();

  static Future<PlateScanResult> recognizePlate({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    return PlateScanResult(
      isOcr: true,
      confidence: 0.0,
      photoBytes: imageBytes,
      errorMessage: 'On-device OCR is not supported on this platform.',
    );
  }
}
