import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'camera_device_info.dart';

export 'camera_device_info.dart';

/// Non-web fallback stub for WebCameraPlatform.
/// Returns safe defaults and supports mock hooks for unit/widget testing on VM.
class WebCameraPlatform {
  static bool get isSupported => mockIsSupported ?? false;
  static bool? mockIsSupported;
  static String? lastSelectedDeviceId;

  static Future<List<CameraDeviceInfo>> Function()? mockGetAvailableCameras;
  static Future<CameraStartResult> Function(String viewId, {String? deviceId, CameraFacing? preferredFacing})? mockStartStream;
  static Future<bool> Function(String viewId, {required String targetDeviceId, required CameraFacing facing})? mockSwitchCamera;
  static Future<Uint8List?> Function(String viewId)? mockCaptureFrame;
  static void Function(String viewId)? mockStopStream;
  static Widget Function({required String viewId, required VoidCallback onReady})? mockBuildCameraView;

  static Widget buildCameraView({
    required String viewId,
    required VoidCallback onReady,
  }) {
    if (mockBuildCameraView != null) {
      return mockBuildCameraView!(viewId: viewId, onReady: onReady);
    }
    return const SizedBox();
  }

  static Future<List<CameraDeviceInfo>> getAvailableCameras() async {
    if (mockGetAvailableCameras != null) {
      return await mockGetAvailableCameras!();
    }
    return [];
  }

  static Future<CameraStartResult> startStream(
    String viewId, {
    String? deviceId,
    CameraFacing? preferredFacing,
  }) async {
    if (mockStartStream != null) {
      return await mockStartStream!(viewId, deviceId: deviceId, preferredFacing: preferredFacing);
    }
    return CameraStartResult.failure('Camera is not supported on this platform.');
  }

  static Future<bool> switchCamera(
    String viewId, {
    required String targetDeviceId,
    required CameraFacing facing,
  }) async {
    if (mockSwitchCamera != null) {
      return await mockSwitchCamera!(viewId, targetDeviceId: targetDeviceId, facing: facing);
    }
    return false;
  }

  static Future<Uint8List?> captureFrame(String viewId) async {
    if (mockCaptureFrame != null) {
      return await mockCaptureFrame!(viewId);
    }
    return null;
  }

  static Future<String?> scanQrFromVideo(String viewId) async {
    return null;
  }

  static void stopStream(String viewId) {
    if (mockStopStream != null) {
      mockStopStream!(viewId);
    }
  }

  static void resetMocks() {
    mockIsSupported = null;
    lastSelectedDeviceId = null;
    mockGetAvailableCameras = null;
    mockStartStream = null;
    mockSwitchCamera = null;
    mockCaptureFrame = null;
    mockStopStream = null;
    mockBuildCameraView = null;
  }
}
