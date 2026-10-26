import 'dart:typed_data';
import '../plate_scanner_service.dart';
import 'plate_ocr_stub.dart'
    if (dart.library.html) 'plate_ocr_web.dart'
    if (dart.library.io) 'plate_ocr_mobile.dart';

/// Service providing genuine on-device OCR plate recognition.
/// Uses Google ML Kit on Android and iOS devices, with graceful fallbacks
/// on Web/Desktop and testing hooks for unit/widget tests.
class PlateOcrService {
  PlateOcrService._();

  /// Testing hook: mock OCR scan result.
  static PlateScanResult? mockOcrResult;

  /// Recognizes vehicle number plate from actual camera image.
  /// [imagePath] path to the image on local device storage.
  /// [imageBytes] optional raw bytes of the captured image.
  static Future<PlateScanResult> recognizePlate({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    if (mockOcrResult != null) {
      return mockOcrResult!;
    }

    return PlateOcrPlatform.recognizePlate(
      imagePath: imagePath,
      imageBytes: imageBytes,
    );
  }

  /// Clears testing mocks.
  static void resetMocks() {
    mockOcrResult = null;
  }
}
