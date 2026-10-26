import 'dart:typed_data';
import '../plate_scanner_service.dart';

/// Web implementation for OCR plate recognition.
/// Google ML Kit is native to Android & iOS; Web displays a truthful status.
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
      errorMessage: 'On-device OCR is only supported on Android and iOS devices. Please enter the number manually.',
    );
  }
}
