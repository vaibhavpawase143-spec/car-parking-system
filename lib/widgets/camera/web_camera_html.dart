// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'camera_device_info.dart';

export 'camera_device_info.dart';

/// Web implementation of WebCameraPlatform using standard browser getUserMedia API.
/// Provides reliable camera initialization, front/back switching, device enumeration,
/// and complete resource cleanup.
class WebCameraPlatform {
  static bool get isSupported => html.window.navigator.mediaDevices != null;

  static final Map<String, _CameraSession> _sessions = {};
  static String? lastSelectedDeviceId;

  static Widget buildCameraView({
    required String viewId,
    required VoidCallback onReady,
  }) {
    _getOrCreateSession(viewId);
    return HtmlElementView(viewType: viewId);
  }

  static _CameraSession _getOrCreateSession(String viewId) {
    if (_sessions.containsKey(viewId)) {
      return _sessions[viewId]!;
    }

    final videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(1)';

    videoElement.setAttribute('playsinline', 'true');
    videoElement.setAttribute('webkit-playsinline', 'true');
    videoElement.setAttribute('muted', 'true');

    // Register factory for Flutter HtmlElementView
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => videoElement,
    );

    final session = _CameraSession(viewId: viewId, videoElement: videoElement);
    _sessions[viewId] = session;
    return session;
  }

  /// Internal helper to invoke navigator.mediaDevices.getUserMedia safely.
  static Future<html.MediaStream> _getUserMedia(Map<String, dynamic> constraints) async {
    final nav = html.window.navigator;
    final mediaDevices = nav.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('navigator.mediaDevices is null. Ensure this page is running on localhost or HTTPS.');
    }
    return await mediaDevices.getUserMedia(constraints);
  }

  /// Detects all connected videoinput devices available in the browser.
  static Future<List<CameraDeviceInfo>> getAvailableCameras() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        return [];
      }

      final devices = await mediaDevices.enumerateDevices();
      final videoDevices = <CameraDeviceInfo>[];

      int videoIndex = 0;
      for (final device in devices) {
        final kind = (device.kind ?? '').toString();
        if (kind == 'videoinput') {
          final id = (device.deviceId ?? '').toString();
          final label = (device.label ?? '').toString();
          final facing = _determineCameraFacing(label, videoIndex);

          videoDevices.add(CameraDeviceInfo(
            id: id.isNotEmpty ? id : 'camera-$videoIndex',
            label: label.isNotEmpty ? label : 'Camera ${videoIndex + 1}',
            facing: facing,
          ));
          videoIndex++;
        }
      }

      // If we found exactly 2 cameras and neither had a definitive facing keyword,
      // default convention: index 0 = rear, index 1 = front.
      if (videoDevices.length == 2 &&
          videoDevices[0].facing == CameraFacing.unknown &&
          videoDevices[1].facing == CameraFacing.unknown) {
        videoDevices[0] = CameraDeviceInfo(
          id: videoDevices[0].id,
          label: videoDevices[0].label,
          facing: CameraFacing.rear,
        );
        videoDevices[1] = CameraDeviceInfo(
          id: videoDevices[1].id,
          label: videoDevices[1].label,
          facing: CameraFacing.front,
        );
      }

      debugPrint('[WebCamera] Detected ${videoDevices.length} camera device(s): $videoDevices');
      return videoDevices;
    } catch (e) {
      debugPrint('[WebCamera] enumerateDevices error: $e');
      return [];
    }
  }

  /// Categorize camera as rear, front, or unknown based on device label and index.
  static CameraFacing _determineCameraFacing(String label, int index) {
    final lower = label.toLowerCase();
    if (lower.contains('back') ||
        lower.contains('rear') ||
        lower.contains('environment') ||
        lower.contains('world') ||
        lower.contains('facing back') ||
        lower.contains('camera2 0')) {
      return CameraFacing.rear;
    }
    if (lower.contains('front') ||
        lower.contains('user') ||
        lower.contains('facing front') ||
        lower.contains('selfie') ||
        lower.contains('integrated') ||
        lower.contains('webcam') ||
        lower.contains('camera2 1')) {
      return CameraFacing.front;
    }
    return CameraFacing.unknown;
  }

  /// Starts the camera stream.
  /// Starts with reliable basic constraints (`video: true, audio: false`),
  /// allowing any camera to start and prompt for permissions without constraint mismatch.
  static Future<CameraStartResult> startStream(
    String viewId, {
    String? deviceId,
    CameraFacing? preferredFacing,
  }) async {
    final session = _getOrCreateSession(viewId);
    _stopSessionStream(session);

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        return CameraStartResult.failure(
          'Camera API is not supported in this browser environment.',
          'NotSupported',
        );
      }

      html.MediaStream stream;

      // 1. If explicit deviceId is requested (e.g. from previous session)
      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          stream = await _getUserMedia({
            'video': {
              'deviceId': {'exact': deviceId},
            },
            'audio': false,
          });
          lastSelectedDeviceId = deviceId;
        } catch (devError) {
          debugPrint('[WebCamera] Specific deviceId $deviceId failed ($devError). Falling back to basic constraint.');
          stream = await _getUserMedia({'video': true, 'audio': false});
        }
      } else {
        // 2. Start with reliable basic constraint: video: true, audio: false
        // This ensures the browser prompts for permission and opens any available camera without constraint failure.
        try {
          if (preferredFacing == CameraFacing.rear) {
            try {
              stream = await _getUserMedia({
                'video': {
                  'facingMode': {'ideal': 'environment'},
                },
                'audio': false,
              });
            } catch (_) {
              stream = await _getUserMedia({'video': true, 'audio': false});
            }
          } else {
            stream = await _getUserMedia({'video': true, 'audio': false});
          }
        } catch (_) {
          stream = await _getUserMedia({'video': true, 'audio': false});
        }
      }

      // Verify active video track
      final videoTracks = stream.getVideoTracks();
      if (videoTracks.isEmpty) {
        return CameraStartResult.failure(
          'No video track received from camera device.',
          'NoVideoTrack',
        );
      }

      debugPrint('[WebCamera] Camera stream acquired. Track label: "${videoTracks.first.label}"');

      session.stream = stream;
      session.videoElement.srcObject = stream;
      try {
        await session.videoElement.play();
      } catch (playError) {
        debugPrint('[WebCamera] video.play() note: $playError');
      }

      return CameraStartResult.success();
    } catch (e) {
      final diagnosed = _diagnoseError(e);
      final errorCode = _extractErrorCode(e);
      debugPrint('[WebCamera] startStream error: $e | Diagnosed: $diagnosed');
      return CameraStartResult.failure(diagnosed, errorCode);
    }
  }

  /// Switches active camera to a new device or facing direction.
  /// Immediately stops the previous stream to prevent webcam leaks,
  /// attaches the new stream, and updates the live preview.
  static Future<bool> switchCamera(
    String viewId, {
    required String targetDeviceId,
    required CameraFacing facing,
  }) async {
    final session = _sessions[viewId];
    if (session == null) {
      return false;
    }

    try {
      // 1. Immediately stop previous stream tracks
      _stopSessionStream(session);
      session.videoElement.srcObject = null;

      html.MediaStream stream;

      // 2. Request stream for the target device
      if (targetDeviceId.isNotEmpty) {
        try {
          stream = await _getUserMedia({
            'video': {
              'deviceId': {'exact': targetDeviceId},
            },
            'audio': false,
          });
          lastSelectedDeviceId = targetDeviceId;
        } catch (_) {
          final facingStr = facing == CameraFacing.front ? 'user' : 'environment';
          stream = await _getUserMedia({
            'video': {
              'facingMode': {'ideal': facingStr},
            },
            'audio': false,
          });
        }
      } else {
        final facingStr = facing == CameraFacing.front ? 'user' : 'environment';
        stream = await _getUserMedia({
          'video': {
            'facingMode': {'ideal': facingStr},
          },
          'audio': false,
        });
      }

      // 3. Attach new stream and play
      session.stream = stream;
      session.videoElement.srcObject = stream;
      try {
        await session.videoElement.play();
      } catch (e) {
        debugPrint('[WebCamera] switch play note: $e');
      }
      return true;
    } catch (e) {
      debugPrint('[WebCamera] switchCamera error: $e');
      return false;
    }
  }

  /// Captures current video frame from the active camera stream.
  static Future<Uint8List?> captureFrame(String viewId) async {
    final session = _sessions[viewId];
    if (session == null || session.stream == null) {
      return null;
    }

    final video = session.videoElement;
    final w = video.videoWidth > 0 ? video.videoWidth : 1280;
    final h = video.videoHeight > 0 ? video.videoHeight : 720;

    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex != -1) {
      final base64Str = dataUrl.substring(commaIndex + 1);
      return base64Decode(base64Str);
    }
    return null;
  }

  /// Attempts to decode a QR code from the current video frame of the active session.
  /// Uses browser BarcodeDetector or jsQR.
  static Future<String?> scanQrFromVideo(String viewId) async {
    final session = _sessions[viewId];
    if (session == null || session.stream == null) return null;
    final video = session.videoElement;
    if (video.videoWidth == 0 || video.videoHeight == 0) return null;

    final w = video.videoWidth;
    final h = video.videoHeight;

    try {
      // 1. Try browser native BarcodeDetector if supported
      if (js.context.hasProperty('BarcodeDetector')) {
        try {
          final detectorClass = js.context['BarcodeDetector'] as js.JsFunction?;
          if (detectorClass != null) {
            final detector = js.JsObject(detectorClass, [
              js.JsObject.jsify({'formats': ['qr_code']}),
            ]);
            final barcodes = await (detector.callMethod('detect', [video]) as Future<dynamic>);
            final list = barcodes as List<dynamic>?;
            if (list != null && list.isNotEmpty) {
              final first = list.first;
              final rawValue = (first as dynamic)['rawValue'] as String?;
              if (rawValue != null && rawValue.trim().isNotEmpty) {
                return rawValue.trim();
              }
            }
          }
        } catch (_) {}
      }

      // 2. Try jsQR
      if (js.context.hasProperty('jsQR')) {
        final canvas = html.CanvasElement(width: w, height: h);
        final ctx = canvas.context2D;
        ctx.drawImage(video, 0, 0);
        final imgData = ctx.getImageData(0, 0, w, h);

        final code = js.context.callMethod('jsQR', [
          imgData.data,
          w,
          h,
          js.JsObject.jsify({'inversionAttempts': 'dontInvert'}),
        ]);
        if (code != null) {
          final data = (code as dynamic)['data'] as String?;
          if (data != null && data.trim().isNotEmpty) {
            return data.trim();
          }
        }
      }
    } catch (e) {
      debugPrint('[WebCamera] scanQrFromVideo error: $e');
    }
    return null;
  }

  /// Stops current stream on a session without removing the session object.
  static void _stopSessionStream(_CameraSession session) {
    if (session.stream != null) {
      for (final track in session.stream!.getTracks()) {
        track.stop();
      }
      session.stream = null;
    }
    session.videoElement.srcObject = null;
  }

  /// Stops the stream completely and cleans up all resources.
  static void stopStream(String viewId) {
    final session = _sessions.remove(viewId);
    if (session != null) {
      _stopSessionStream(session);
    }
  }

  /// Diagnoses specific browser error causes into clear user-friendly guidance.
  static String _diagnoseError(dynamic error) {
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('notallowed') ||
        errStr.contains('permission')) {
      return 'Camera permission is required to capture the vehicle photo. Please allow camera access in site settings and retry.';
    }
    if (errStr.contains('notfound') ||
        errStr.contains('devicesnotfound')) {
      return 'No camera device found on this system. Please connect a webcam or enable your camera in device settings.';
    }
    if (errStr.contains('notreadable') ||
        errStr.contains('trackstart')) {
      return 'Camera is in use by another application. Please close other camera apps and retry.';
    }
    if (errStr.contains('overconstrained')) {
      return 'Camera hardware could not satisfy requested settings.';
    }
    if (errStr.contains('security') || errStr.contains('insecure')) {
      return 'Camera access is blocked by browser security policy. Please ensure the app is running on localhost or HTTPS.';
    }
    return 'Camera access failed: ${error.toString().replaceAll('Exception: ', '')}';
  }

  static String? _extractErrorCode(dynamic error) {
    final errStr = error.toString();
    if (errStr.contains(':')) {
      return errStr.split(':').first.trim();
    }
    return null;
  }
}

class _CameraSession {
  final String viewId;
  final html.VideoElement videoElement;
  html.MediaStream? stream;

  _CameraSession({required this.viewId, required this.videoElement});
}
