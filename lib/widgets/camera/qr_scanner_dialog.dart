import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera_html.dart' as web_cam;

/// Dialog providing live camera QR code scanning for physical 58mm entry receipts.
/// - Android: Uses high-performance native camera QR scanning via [mobile_scanner] with robust multi-device support.
/// - Web: Uses HTML5 live video feed and BarcodeDetector via [WebCameraPlatform].
/// Automatically decodes the QR code from the camera stream and returns the decoded ticket reference.
class QrScannerDialog extends StatefulWidget {
  /// Test hook to simulate scanning a specific QR code in automated tests.
  static String? mockScanResult;

  const QrScannerDialog({super.key});

  /// Displays the QR scanner dialog directly with live camera and returns the decoded ticket reference or null.
  static Future<String?> show(BuildContext context) {
    if (mockScanResult != null) {
      final res = mockScanResult;
      mockScanResult = null;
      return Future.value(res);
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const QrScannerDialog(),
    );
  }

  /// Extracts the ticket number or vehicle registration from any valid parking QR payload format.
  /// Handles JSON payloads, raw ticket numbers, legacy TKT formats, URLs, and key-value pairs.
  static String? extractTicketFromQr(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    // 1. Try parsing as JSON payload
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('ticketNumber') && decoded['ticketNumber'] != null) {
            final val = decoded['ticketNumber'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
          if (decoded.containsKey('ticketId') && decoded['ticketId'] != null) {
            final val = decoded['ticketId'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
          if (decoded.containsKey('qrReference') && decoded['qrReference'] != null) {
            final val = decoded['qrReference'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
          if (decoded.containsKey('ticket') && decoded['ticket'] != null) {
            final val = decoded['ticket'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
          if (decoded.containsKey('id') && decoded['id'] != null) {
            final val = decoded['id'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
          if (decoded.containsKey('vehicleNumber') && decoded['vehicleNumber'] != null) {
            final val = decoded['vehicleNumber'].toString().trim();
            if (val.isNotEmpty) return _cleanTicketValue(val);
          }
        }
      } catch (_) {}
    }

    // 2. Reject non-parking URL / URI schemes
    final lower = clean.toLowerCase();
    if (lower.startsWith('wifi:') ||
        lower.startsWith('begin:vcard') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        lower.startsWith('geo:') ||
        lower.startsWith('upi:')) {
      return null;
    }

    // 3. Try parsing URL query parameters (e.g. ?ticket=1001 or ?tkt=1001)
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        final ticketParam = uri.queryParameters['ticket'] ??
            uri.queryParameters['ticketNumber'] ??
            uri.queryParameters['tkt'] ??
            uri.queryParameters['id'];
        if (ticketParam != null && ticketParam.trim().isNotEmpty) {
          return _cleanTicketValue(ticketParam);
        }
        final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.trim() : '';
        if (lastSeg.isNotEmpty &&
            (AppFormatters.isNumericTicketQuery(lastSeg) || AppFormatters.isLegacyTicketQuery(lastSeg))) {
          return _cleanTicketValue(lastSeg);
        }
      } catch (_) {}
      return null;
    }

    // 4. Key-Value text (e.g., "TICKET:1001" or "TKT: 1004" or "TICKET=1001")
    if (lower.startsWith('ticket:') || lower.startsWith('tkt:') || lower.startsWith('ticket=')) {
      final parts = clean.split(RegExp(r'[:=]'));
      if (parts.length >= 2) {
        final val = parts[1].trim();
        if (val.isNotEmpty) return _cleanTicketValue(val);
      }
    }

    // 5. Direct numeric ticket, legacy ticket, or vehicle registration
    return _cleanTicketValue(clean);
  }

  static String? _cleanTicketValue(String val) {
    final clean = val.trim();
    if (clean.isEmpty) return null;

    // Direct numeric ticket (e.g. 1004)
    if (AppFormatters.isNumericTicketQuery(clean)) {
      return clean;
    }

    // Legacy ticket format (e.g. TKT-1004 or TKT-20260923-4K0D)
    if (AppFormatters.isLegacyTicketQuery(clean)) {
      return clean.toUpperCase();
    }

    // Normalized vehicle registration (e.g. MH12AB1234 or MH 12 AB 1234)
    final normalized = AppFormatters.normalizeVehicleNumber(clean);
    if (normalized.length >= 4 && RegExp(r'^[A-Z0-9\-_]{2,30}$', caseSensitive: false).hasMatch(normalized)) {
      return normalized.toUpperCase();
    }

    // Alphanumeric ticket reference (2-30 characters)
    if (RegExp(r'^[A-Z0-9\-_]{2,30}$', caseSensitive: false).hasMatch(clean)) {
      return clean.toUpperCase();
    }

    return null;
  }

  static bool isValidParkingQr(String raw) {
    final extracted = extractTicketFromQr(raw);
    return extracted != null && extracted.isNotEmpty;
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> with WidgetsBindingObserver {
  // Web specific state
  final String _viewId = 'qr_scanner_${DateTime.now().microsecondsSinceEpoch}';
  bool _isWebCameraActive = false;
  bool _isWebScanning = true;
  String? _webErrorMessage;
  Timer? _webScanTimer;

  // Mobile / Android specific state
  MobileScannerController? _mobileController;
  CameraFacing _currentFacing = CameraFacing.back;
  bool _hasScanned = false;
  bool _isRetrying = false;
  String? _invalidQrMessage;
  Timer? _invalidQrTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _startWebLiveScanner();
    } else {
      _initAndroidScanner();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || _mobileController == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _mobileController?.stop();
    } else if (state == AppLifecycleState.resumed && !_hasScanned) {
      _mobileController?.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invalidQrTimer?.cancel();
    if (kIsWeb) {
      _webScanTimer?.cancel();
      web_cam.WebCameraPlatform.stopStream(_viewId);
    } else {
      _disposeAndroidScanner();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Android Scanner Implementation (mobile_scanner)
  // ---------------------------------------------------------------------------

  void _initAndroidScanner() {
    _mobileController = MobileScannerController(
      facing: _currentFacing,
      lensType: CameraLensType.any,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      autoStart: true,
    );
  }

  Future<void> _disposeAndroidScanner() async {
    final controller = _mobileController;
    _mobileController = null;
    if (controller != null) {
      try {
        await controller.stop();
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _retryAndroidScanner({CameraFacing? fallbackFacing}) async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _hasScanned = false;
      _invalidQrMessage = null;
      if (fallbackFacing != null) {
        _currentFacing = fallbackFacing;
      }
    });

    await _disposeAndroidScanner();

    if (!mounted) return;

    setState(() {
      _initAndroidScanner();
      _isRetrying = false;
    });
  }

  void _handleBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? barcode.displayValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      final extracted = QrScannerDialog.extractTicketFromQr(raw);
      if (extracted == null || extracted.isEmpty) {
        _showInvalidQrWarning();
        return;
      }

      // Valid parking QR code detected
      _hasScanned = true;
      _mobileController?.stop();
      if (mounted) {
        Navigator.pop(context, extracted);
      }
      break;
    }
  }

  void _showInvalidQrWarning() {
    if (!mounted) return;
    setState(() {
      _invalidQrMessage = 'Invalid parking QR. Please scan a valid entry receipt QR.';
    });
    _invalidQrTimer?.cancel();
    _invalidQrTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _invalidQrMessage = null;
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Web Scanner Implementation (WebCameraPlatform)
  // ---------------------------------------------------------------------------

  Future<void> _startWebLiveScanner() async {
    setState(() {
      _isWebCameraActive = false;
      _isWebScanning = true;
      _webErrorMessage = null;
    });

    try {
      final result = await web_cam.WebCameraPlatform.startStream(
        _viewId,
        preferredFacing: web_cam.CameraFacing.rear,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _isWebCameraActive = true;
        });
        _startWebFrameAnalysis();
      } else {
        setState(() {
          _isWebCameraActive = false;
          _isWebScanning = false;
          _webErrorMessage = result.errorMessage ?? 'Camera permission is required to scan QR codes.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWebCameraActive = false;
          _isWebScanning = false;
          _webErrorMessage = 'Unable to start the camera. Please try again.';
        });
      }
    }
  }

  void _startWebFrameAnalysis() {
    _webScanTimer?.cancel();
    _webScanTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      if (!mounted || !_isWebCameraActive) return;

      try {
        final decoded = await web_cam.WebCameraPlatform.scanQrFromVideo(_viewId);
        if (decoded != null && decoded.trim().isNotEmpty) {
          final extracted = QrScannerDialog.extractTicketFromQr(decoded);
          if (extracted == null || extracted.isEmpty) {
            _showInvalidQrWarning();
            return;
          }
          timer.cancel();
          if (mounted) {
            Navigator.pop(context, extracted);
          }
        }
      } catch (_) {}
    });
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Scan Vehicle Entry QR',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Hold physical 58mm entry receipt QR code inside the viewfinder:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // Live Camera Viewfinder Box
              Container(
                height: 290,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (kIsWeb) _buildWebViewfinder() else _buildAndroidViewfinder(),

                    // Viewfinder Reticle Overlay
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary, width: 3),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                            ),
                          ),
                          // Center aiming indicator
                          Container(
                            width: 180,
                            height: 2,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),

                    // Invalid QR warning overlay banner
                    if (_invalidQrMessage != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _invalidQrMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              OutlinedButton(
                key: const ValueKey('qr_scanner_cancel_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel / Close Scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidViewfinder() {
    if (_isRetrying || _mobileController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    return MobileScanner(
      controller: _mobileController!,
      onDetect: _handleBarcodeDetected,
      errorBuilder: (context, error) {
        String message = 'Unable to start the camera. Please try again.';
        if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
          message = 'Camera permission is required to scan QR codes.';
        } else if (error.errorCode == MobileScannerErrorCode.unsupported) {
          message = 'No camera was detected on this device.';
        } else if (error.errorCode == MobileScannerErrorCode.controllerInitializing ||
            error.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized) {
          message = 'Camera is temporarily unavailable. Please retry.';
        } else {
          message = error.errorDetails?.message ?? 'Unable to start the camera. Please try again.';
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 44),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () => _retryAndroidScanner(),
                    ),
                    if (_currentFacing == CameraFacing.back)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.flip_camera_android, size: 16),
                        label: const Text('Try Front Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _retryAndroidScanner(fallbackFacing: CameraFacing.front),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.flip_camera_android, size: 16),
                        label: const Text('Use Rear Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _retryAndroidScanner(fallbackFacing: CameraFacing.back),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebViewfinder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isWebScanning)
          web_cam.WebCameraPlatform.buildCameraView(
            viewId: _viewId,
            onReady: () {},
          ),

        if (!_isWebCameraActive && _webErrorMessage == null)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                SizedBox(height: 12),
                Text(
                  'Starting live camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

        if (_webErrorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    _webErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: _startWebLiveScanner,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
