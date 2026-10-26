import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../plate_scanner_service.dart';
import 'plate_stability_tracker.dart';

/// Platform stub for LiveCameraOcrService.
class LiveCameraOcrPlatform {
  final PlateStabilityTracker stabilityTracker = PlateStabilityTracker();

  bool get isSupported => false;

  Future<void> initialize() async {}

  Future<void> processCameraImage({
    required CameraImage cameraImage,
    required CameraDescription cameraDescription,
    required DeviceOrientation deviceOrientation,
    required Function(String plateNumber, double confidence) onPlateDetected,
    required Function(PlateScanResult qrResult) onQrDetected,
    Function(String status)? onStatusUpdate,
  }) async {}

  void resetStability() {
    stabilityTracker.reset();
  }

  Future<void> dispose() async {}
}
