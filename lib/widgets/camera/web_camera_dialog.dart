import 'dart:async';
import 'dart:typed_data';
import 'package:car_parking_system/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../services/ocr/plate_ocr_service.dart';

import 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera_html.dart';

/// Interactive Live Camera Dialog for Flutter Web.
/// Supports live camera preview, front/back camera switching, frame capture, preview, and selection.
class WebCameraDialog extends StatefulWidget {
  final String? initialCameraId;
  final bool isPlateScanning;
  final Function(String plateNumber, Uint8List photoBytes)? onPlateDetected;

  const WebCameraDialog({
    super.key,
    this.initialCameraId,
    this.isPlateScanning = false,
    this.onPlateDetected,
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    String? initialCameraId,
    bool isPlateScanning = false,
    Function(String plateNumber, Uint8List photoBytes)? onPlateDetected,
  }) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebCameraDialog(
        initialCameraId: initialCameraId,
        isPlateScanning: isPlateScanning,
        onPlateDetected: onPlateDetected,
      ),
    );
  }

  @override
  State<WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<WebCameraDialog> {
  late final String _viewId;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Uint8List? _capturedBytes;
  bool _isCapturing = false;
  bool _isSwitching = false;
  Timer? _liveScanTimer;
  String _liveScanStatus = 'Scanning for plate...';

  List<CameraDeviceInfo> _availableCameras = [];
  CameraDeviceInfo? _currentCamera;

  @override
  void initState() {
    super.initState();
    _viewId = 'camera-preview-${DateTime.now().microsecondsSinceEpoch}';
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final targetId = widget.initialCameraId ?? WebCameraPlatform.lastSelectedDeviceId;

    // Start stream preferring rear camera (or previously selected device)
    final result = await WebCameraPlatform.startStream(
      _viewId,
      deviceId: targetId,
      preferredFacing: CameraFacing.rear,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // Permission is granted, now enumerate available devices
      final cameras = await WebCameraPlatform.getAvailableCameras();

      if (!mounted) return;

      CameraDeviceInfo? activeCamera;
      if (cameras.isNotEmpty) {
        if (targetId != null) {
          activeCamera = cameras.firstWhere(
            (c) => c.id == targetId,
            orElse: () => _pickDefaultRearCamera(cameras),
          );
        } else {
          activeCamera = _pickDefaultRearCamera(cameras);
        }
      }

      setState(() {
        _isLoading = false;
        _hasError = false;
        _availableCameras = cameras;
        _currentCamera = activeCamera;
      });

      if (widget.isPlateScanning) {
        _startLivePlateScanner();
      }
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = result.errorMessage ??
            'Camera permission is required to capture the vehicle photo.';
      });
    }
  }

  void _startLivePlateScanner() {
    if (!widget.isPlateScanning) return;
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!mounted || _isCapturing || _isLoading || _hasError || _capturedBytes != null) return;
      try {
        final frameBytes = await WebCameraPlatform.captureFrame(_viewId);
        if (frameBytes != null && frameBytes.isNotEmpty) {
          final evaluated = await PlateOcrService.recognizePlate(imageBytes: frameBytes);
          if (evaluated.hasPlate && evaluated.isHighConfidence && mounted) {
            _liveScanTimer?.cancel();
            setState(() {
              _liveScanStatus = 'Plate detected: ${evaluated.plateNumber}!';
              _capturedBytes = frameBytes;
            });
            widget.onPlateDetected?.call(evaluated.plateNumber!, frameBytes);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                WebCameraPlatform.stopStream(_viewId);
                Navigator.pop(context, frameBytes);
              }
            });
          }
        }
      } catch (_) {}
    });
  }

  /// Prefers rear camera if available, else first camera in list
  CameraDeviceInfo _pickDefaultRearCamera(List<CameraDeviceInfo> cameras) {
    return cameras.firstWhere(
      (c) => c.isRear,
      orElse: () => cameras.first,
    );
  }

  /// Switches between available cameras (e.g. Rear <-> Front)
  Future<void> _switchCamera() async {
    if (_isSwitching || _availableCameras.length <= 1) return;

    setState(() {
      _isSwitching = true;
    });

    // Determine next camera to switch to
    final currentIndex = _availableCameras.indexWhere((c) => c.id == _currentCamera?.id);
    final nextIndex = currentIndex == -1 ? 0 : (currentIndex + 1) % _availableCameras.length;
    final nextCamera = _availableCameras[nextIndex];

    final success = await WebCameraPlatform.switchCamera(
      _viewId,
      targetDeviceId: nextCamera.id,
      facing: nextCamera.facing,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _currentCamera = nextCamera;
        _isSwitching = false;
      });
    } else {
      setState(() {
        _isSwitching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not switch to ${nextCamera.displayLabel}. Keeping active camera.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _isSwitching) return;

    setState(() {
      _isCapturing = true;
    });

    final bytes = await WebCameraPlatform.captureFrame(_viewId);

    if (!mounted) return;

    if (bytes != null && bytes.isNotEmpty) {
      setState(() {
        _capturedBytes = bytes;
        _isCapturing = false;
      });
    } else {
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture frame from camera. Please try again.')),
      );
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
    });
  }

  void _usePhoto() {
    if (_capturedBytes != null) {
      WebCameraPlatform.stopStream(_viewId);
      Navigator.pop(context, _capturedBytes);
    }
  }

  @override
  void dispose() {
    _liveScanTimer?.cancel();
    WebCameraPlatform.stopStream(_viewId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPreviewing = _capturedBytes != null;
    final hasMultipleCameras = _availableCameras.length > 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPreviewing ? Icons.photo_library_outlined : Icons.videocam_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isPreviewing
                                ? 'Captured Photo Preview'
                                : (widget.isPlateScanning
                                    ? 'Number Plate Scanner (Live OCR)'
                                    : 'Live Vehicle Camera'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isPreviewing && _currentCamera != null) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _currentCamera!.isRear ? Icons.camera_rear : Icons.camera_front,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _currentCamera!.displayLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPreviewing
                              ? AppColors.success.withValues(alpha: 0.12)
                              : (_isLoading
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPreviewing
                              ? '✓ Captured'
                              : (_isLoading
                                  ? 'Connecting...'
                                  : (_isSwitching ? 'Switching...' : '● Live Stream')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPreviewing
                                ? AppColors.success
                                : (_isLoading
                                    ? Colors.orange
                                    : (_isSwitching ? Colors.orange : AppColors.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Camera View / Captured Preview / Error Area
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPreviewing ? AppColors.success : AppColors.borderDark,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isLoading)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Requesting browser camera access...',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else if (_hasError)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_outlined, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _initCamera,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry Camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (isPreviewing)
                        Image.memory(
                          _capturedBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          ),
                        )
                      else
                        WebCameraPlatform.buildCameraView(
                          viewId: _viewId,
                          onReady: () {},
                        ),

                      // Overlay switching indicator
                      if (_isSwitching)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Switching camera...',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Overlay target guidelines when streaming live
                      if (!_isLoading && !_hasError && !isPreviewing)
                        Center(
                          child: Container(
                            width: 260,
                            height: 160,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white38, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  widget.isPlateScanning
                                      ? 'Align Number Plate in Frame'
                                      : 'Align Vehicle / Plate in Frame',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Overlay Switch Camera Control (Top Right)
                      if (!_isLoading && !_hasError && !isPreviewing && hasMultipleCameras)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Tooltip(
                            message: 'Switch Camera',
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                key: const ValueKey('switch_camera_overlay_button'),
                                onTap: _isSwitching ? null : _switchCamera,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.flip_camera_ios,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentCamera?.isRear == true
                                            ? 'Switch to Front'
                                            : 'Switch to Rear',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Controls
              if (isPreviewing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _retake,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retake'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _usePhoto,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Use Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          WebCameraPlatform.stopStream(_viewId);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),

                    // Switch Camera Control (Bottom Bar) - visible when multiple cameras exist
                    if (hasMultipleCameras) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: 'Switch Camera',
                          child: OutlinedButton.icon(
                            key: const ValueKey('switch_camera_button'),
                            onPressed: (_isLoading || _hasError || _isSwitching)
                                ? null
                                : _switchCamera,
                            icon: const Icon(Icons.flip_camera_ios, size: 16),
                            label: const Text('Switch Camera', overflow: TextOverflow.ellipsis),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 12),

                    if (!widget.isPlateScanning)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          key: const ValueKey('capture_photo_button'),
                          onPressed: (_isLoading || _hasError || _isCapturing || _isSwitching)
                              ? null
                              : _capturePhoto,
                          icon: _isCapturing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.camera_alt, size: 18),
                          label: Text(_isCapturing ? 'Capturing...' : 'Capture Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _liveScanStatus,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
