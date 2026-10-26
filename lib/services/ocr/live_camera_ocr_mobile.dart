import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/utils/formatters.dart';
import '../plate_scanner_service.dart';
import 'plate_ocr_mobile.dart';
import 'plate_stability_tracker.dart';

/// Native Android/iOS implementation of real-time camera frame OCR and QR scanner.
class LiveCameraOcrPlatform {
  final PlateStabilityTracker stabilityTracker = PlateStabilityTracker();

  late final TextRecognizer _textRecognizer;
  late final BarcodeScanner _barcodeScanner;
  bool _isInitialized = false;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!isSupported || _isInitialized) return;
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    _isInitialized = true;
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Processes a single live camera frame for both OCR number plate recognition
  /// and QR barcode scanning.
  Future<void> processCameraImage({
    required CameraImage cameraImage,
    required CameraDescription cameraDescription,
    required DeviceOrientation deviceOrientation,
    required Function(String plateNumber, double confidence) onPlateDetected,
    required Function(PlateScanResult qrResult) onQrDetected,
    Function(String status)? onStatusUpdate,
  }) async {
    if (!isSupported || !_isInitialized) return;

    final inputImage = _inputImageFromCameraImage(
      image: cameraImage,
      camera: cameraDescription,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) {
      if (kDebugMode) {
        debugPrint('[LiveCameraOcr] Failed to convert CameraImage to InputImage');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[LiveCameraOcr] Frame -> InputImage conversion successful. Calling _textRecognizer.processImage()...');
    }

    // 1. Text Recognition for Live Number Plate Extraction
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final raw = recognizedText.text.trim();

      if (kDebugMode) {
        debugPrint('[LiveCameraOcr] OCR returned blocks: ${recognizedText.blocks.length}, rawText: "${raw.replaceAll('\n', ' ')}"');
      }

      if (raw.isNotEmpty) {
        onStatusUpdate?.call('Text detected — validating plate...');
        final candidate = _extractPlateCandidate(recognizedText);

        if (candidate != null) {
          if (kDebugMode) {
            debugPrint('[LiveCameraOcr] Plate candidate extracted: $candidate');
          }
          final stablePlate = stabilityTracker.addCandidate(candidate);
          if (stablePlate != null) {
            if (kDebugMode) {
              debugPrint('[LiveCameraOcr] Plate stable & locked: $stablePlate (consensus reached)');
            }
            onStatusUpdate?.call('Plate detected: $stablePlate');
            onPlateDetected(stablePlate, 0.95);
          } else {
            if (kDebugMode) {
              debugPrint('[LiveCameraOcr] Stability progress: ${stabilityTracker.consecutiveCount}/${stabilityTracker.requiredConsecutiveMatches} for $candidate');
            }
            onStatusUpdate?.call(stabilityTracker.statusText);
          }
        } else {
          if (kDebugMode) {
            debugPrint('[LiveCameraOcr] Text detected but no valid Indian plate candidate found (rejection: non-matching format or noise)');
          }
          onStatusUpdate?.call('Text detected — validating plate...');
        }
      } else {
        stabilityTracker.registerEmptyFrame();
        onStatusUpdate?.call(stabilityTracker.statusText);
      }
    } catch (e) {
      debugPrint('[LiveCameraOcr] Frame OCR error: $e');
    }

    // 2. Barcode Scanning for Live QR Detection
    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final rawVal = barcode.rawValue;
        if (rawVal != null && rawVal.trim().isNotEmpty) {
          final qrResult = PlateScannerService.parseQrData(rawVal);
          if (qrResult.hasPlate) {
            if (kDebugMode) {
              debugPrint('[LiveCameraOcr] QR code detected with plate: ${qrResult.plateNumber}');
            }
            onQrDetected(qrResult);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[LiveCameraOcr] Frame QR error: $e');
    }
  }

  // Matches Indian HSRP / standard plates with 36 state codes (e.g. MH 12 AB 1234, IND MH12AB1234, MH-12-AB-1234)
  static final RegExp _indianStatePlatePattern = RegExp(
    r'(?:IND[\s\.\-]*)?(AP|AR|AS|BR|CG|CH|DD|DL|DN|GA|GJ|HP|HR|JH|JK|KA|KL|LA|LD|MH|ML|MN|MP|MZ|NL|OD|OR|PB|PY|RJ|SK|TN|TR|TS|UA|UK|UP|WB)\s*([0-9]{1,2})\s*([A-Z]{0,3})\s*([0-9]{1,4})',
    caseSensitive: false,
  );

  // General fallback for any 2-letter state code
  static final RegExp _generalPlatePattern = RegExp(
    r'\b([A-Z]{2})\s*([0-9]{1,2})\s*([A-Z]{0,3})\s*([0-9]{1,4})\b',
    caseSensitive: false,
  );

  // Bharat series format: 22 BH 1234 AA
  static final RegExp _bharatSeriesPattern = RegExp(
    r'([0-9]{2})\s*(BH)\s*([0-9]{4})\s*([A-Z]{1,2})',
    caseSensitive: false,
  );

  /// Extracts a valid Indian number plate candidate from recognized text blocks.
  String? _extractPlateCandidate(RecognizedText recognizedText) {
    final List<String> lines = [];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) {
          lines.add(t);
        }
      }
    }

    // 1. Prioritized state-code regex extraction across each line (handles "IND MH 12 AB 1234", "IND•MH12AB1234", "MH-12-AB-1234")
    for (final line in lines) {
      for (final match in _indianStatePlatePattern.allMatches(line)) {
        final matchedText = match.group(0)!;
        final normalized = AppFormatters.normalizeVehicleNumber(matchedText);
        final clean = normalized.startsWith('IND') && normalized.length > 3 ? normalized.substring(3) : normalized;
        if (AppFormatters.isValidVehicleNumber(clean)) {
          return clean;
        }
      }
      for (final match in _bharatSeriesPattern.allMatches(line)) {
        final matchedText = match.group(0)!;
        final normalized = AppFormatters.normalizeVehicleNumber(matchedText);
        if (AppFormatters.isValidVehicleNumber(normalized)) {
          return normalized;
        }
      }
    }

    // 2. Exact single-line candidate check with HSRP/IND noise removal
    for (final line in lines) {
      final cleaned = PlateOcrPlatform.cleanOcrCandidate(line);
      if (AppFormatters.isValidVehicleNumber(cleaned)) {
        return AppFormatters.normalizeVehicleNumber(cleaned);
      }
    }

    // 3. Fallback general plate pattern with allMatches
    for (final line in lines) {
      for (final match in _generalPlatePattern.allMatches(line)) {
        final matchedText = match.group(0)!;
        final normalized = AppFormatters.normalizeVehicleNumber(matchedText);
        final clean = normalized.startsWith('IND') && normalized.length > 3 ? normalized.substring(3) : normalized;
        if (AppFormatters.isValidVehicleNumber(clean)) {
          return clean;
        }
      }
    }

    // 4. Adjacent two-line candidate check (e.g. MH12 on top, AB1234 on bottom)
    for (int i = 0; i < lines.length - 1; i++) {
      final combined = PlateOcrPlatform.cleanOcrCandidate('${lines[i]} ${lines[i + 1]}');
      if (AppFormatters.isValidVehicleNumber(combined)) {
        return AppFormatters.normalizeVehicleNumber(combined);
      }
    }

    // 5. Full text regex extraction
    final fullText = recognizedText.text;
    for (final match in _indianStatePlatePattern.allMatches(fullText)) {
      final matchedText = match.group(0)!;
      final normalized = AppFormatters.normalizeVehicleNumber(matchedText);
      final clean = normalized.startsWith('IND') && normalized.length > 3 ? normalized.substring(3) : normalized;
      if (AppFormatters.isValidVehicleNumber(clean)) {
        return clean;
      }
    }
    for (final match in _bharatSeriesPattern.allMatches(fullText)) {
      final matchedText = match.group(0)!;
      final normalized = AppFormatters.normalizeVehicleNumber(matchedText);
      if (AppFormatters.isValidVehicleNumber(normalized)) {
        return normalized;
      }
    }

    // 6. Optical character error correction (O<->0, I<->1, B<->8, S<->5)
    for (final line in lines) {
      final corrected = PlateOcrPlatform.attemptPlateCharacterCorrection(line);
      if (corrected != null && AppFormatters.isValidVehicleNumber(corrected)) {
        return AppFormatters.normalizeVehicleNumber(corrected);
      }
    }

    // 7. Fallback evaluator
    final evaluated = PlateScannerService.evaluateOcr(detectedText: fullText);
    if (evaluated.hasPlate && evaluated.isHighConfidence) {
      return evaluated.plateNumber;
    }

    return null;
  }

  /// Converts a CameraImage frame into an ML Kit InputImage.
  /// Handles 1-plane NV21 and 3-plane YUV420 on Android, and BGRA on iOS.
  static InputImage? _inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    if (image.planes.isEmpty) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation != null) {
        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
    }
    rotation ??= InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

    final rawFormat = image.format.raw;
    final parsedFormat = InputImageFormatValue.fromRawValue(rawFormat);

    // Format selection: ML Kit Android requires NV21 format for fromByteArray
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : (parsedFormat ?? InputImageFormat.bgra8888);

    final int bytesPerRow;
    Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if (image.planes.length == 3 && Platform.isAndroid) {
      bytes = _yuv420ToNv21(image);
      // Essential: _yuv420ToNv21 strips row stride padding and writes packed rows of width `image.width`
      bytesPerRow = image.width;
    } else {
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
      bytesPerRow = image.planes.first.bytesPerRow;
    }

    if (kDebugMode) {
      debugPrint('[LiveCameraOcr] Frame metadata: format=$rawFormat ($format), planes=${image.planes.length}, '
          'w=${image.width}, h=${image.height}, bytesPerRow=$bytesPerRow, bytes=${bytes.length}, rot=${rotation.name}');
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  /// Converts 3-plane Android YUV_420_888 to contiguous NV21 byte buffer (Y followed by interleaved VU).
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    // Copy Y plane row-by-row respecting rowStride
    int idy = 0;
    for (int y = 0; y < height; y++) {
      final yRowStart = y * yPlane.bytesPerRow;
      for (int x = 0; x < width; x++) {
        nv21[idy++] = yBuffer[yRowStart + x];
      }
    }

    // Interleave VU for NV21
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    int iduv = numPixels;
    for (int y = 0; y < uvHeight; y++) {
      final int uRowStart = y * uRowStride;
      final int vRowStart = y * vRowStride;
      for (int x = 0; x < uvWidth; x++) {
        nv21[iduv++] = vBuffer[vRowStart + x * vPixelStride];
        nv21[iduv++] = uBuffer[uRowStart + x * uPixelStride];
      }
    }

    return nv21;
  }

  void resetStability() {
    stabilityTracker.reset();
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    try {
      await _textRecognizer.close();
    } catch (_) {}
    try {
      await _barcodeScanner.close();
    } catch (_) {}
    _isInitialized = false;
  }
}
