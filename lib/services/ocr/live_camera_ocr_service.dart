import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../plate_scanner_service.dart';
import 'plate_stability_tracker.dart';
import 'live_camera_ocr_stub.dart'
    if (dart.library.html) 'live_camera_ocr_web.dart'
    if (dart.library.io) 'live_camera_ocr_mobile.dart';

/// Service providing live camera frame OCR and QR detection.
/// Automatically scans camera frames without requiring manual photo capture.
class LiveCameraOcrService {
  final LiveCameraOcrPlatform _platform = LiveCameraOcrPlatform();

  /// Testing hook: mock live plate detection callback for automated tests.
  static String? mockDetectedPlate;

  /// Testing hook: mock live QR detection callback for automated tests.
  static PlateScanResult? mockDetectedQr;

  PlateStabilityTracker get stabilityTracker => _platform.stabilityTracker;

  bool get isSupported => _platform.isSupported;

  Future<void> initialize() async {
    await _platform.initialize();
  }

  Future<void> processCameraImage({
    required CameraImage cameraImage,
    required CameraDescription cameraDescription,
    required DeviceOrientation deviceOrientation,
    required Function(String plateNumber, double confidence) onPlateDetected,
    required Function(PlateScanResult qrResult) onQrDetected,
    Function(String status)? onStatusUpdate,
  }) async {
    if (mockDetectedPlate != null) {
      final stable = stabilityTracker.addCandidate(mockDetectedPlate!);
      if (stable != null) {
        onStatusUpdate?.call('Plate detected: $stable');
        onPlateDetected(stable, 1.0);
      } else {
        onStatusUpdate?.call(stabilityTracker.statusText);
      }
      return;
    }

    if (mockDetectedQr != null) {
      onQrDetected(mockDetectedQr!);
      return;
    }

    await _platform.processCameraImage(
      cameraImage: cameraImage,
      cameraDescription: cameraDescription,
      deviceOrientation: deviceOrientation,
      onPlateDetected: onPlateDetected,
      onQrDetected: onQrDetected,
      onStatusUpdate: onStatusUpdate,
    );
  }

  void resetStability() {
    _platform.resetStability();
  }

  Future<void> dispose() async {
    await _platform.dispose();
  }

  static void resetMocks() {
    mockDetectedPlate = null;
    mockDetectedQr = null;
  }
}
