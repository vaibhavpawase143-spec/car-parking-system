import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/ocr/live_camera_ocr_service.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/shift_model.dart';
import '../../../models/system_settings_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/monthly_pass_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/ocr/plate_ocr_service.dart';
import '../../../services/parking_service.dart';
import '../../../services/plate_scanner_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/camera/web_camera_dialog.dart';
import '../../../widgets/camera/web_camera_stub.dart'
    if (dart.library.html) '../../../widgets/camera/web_camera_html.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/status_badge.dart';
import 'entry_success_screen.dart';

/// Validates and normalizes an Indian mobile number.
bool _isValidCustomerMobile(String? value) => AppFormatters.isValidCustomerMobile(value);

/// VehicleEntryScreen provides a responsive, horizontal split layout for vehicle entry:
/// - Left Half: Live camera preview with visible horizontal number plate framing guide,
///   permission handling, QR & OCR scanning status, frame debounce, and auto-captured plate photo.
/// - Right Half: Vehicle entry form with mandatory plate confirmation, vehicle category selector,
///   optional vehicle photo, customer mobile, advance payment, and trusted save logic.
/// On narrow portrait screens, it smoothly adapts to a compact stacked arrangement.
class VehicleEntryScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final VoidCallback onViewActiveParking;

  /// Test hooks for widget & unit testing
  static PlateScanResult? mockScanResult;
  static bool mockCameraPermissionDenied = false;
  static Uint8List? mockCapturedPhoto;
  static String? mockContinuousPlateCandidate;
  static int mockContinuousFrameCount = 2;
  static LiveCameraOcrService? mockLiveOcrService;
  static bool? mockIsWeb;

  static bool enableAnimationInTest = false;

  static void resetTestMocks() {
    mockScanResult = null;
    mockCameraPermissionDenied = false;
    mockCapturedPhoto = null;
    mockContinuousPlateCandidate = null;
    mockContinuousFrameCount = 2;
    mockLiveOcrService = null;
    mockIsWeb = null;
    enableAnimationInTest = false;
    LiveCameraOcrService.resetMocks();
  }

  const VehicleEntryScreen({
    super.key,
    required this.currentGuard,
    required this.onReturnDashboard,
    required this.onViewActiveParking,
  });

  @override
  State<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends State<VehicleEntryScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _mobileController = TextEditingController();
  final _advanceController = TextEditingController();

  final _parkingService = ParkingService();
  final _shiftService = ShiftService();
  final _notificationService = NotificationService();
  final _settingsService = SettingsService.instance;
  final _imagePicker = ImagePicker();
  final _monthlyPassService = MonthlyPassService.instance;
  StreamSubscription<SystemSettingsModel>? _settingsSubscription;

  // Camera & Live Continuous OCR State
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  late final LiveCameraOcrService _liveOcrService =
      VehicleEntryScreen.mockLiveOcrService ?? LiveCameraOcrService();
  bool _isCameraPermissionDenied = false;
  bool _isTorchOn = false;
  bool _isProcessingFrame = false;
  DateTime _lastFrameProcessedTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Web Camera State
  late final String _webCameraViewId = 'vehicle-entry-webcam-${DateTime.now().microsecondsSinceEpoch}';
  bool _isWebCameraLoading = false;
  bool _isWebCameraActive = false;
  bool _isWebCameraNoDevice = false;
  bool _isWebCameraInitFailed = false;
  String _webCameraErrorMessage = '';
  List<CameraDeviceInfo> _webAvailableCameras = [];
  CameraDeviceInfo? _webCurrentCamera;
  Timer? _webLiveScanTimer;

  bool get _isWeb => VehicleEntryScreen.mockIsWeb ?? kIsWeb;

  // Scanning & Detection State
  String? _detectedQrPlate;
  String? _detectedOcrPlate;
  double _detectionConfidence = 1.0;
  bool _hasConflict = false;
  bool _isPlateConfirmed = false;
  bool _isScanningActive = true;
  String? _scannerStatusMessage;

  // QR Scanner-style Animated Horizontal Scanning Laser Line
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;

  @visibleForTesting
  AnimationController get scanLineController => _scanLineController;

  // Frame Debounce to prevent repeatedly processing the same plate on consecutive frames
  String? _lastDebouncedPlate;
  DateTime? _lastDebounceTime;

  // Photos
  Uint8List? _platePhotoBytes;
  Uint8List? _vehiclePhotoBytes;

  // Form selections & inputs
  VehicleType _selectedType = VehicleType.fourWheeler;
  bool _takeAdvance = false;
  String _advancePaymentMethod = 'cash'; // 'cash' or 'upi'

  // Async & validation state
  bool _isLoading = false;
  int _availableCapacity = 100;
  bool _isCheckingCapacity = false;
  String? _errorMessage;

  // Monthly Pass State
  Timer? _passCheckDebounce;
  VehiclePassCheckResult? _passCheckResult;
  bool _isCheckingPass = false;

  void _updateScanLineAnimation() {
    if (!mounted) return;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final shouldRun = !isTest || VehicleEntryScreen.enableAnimationInTest;

    final isCameraActive = _isWeb
        ? _isWebCameraActive
        : ((_cameraController != null && _cameraController!.value.isInitialized) ||
            VehicleEntryScreen.mockContinuousPlateCandidate != null ||
            VehicleEntryScreen.mockScanResult != null);

    final shouldAnimate = _isScanningActive &&
        !_isPlateConfirmed &&
        !_isCameraPermissionDenied &&
        isCameraActive;

    if (shouldAnimate) {
      if (shouldRun && !_scanLineController.isAnimating) {
        _scanLineController.repeat(reverse: true);
      }
    } else {
      if (_scanLineController.isAnimating) {
        _scanLineController.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _scanLineController.value = 0.5;

    WidgetsBinding.instance.addObserver(this);
    _checkCapacity();
    _vehicleNumberController.addListener(_onVehicleNumberChanged);
    _initScanner();
    _updateScanLineAnimation();
    _settingsSubscription = _settingsService.watchSettings().listen((updated) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isWeb) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      _updateScanLineAnimation();
    } else if (state == AppLifecycleState.resumed && _isScanningActive) {
      if (!controller.value.isStreamingImages) {
        _startImageStream();
      }
      _updateScanLineAnimation();
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.cancel();
    _passCheckDebounce?.cancel();
    _vehicleNumberController.removeListener(_onVehicleNumberChanged);
    _vehicleNumberController.dispose();
    _mobileController.dispose();
    _advanceController.dispose();
    _disposeScanner();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera & Live Continuous OCR Controller
  // ---------------------------------------------------------------------------

  void _initScanner() {
    _initScannerAsync();
  }

  Future<void> _initScannerAsync() async {
    if (VehicleEntryScreen.mockCameraPermissionDenied || PlateScannerService.mockPermissionDenied) {
      if (mounted) {
        setState(() {
          _isCameraPermissionDenied = true;
          _isWebCameraLoading = false;
          _isWebCameraActive = false;
          _scannerStatusMessage = AppStrings.cameraPermissionDeniedTitle;
        });
      }
      return;
    }

    if (VehicleEntryScreen.mockScanResult != null) {
      final mock = VehicleEntryScreen.mockScanResult!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyScanResult(mock);
      });
      return;
    }

    if (VehicleEntryScreen.mockContinuousPlateCandidate != null) {
      final candidate = VehicleEntryScreen.mockContinuousPlateCandidate!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (int i = 0; i < VehicleEntryScreen.mockContinuousFrameCount; i++) {
          final stable = _liveOcrService.stabilityTracker.addCandidate(candidate);
          if (stable != null) {
            _handleLivePlateDetected(stable, 0.95);
            break;
          }
        }
      });
      return;
    }

    if (_isWeb) {
      await _initWebCamera();
      return;
    }

    try {
      await _liveOcrService.initialize();
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraPermissionDenied = false;
            _scannerStatusMessage = 'No camera hardware found.';
          });
        }
        return;
      }

      await _initCameraControllerOnly();
      if (mounted) {
        setState(() {
          _isCameraPermissionDenied = false;
        });
      }
    } catch (e) {
      debugPrint('[VehicleEntry] Camera initialization notice: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('permission') || errStr.contains('denied')) {
          setState(() {
            _isCameraPermissionDenied = true;
          });
        } else {
          setState(() {
            _scannerStatusMessage = 'Camera hardware not available';
          });
        }
      }
    }
  }

  Future<void> _initWebCamera() async {
    if (!mounted) return;
    setState(() {
      _isWebCameraLoading = true;
      _isWebCameraActive = false;
      _isCameraPermissionDenied = false;
      _isWebCameraNoDevice = false;
      _isWebCameraInitFailed = false;
      _webCameraErrorMessage = '';
      _scannerStatusMessage = 'Requesting camera permission...';
    });

    try {
      final targetId = WebCameraPlatform.lastSelectedDeviceId;
      final result = await WebCameraPlatform.startStream(
        _webCameraViewId,
        deviceId: targetId,
        preferredFacing: CameraFacing.rear,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final cameras = await WebCameraPlatform.getAvailableCameras();
        if (!mounted) return;

        if (cameras.isEmpty) {
          setState(() {
            _isWebCameraLoading = false;
            _isWebCameraActive = false;
            _isWebCameraNoDevice = true;
            _scannerStatusMessage = 'No camera hardware found on this device.';
          });
          return;
        }

        CameraDeviceInfo? activeCamera;
        if (targetId != null) {
          activeCamera = cameras.firstWhere(
            (c) => c.id == targetId,
            orElse: () => cameras.first,
          );
        } else {
          activeCamera = cameras.first;
        }

        setState(() {
          _isWebCameraLoading = false;
          _isWebCameraActive = true;
          _isWebCameraNoDevice = false;
          _isWebCameraInitFailed = false;
          _isCameraPermissionDenied = false;
          _webAvailableCameras = cameras;
          _webCurrentCamera = activeCamera;
          _scannerStatusMessage = null;
        });

        _startWebLivePlateScanner();
      } else {
        final errCode = result.errorCode ?? '';
        final errMsg = result.errorMessage ?? 'Camera initialization failed.';
        final isDenied = errCode == 'NotAllowedError' ||
            errMsg.toLowerCase().contains('denied') ||
            errMsg.toLowerCase().contains('permission');
        final isNotFound = errCode == 'NotFoundError' ||
            errCode == 'NoVideoTrack' ||
            errMsg.toLowerCase().contains('not found') ||
            errMsg.toLowerCase().contains('no camera');

        setState(() {
          _isWebCameraLoading = false;
          _isWebCameraActive = false;
          if (isDenied) {
            _isCameraPermissionDenied = true;
            _scannerStatusMessage = AppStrings.cameraPermissionDeniedTitle;
          } else if (isNotFound) {
            _isWebCameraNoDevice = true;
            _scannerStatusMessage = 'No camera hardware found on this device.';
          } else {
            _isWebCameraInitFailed = true;
            _webCameraErrorMessage = errMsg;
            _scannerStatusMessage = 'Camera initialization failed: $errMsg';
          }
        });
      }
    } catch (e) {
      debugPrint('[VehicleEntry WebCamera] Initialization error: $e');
      if (mounted) {
        setState(() {
          _isWebCameraLoading = false;
          _isWebCameraActive = false;
          _isWebCameraInitFailed = true;
          _webCameraErrorMessage = e.toString();
          _scannerStatusMessage = 'Camera initialization failed';
        });
      }
    }
  }

  void _startWebLivePlateScanner() {
    _webLiveScanTimer?.cancel();
    if (kDebugMode) {
      debugPrint('[VehicleEntry WebOCR] Starting periodic web live plate scanner...');
    }

    _webLiveScanTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (!mounted || !_isWebCameraActive || _isCameraPermissionDenied || _isPlateConfirmed) {
        return;
      }
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        // 1. Scan QR from active web video stream
        final qrCode = await WebCameraPlatform.scanQrFromVideo(_webCameraViewId);
        if (qrCode != null && qrCode.isNotEmpty && mounted) {
          if (kDebugMode) {
            debugPrint('[VehicleEntry WebOCR] QR code detected: $qrCode');
          }
          _handleBarcodeCaptureFromLive(PlateScanResult(
            plateNumber: qrCode,
            confidence: 1.0,
            isQr: true,
          ));
          return;
        }

        // 2. Capture video frame cropped to framing guide ROI
        final frameBytes = await WebCameraPlatform.captureFrame(
          _webCameraViewId,
          cropToFramingGuide: true,
        );
        if (frameBytes == null || frameBytes.isEmpty) {
          if (kDebugMode) {
            debugPrint('[VehicleEntry WebOCR] Frame capture returned empty/video not ready.');
          }
          return;
        }

        if (kDebugMode) {
          debugPrint('[VehicleEntry WebOCR] Frame captured (${frameBytes.length} bytes). Invoking PlateOcrService...');
        }

        if (mounted && _detectedOcrPlate == null && !_liveOcrService.stabilityTracker.hasPendingCandidate) {
          if (_scannerStatusMessage != 'Scanning for plate') {
            setState(() {
              _scannerStatusMessage = 'Scanning for plate';
            });
          }
        }

        // 3. Invoke real OCR on frame bytes
        final evaluated = await PlateOcrService.recognizePlate(imageBytes: frameBytes);

        if (!mounted) return;

        // Diagnostic log in DevTools console: raw text, candidate, and error
        debugPrint('[VehicleEntry WebOCR] OCR raw text: "${evaluated.rawData}" | Error: "${evaluated.errorMessage}"');

        // If raw text was recognized
        if (evaluated.rawData != null && evaluated.rawData!.trim().isNotEmpty) {
          if (mounted && _detectedOcrPlate == null && !_liveOcrService.stabilityTracker.hasPendingCandidate) {
            setState(() {
              _scannerStatusMessage = evaluated.hasPlate
                  ? 'Validating plate'
                  : AppStrings.plateNotClearReposition;
            });
          }
        }

        if (evaluated.hasPlate && evaluated.confidence >= 0.75) {
          final candidate = evaluated.plateNumber!;
          debugPrint('[VehicleEntry WebOCR] Candidate extracted: $candidate (confidence: ${evaluated.confidence})');

          final stable = _liveOcrService.stabilityTracker.addCandidate(candidate);
          final count = _liveOcrService.stabilityTracker.consecutiveCount;

          debugPrint('[VehicleEntry WebOCR] Stability: candidate=$candidate, count=$count/2, stable=$stable');

          // Candidate locking: require multi-frame consensus before locking onto form
          final shouldLock = stable != null;
          final plateToLock = stable;

          if (shouldLock && plateToLock != null && mounted) {
            debugPrint('[VehicleEntry WebOCR] Plate locked: $plateToLock. Populating vehicle number field.');
            setState(() {
              _scannerStatusMessage = 'Plate detected: $plateToLock';
            });
            _handleLivePlateDetected(plateToLock, evaluated.confidence);
            if (_platePhotoBytes == null) {
              setState(() {
                _platePhotoBytes = frameBytes;
              });
            }
          } else if (mounted && _detectedOcrPlate == null) {
            setState(() {
              _scannerStatusMessage = _liveOcrService.stabilityTracker.hasPendingCandidate
                  ? AppStrings.verifyingStability
                  : 'Validating plate';
            });
          }
        } else {
          _liveOcrService.stabilityTracker.registerEmptyFrame();
          if (mounted && _detectedOcrPlate == null) {
            setState(() {
              if (evaluated.rawData != null && evaluated.rawData!.trim().isNotEmpty) {
                _scannerStatusMessage = AppStrings.plateNotClearReposition;
              } else {
                _scannerStatusMessage = 'Scanning for plate';
              }
            });
          }
          if (evaluated.errorMessage != null) {
            debugPrint('[VehicleEntry WebOCR] Plate rejected: ${evaluated.errorMessage}');
          }
        }
      } catch (e) {
        debugPrint('[VehicleEntry WebOCR] Frame evaluation error: $e');
        if (mounted) {
          setState(() {
            _scannerStatusMessage = 'Camera / OCR Error: $e';
          });
        }
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _initCameraControllerOnly() async {
    if (_availableCameras.isEmpty) return;
    try {
      final camera = _availableCameras[_selectedCameraIndex];
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      await _startImageStream();
    } catch (e) {
      debugPrint('[VehicleEntry] Controller init error: $e');
    }
  }

  Future<void> _startImageStream() async {
    if (_isWeb) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      await controller.startImageStream((CameraImage image) {
        _processLiveCameraFrame(image);
      });
    } catch (e) {
      debugPrint('[VehicleEntry] startImageStream error: $e');
    }
  }

  Future<void> _disposeCameraControllerOnly() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _disposeScanner() async {
    _webLiveScanTimer?.cancel();
    _webLiveScanTimer = null;
    if (_isWeb) {
      WebCameraPlatform.stopStream(_webCameraViewId);
    } else {
      await _disposeCameraControllerOnly();
      await _liveOcrService.dispose();
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        final newTorch = !_isTorchOn;
        await controller.setFlashMode(newTorch ? FlashMode.torch : FlashMode.off);
        if (mounted) {
          setState(() {
            _isTorchOn = newTorch;
          });
        }
      } catch (e) {
        debugPrint('[VehicleEntry] Torch error: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_isWeb) {
      if (_webAvailableCameras.length < 2) return;
      final currentIndex = _webAvailableCameras.indexWhere((c) => c.id == _webCurrentCamera?.id);
      final nextIndex = (currentIndex + 1) % _webAvailableCameras.length;
      final nextCamera = _webAvailableCameras[nextIndex];

      final success = await WebCameraPlatform.switchCamera(
        _webCameraViewId,
        targetDeviceId: nextCamera.id,
        facing: nextCamera.facing,
      );
      if (success && mounted) {
        setState(() {
          _webCurrentCamera = nextCamera;
        });
      }
      return;
    }

    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _disposeCameraControllerOnly();
    await _initCameraControllerOnly();
    if (mounted) {
      setState(() {});
    }
  }

  void _retryCameraPermission() {
    VehicleEntryScreen.mockCameraPermissionDenied = false;
    PlateScannerService.mockPermissionDenied = false;
    setState(() {
      _isCameraPermissionDenied = false;
      _isWebCameraInitFailed = false;
      _isWebCameraNoDevice = false;
      _errorMessage = null;
    });
    _disposeScanner().then((_) => _initScanner());
  }

  // ---------------------------------------------------------------------------
  // Continuous Live Frame OCR and QR Analysis
  // ---------------------------------------------------------------------------

  Future<void> _processLiveCameraFrame(CameraImage image) async {
    if (!_isScanningActive || _isProcessingFrame || !mounted) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    // Rate limiter: skip frames arriving faster than 300ms (~3.3 fps)
    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedTime).inMilliseconds < 300) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameProcessedTime = now;

    try {
      final camera = controller.description;
      final orientation = controller.value.deviceOrientation;

      if (kDebugMode) {
        debugPrint('[VehicleEntry] Sending camera frame to LiveCameraOcrService...');
      }

      await _liveOcrService.processCameraImage(
        cameraImage: image,
        cameraDescription: camera,
        deviceOrientation: orientation,
        onPlateDetected: (plate, confidence) {
          if (mounted) {
            _handleLivePlateDetected(plate, confidence);
          }
        },
        onQrDetected: (qrResult) {
          if (mounted) {
            _handleBarcodeCaptureFromLive(qrResult);
          }
        },
        onStatusUpdate: (status) {
          if (mounted && _scannerStatusMessage != status) {
            setState(() {
              _scannerStatusMessage = status;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('[VehicleEntry] Live frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleLivePlateDetected(String plate, double confidence) {
    if (!mounted) return;

    final normalized = AppFormatters.normalizeVehicleNumber(plate);
    if (!AppFormatters.isValidVehicleNumber(normalized)) return;

    final isDifferentPlate = _detectedOcrPlate != normalized;

    // Frame Debounce: ignore identical plate within 2.5 seconds
    final now = DateTime.now();
    if (!isDifferentPlate &&
        _lastDebouncedPlate == normalized &&
        _lastDebounceTime != null &&
        now.difference(_lastDebounceTime!) < const Duration(milliseconds: 2500)) {
      return;
    }

    _lastDebouncedPlate = normalized;
    _lastDebounceTime = now;

    setState(() {
      _detectedOcrPlate = normalized;
      _detectionConfidence = confidence;

      // Populate text field automatically
      _vehicleNumberController.text = normalized;

      // If a different plate was scanned or first detection, reset confirmation!
      if (isDifferentPlate) {
        _isPlateConfirmed = false;
      }

      // Check conflict between QR and OCR
      _hasConflict = PlateScannerService.hasConflict(_detectedQrPlate, _detectedOcrPlate);

      _errorMessage = null;
      _scannerStatusMessage = null;
    });

    _checkCapacity();
  }

  void _handleBarcodeCaptureFromLive(PlateScanResult qrResult) {
    if (!_isScanningActive || !mounted) return;
    final plate = qrResult.plateNumber;
    if (plate == null || plate.trim().isEmpty) return;

    final normalized = AppFormatters.normalizeVehicleNumber(plate);

    final now = DateTime.now();
    if (_lastDebouncedPlate == normalized &&
        _lastDebounceTime != null &&
        now.difference(_lastDebounceTime!) < const Duration(milliseconds: 2500)) {
      return;
    }

    _lastDebouncedPlate = normalized;
    _lastDebounceTime = now;

    _applyScanResult(qrResult);
  }

  @visibleForTesting
  void simulateLiveCandidate(String candidate, {double confidence = 0.95}) {
    final stable = _liveOcrService.stabilityTracker.addCandidate(candidate);
    if (stable != null) {
      _handleLivePlateDetected(stable, confidence);
    }
  }

  @visibleForTesting
  LiveCameraOcrService get liveOcrService => _liveOcrService;

  @visibleForTesting
  bool get isPlateConfirmed => _isPlateConfirmed;

  @visibleForTesting
  bool get hasConflict => _hasConflict;

  /// Evaluates and applies a QR or OCR scan result.
  void _applyScanResult(PlateScanResult result) {
    if (!mounted) return;

    final plate = result.plateNumber;
    if (plate == null || plate.trim().isEmpty) {
      if (result.errorMessage != null) {
        setState(() {
          _scannerStatusMessage = result.errorMessage;
        });
      }
      return;
    }

    final normalized = AppFormatters.normalizeVehicleNumber(plate);

    setState(() {
      if (result.isQr) {
        _detectedQrPlate = normalized;
      } else if (result.isOcr) {
        _detectedOcrPlate = normalized;
      }

      _detectionConfidence = result.confidence;

      // Check conflict between QR and OCR
      _hasConflict = PlateScannerService.hasConflict(_detectedQrPlate, _detectedOcrPlate);

      // Populate text field
      _vehicleNumberController.text = normalized;

      // Reset confirmation whenever a new plate is detected
      _isPlateConfirmed = false;

      // Automatically assign vehicle type ONLY if present in QR data
      if (result.vehicleType != null) {
        _selectedType = result.vehicleType!;
      }

      // Auto-capture plate photo if genuine frame bytes are available or mock photo is set
      if (result.photoBytes != null &&
          result.photoBytes!.isNotEmpty &&
          !PlateScannerService.isPlaceholder(result.photoBytes)) {
        _platePhotoBytes = result.photoBytes;
      } else if (VehicleEntryScreen.mockCapturedPhoto != null &&
          !PlateScannerService.isPlaceholder(VehicleEntryScreen.mockCapturedPhoto)) {
        _platePhotoBytes = VehicleEntryScreen.mockCapturedPhoto;
      } else {
        _platePhotoBytes = null;
      }

      _errorMessage = null;
    });

    _checkCapacity();
  }

  /// Triggers genuine on-device OCR evaluation using actual camera images.
  /// Never uses mock text or the existing text field as the OCR source.
  @visibleForTesting
  Future<void> triggerOcrCapture({String? simulatedOcrText, double? simulatedConfidence}) async {
    if (simulatedOcrText != null) {
      final conf = simulatedConfidence ?? 0.94;
      final result = PlateScannerService.evaluateOcr(
        detectedText: simulatedOcrText,
        photoBytes: _platePhotoBytes,
        defaultConfidence: conf,
      );
      if (result.isHighConfidence && result.hasPlate) {
        _applyScanResult(result);
      } else {
        setState(() {
          _detectionConfidence = result.confidence;
          _errorMessage = AppStrings.lowConfidenceWarning;
        });
      }
      return;
    }

    if (PlateOcrService.mockOcrResult != null) {
      _applyScanResult(PlateOcrService.mockOcrResult!);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List? photoBytes;
      String? photoPath;

      if (_isWeb) {
        final captured = await WebCameraDialog.show(context);
        if (captured == null || captured.isEmpty) {
          return;
        }
        photoBytes = captured;
      } else {
        final pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: 1920,
          maxHeight: 1440,
          imageQuality: 85,
        );
        if (pickedFile == null) {
          return;
        }
        photoPath = pickedFile.path;
        photoBytes = await pickedFile.readAsBytes();
      }

      if (photoBytes.isEmpty) {
        return;
      }

      // Real camera photo captured: store it immediately as plate photo!
      setState(() {
        _platePhotoBytes = photoBytes;
      });

      // Run genuine on-device ML Kit OCR on the captured image
      final result = await PlateOcrService.recognizePlate(
        imagePath: photoPath,
        imageBytes: photoBytes,
      );

      if (result.hasPlate && result.isHighConfidence) {
        _applyScanResult(result);
      } else {
        setState(() {
          _detectionConfidence = result.confidence;
          _errorMessage = result.errorMessage ?? AppStrings.lowConfidenceWarning;
          _scannerStatusMessage = result.errorMessage;
        });
      }
    } catch (e) {
      debugPrint('[VehicleEntry] OCR capture error: $e');
      setState(() {
        _errorMessage = 'OCR capture failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Vehicle Number Listener & Monthly Pass Check
  // ---------------------------------------------------------------------------

  void _onVehicleNumberChanged() {
    _passCheckDebounce?.cancel();
    final text = _vehicleNumberController.text.trim();
    final normalized = AppFormatters.normalizeVehicleNumber(text);

    // Any edit to the plate field invalidates previous confirmation
    if (_isPlateConfirmed) {
      setState(() {
        _isPlateConfirmed = false;
      });
    }

    if (_passCheckResult != null) {
      setState(() {
        _passCheckResult = null;
      });
    }

    if (normalized.length < 4) {
      return;
    }

    _passCheckDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isCheckingPass = true;
      });
      try {
        final result = await _monthlyPassService.checkVehiclePass(normalized);
        if (mounted) {
          final wasValid = _passCheckResult?.hasValidPass == true;
          setState(() {
            _passCheckResult = result;
            _isCheckingPass = false;
            if (result.hasValidPass) {
              _takeAdvance = false;
              _advanceController.clear();
              _selectedType = result.validPass!.vehicleType;
            }
          });
          if (result.hasValidPass || wasValid) {
            _checkCapacity();
          }
        }
      } catch (e) {
        debugPrint('[VehicleEntry] Pass check error: $e');
        if (mounted) {
          setState(() {
            _isCheckingPass = false;
          });
        }
      }
    });
  }

  void _confirmPlateNumber() {
    final raw = _vehicleNumberController.text.trim();
    final normalized = AppFormatters.normalizeVehicleNumber(raw);

    if (normalized.isEmpty) {
      final settings = _settingsService.currentSettings;
      if (settings.requireNumberPlate) {
        setState(() {
          _errorMessage = AppStrings.vehicleNumberRequired;
        });
        return;
      }
      setState(() {
        _isPlateConfirmed = true;
        _errorMessage = null;
      });
      return;
    }

    if (!AppFormatters.isValidVehicleNumber(normalized)) {
      setState(() {
        _errorMessage = AppStrings.invalidVehicleNumber;
      });
      return;
    }

    setState(() {
      _vehicleNumberController.text = normalized;
      _isPlateConfirmed = true;
      _hasConflict = false;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();
  }

  void _resolveConflict(String selectedValue) {
    setState(() {
      _vehicleNumberController.text = selectedValue;
      _hasConflict = false;
      _isPlateConfirmed = true;
      _errorMessage = null;
    });
  }

  void _clearForm() {
    _passCheckDebounce?.cancel();
    _vehicleNumberController.clear();
    _mobileController.clear();
    _advanceController.clear();
    setState(() {
      _platePhotoBytes = null;
      _vehiclePhotoBytes = null;
      _takeAdvance = false;
      _passCheckResult = null;
      _isCheckingPass = false;
      _errorMessage = null;
      _detectedQrPlate = null;
      _detectedOcrPlate = null;
      _hasConflict = false;
      _isPlateConfirmed = false;
      _lastDebouncedPlate = null;
    });
    _checkCapacity();
  }

  Future<void> _checkCapacity() async {
    setState(() {
      _isCheckingCapacity = true;
    });

    try {
      final available = await _parkingService.getAvailableCapacity(_selectedType);
      if (mounted) {
        setState(() {
          _availableCapacity = available;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingCapacity = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Photo Capture & Retake Helpers
  // ---------------------------------------------------------------------------

  Future<void> _capturePlatePhoto() async {
    if (_isWeb) {
      if (_isWebCameraActive) {
        final captured = await WebCameraPlatform.captureFrame(_webCameraViewId);
        if (captured != null && captured.isNotEmpty) {
          setState(() {
            _platePhotoBytes = captured;
            _errorMessage = null;
          });
          return;
        }
      }
      if (!mounted) return;
      final captured = await WebCameraDialog.show(
        context,
        isPlateScanning: true,
        onPlateDetected: (plate, photo) {
          _handleLivePlateDetected(plate, 0.95);
        },
      );
      if (captured != null && captured.isNotEmpty) {
        setState(() {
          _platePhotoBytes = captured;
          _errorMessage = null;
        });
      }
    } else {
      // On mobile, continuous live scanning runs directly inside the screen camera viewport.
      // Trigger a rescan so guard can align plate in frame.
      _liveOcrService.resetStability();
      setState(() {
        _isScanningActive = true;
        _scannerStatusMessage = AppStrings.scanningForQrAndPlate;
        _errorMessage = null;
      });
      final controller = _cameraController;
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        await _startImageStream();
      }
    }
  }

  Future<void> _captureVehiclePhoto() async {
    if (_isWeb) {
      final captured = await WebCameraDialog.show(context);
      if (captured != null && captured.isNotEmpty) {
        setState(() {
          _vehiclePhotoBytes = captured;
          _errorMessage = null;
        });
      }
    } else {
      await _pickPhoto(ImageSource.camera, isPlatePhoto: false);
    }
  }

  Future<void> _pickPhoto(ImageSource source, {required bool isPlatePhoto}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          if (isPlatePhoto) {
            _platePhotoBytes = bytes;
          } else {
            _vehiclePhotoBytes = bytes;
          }
          _errorMessage = null;
        });

        // If genuine plate photo was captured and plate number is empty, run OCR
        if (isPlatePhoto && _vehicleNumberController.text.trim().isEmpty) {
          try {
            final ocrResult = await PlateOcrService.recognizePlate(
              imagePath: pickedFile.path,
              imageBytes: bytes,
            );
            if (ocrResult.hasPlate && ocrResult.isHighConfidence && mounted) {
              _applyScanResult(ocrResult);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final message = errStr.contains('permission') || errStr.contains('denied')
            ? AppStrings.cameraPermissionRequired
            : '${AppStrings.error}: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Save Entry & Verification Logic
  // ---------------------------------------------------------------------------

  Future<void> _submitEntry() async {
    // 1. Prevent double submission
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final settings = _settingsService.currentSettings;
    final vehicleNumber = AppFormatters.normalizeVehicleNumber(_vehicleNumberController.text);
    final rawMobile = _mobileController.text.trim();
    debugPrint('[VehicleEntry] _submitEntry: requireCustomerMobile=${settings.requireCustomerMobile}, customerMobileVisible=${settings.customerMobileVisible}, rawMobile="$rawMobile"');

    // 2. Validate Vehicle Number requiredness & mandatory confirmation
    if (settings.requireNumberPlate && vehicleNumber.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.vehicleNumberRequired;
      });
      return;
    }

    if (vehicleNumber.isNotEmpty && !AppFormatters.isValidVehicleNumber(vehicleNumber)) {
      setState(() {
        _errorMessage = AppStrings.invalidVehicleNumber;
      });
      return;
    }

    // MANDATORY CONFIRMATION: Guard must confirm the plate number whenever one is provided
    if (vehicleNumber.isNotEmpty && !_isPlateConfirmed) {
      setState(() {
        _errorMessage = AppStrings.plateConfirmationRequired;
      });
      return;
    }

    // Unresolved QR vs OCR mismatch must be resolved before saving
    if (_hasConflict) {
      setState(() {
        _errorMessage = AppStrings.qrOcrConflictDesc;
      });
      return;
    }

    // 3. Customer Mobile validation (based on Admin Settings)
    if (settings.customerMobileVisible) {
      if (settings.requireCustomerMobile) {
        if (!_isValidCustomerMobile(rawMobile)) {
          setState(() {
            _errorMessage = rawMobile.isEmpty ? AppStrings.mobileRequired : AppStrings.invalidMobile;
          });
          return;
        }
      } else if (rawMobile.isNotEmpty && !_isValidCustomerMobile(rawMobile)) {
        setState(() {
          _errorMessage = AppStrings.invalidMobile;
        });
        return;
      }
    }

    // 4. Number Plate Photo is optional: a missing photo does not block vehicle entry.

    // 5. Parking Capacity Check
    if (_availableCapacity <= 0) {
      final fullMsg = _selectedType == VehicleType.twoWheeler
          ? AppStrings.twoWheelerParkingFull
          : AppStrings.fourWheelerParkingFull;
      setState(() {
        _errorMessage = fullMsg;
      });
      return;
    }

    // 6. Advance Payment validation
    double advanceAmount = 0.0;
    if (settings.advanceEnabled && _takeAdvance && _advanceController.text.trim().isNotEmpty) {
      advanceAmount = double.tryParse(_advanceController.text.trim()) ?? 0.0;
      if (advanceAmount <= 0) {
        setState(() {
          _errorMessage = AppStrings.enterAmount;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 7. Active Shift Check (CRITICAL: Guard must have an active assigned shift)
    final activeShift = await _shiftService.getGuardCurrentActiveShift(
      widget.currentGuard.uid,
      widget.currentGuard.email,
      widget.currentGuard.name,
    );
    if (activeShift == null) {
      try {
        await _notificationService.createNotification(
          recipientUserId: widget.currentGuard.uid,
          title: AppStrings.entryBlocked,
          message: AppStrings.noActiveShiftAssignedWarning,
          type: 'entry_blocked',
        );
      } catch (_) {}
      setState(() {
        _isLoading = false;
        _errorMessage = AppStrings.noActiveShiftWarning;
      });
      return;
    }

    try {
      final shiftLabel =
          '${AppFormatters.formatTime(activeShift.startTime)} - ${AppFormatters.formatTime(activeShift.endTime)}';

      _passCheckDebounce?.cancel();
      VehiclePassCheckResult passCheck = _passCheckResult ?? const VehiclePassCheckResult();
      if (_passCheckResult == null && vehicleNumber.length >= 4) {
        try {
          passCheck = await _monthlyPassService.checkVehiclePass(vehicleNumber);
        } catch (_) {}
      }

      final hasValidPass = passCheck.hasValidPass;
      final isTypeMatch = hasValidPass && passCheck.validPass!.vehicleType == _selectedType;
      final isMonthlyPass = isTypeMatch;
      final monthlyPassId = isTypeMatch ? passCheck.validPass?.id : null;

      final record = await _parkingService.createVehicleEntry(
        vehicleNumber: vehicleNumber,
        vehicleType: _selectedType,
        platePhotoBytes: _platePhotoBytes,
        vehiclePhotoBytes: _vehiclePhotoBytes,
        customerMobile: rawMobile,
        guardUid: widget.currentGuard.uid,
        guardName: widget.currentGuard.name,
        guardShift: shiftLabel,
        advanceAmount: isMonthlyPass ? 0.0 : advanceAmount,
        advancePaymentMethod: _advancePaymentMethod,
        isMonthlyPass: isMonthlyPass,
        monthlyPassId: monthlyPassId,
      );

      _clearForm();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntrySuccessScreen(
              record: record,
              onReturnDashboard: () {
                Navigator.pop(context);
                widget.onReturnDashboard();
              },
              onViewActiveParking: () {
                Navigator.pop(context);
                widget.onViewActiveParking();
              },
              onNewEntry: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } on VehicleAlreadyParkedException {
      if (mounted) {
        setState(() {
          _errorMessage = AppStrings.vehicleAlreadyParked;
        });
      }
    } on CapacityFullException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.vehicleType == VehicleType.twoWheeler
              ? AppStrings.twoWheelerParkingFull
              : AppStrings.fourWheelerParkingFull;
        });
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? 'Operation timed out. Please verify network.';
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? e.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppStrings.error}: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods — Responsive Horizontal Split Layout
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          // Horizontal Split: Side-by-side Camera/Scanning & Entry Form
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Half: Camera, Framing Guide, QR/OCR scanning status
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  key: const ValueKey('camera_scanning_section'),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCameraAndScanningSection(compact: false),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
              // Right Half: Entry Form & Save Button
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  key: const ValueKey('entry_form_section'),
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
                  child: _buildEntryFormSection(),
                ),
              ),
            ],
          );
        } else {
          // Compact Portrait: Camera Section stacked above Entry Form
          return SingleChildScrollView(
            key: const ValueKey('portrait_entry_view'),
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCameraAndScanningSection(compact: true),
                const SizedBox(height: 16),
                _buildEntryFormSection(),
              ],
            ),
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT HALF: Camera & Scanning Section
  // ---------------------------------------------------------------------------

  Widget _buildCameraAndScanningSection({required bool compact}) {
    final isScanningVisible = (_detectedQrPlate != null || _detectedOcrPlate != null) ||
        (_isScanningActive &&
            !_isCameraPermissionDenied &&
            (!_isWeb || _isWebCameraActive));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Camera & Scanning with Status Badge
            Row(
              children: [
                const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.cameraScanningTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _buildScanningStatusBadge(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Camera Viewport with Number-Plate Framing Guide
            _buildCameraViewport(height: compact ? 220 : 280),
            const SizedBox(height: 10),

            // Live OCR Scanning Status Banner
            if (isScanningVisible) ...[
              Container(
                key: const ValueKey('live_ocr_status_banner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (_detectedQrPlate != null || _detectedOcrPlate != null)
                      ? AppColors.successLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_detectedQrPlate != null || _detectedOcrPlate != null)
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_detectedQrPlate != null || _detectedOcrPlate != null)
                          ? Icons.check_circle
                          : Icons.radar,
                      size: 16,
                      color: (_detectedQrPlate != null || _detectedOcrPlate != null)
                          ? AppColors.successDark
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scannerStatusMessage ??
                            ((_detectedQrPlate != null || _detectedOcrPlate != null)
                                ? '${AppStrings.plateConfirmed}: ${_detectedOcrPlate ?? _detectedQrPlate}'
                                : AppStrings.scanningForQrAndPlate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (_detectedQrPlate != null || _detectedOcrPlate != null)
                              ? AppColors.successDark
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Camera Controls: Torch, Switch Camera, Rescan
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('toggle_torch_button'),
                  onPressed: (!_isWeb && _cameraController != null && _cameraController!.value.isInitialized)
                      ? _toggleTorch
                      : null,
                  icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, size: 20),
                  tooltip: 'Flash',
                ),
                IconButton.filledTonal(
                  key: const ValueKey('switch_camera_button'),
                  onPressed: (_isWeb
                          ? _webAvailableCameras.length > 1
                          : _availableCameras.length > 1)
                      ? _switchCamera
                      : null,
                  icon: const Icon(Icons.flip_camera_ios, size: 20),
                  tooltip: 'Switch Camera',
                ),
                ElevatedButton.icon(
                  key: const ValueKey('rescan_button'),
                  onPressed: () {
                    _liveOcrService.resetStability();
                    setState(() {
                      _detectedQrPlate = null;
                      _detectedOcrPlate = null;
                      _hasConflict = false;
                      _lastDebouncedPlate = null;
                      _lastDebounceTime = null;
                      _isScanningActive = true;
                      _errorMessage = null;
                      _scannerStatusMessage = null;
                      _isPlateConfirmed = false;
                    });
                    if (_isWeb) {
                      _startWebLivePlateScanner();
                    } else {
                      final controller = _cameraController;
                      if (controller != null &&
                          controller.value.isInitialized &&
                          !controller.value.isStreamingImages) {
                        _startImageStream();
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(AppStrings.rescan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySurface,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Number Plate Photo Preview & Retake
            _buildPlatePhotoPreviewCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningStatusBadge() {
    if (_isCameraPermissionDenied) {
      return StatusBadge(label: AppStrings.cameraPermissionDeniedTitle, type: BadgeType.danger);
    }
    if (_hasConflict) {
      return StatusBadge(label: AppStrings.qrOcrConflictTitle, type: BadgeType.danger);
    }
    if (_detectedQrPlate != null || _detectedOcrPlate != null) {
      if (_detectionConfidence >= 0.75) {
        return StatusBadge(label: AppStrings.plateDetectedHighConfidence, type: BadgeType.active);
      } else {
        return StatusBadge(label: AppStrings.plateDetectedLowConfidence, type: BadgeType.warning);
      }
    }
    if (_isWeb) {
      if (_isWebCameraNoDevice) {
        return const StatusBadge(label: 'No Camera Detected', type: BadgeType.danger);
      }
      if (_isWebCameraInitFailed) {
        return const StatusBadge(label: 'Camera Error', type: BadgeType.danger);
      }
      if (_isWebCameraLoading) {
        return const StatusBadge(label: 'Requesting Camera...', type: BadgeType.warning);
      }
      if (!_isWebCameraActive) {
        return const StatusBadge(label: 'Camera Inactive', type: BadgeType.warning);
      }
    } else {
      if ((_cameraController == null || !_cameraController!.value.isInitialized) &&
          VehicleEntryScreen.mockScanResult == null &&
          VehicleEntryScreen.mockContinuousPlateCandidate == null) {
        return const StatusBadge(label: 'Initializing Camera...', type: BadgeType.warning);
      }
    }
    if (_liveOcrService.stabilityTracker.hasPendingCandidate) {
      return StatusBadge(label: AppStrings.verifyingStability, type: BadgeType.warning);
    }
    if (_scannerStatusMessage != null && _scannerStatusMessage!.isNotEmpty) {
      if (_scannerStatusMessage!.toLowerCase().contains('error') ||
          _scannerStatusMessage!.toLowerCase().contains('failed')) {
        return StatusBadge(label: _scannerStatusMessage!, type: BadgeType.danger);
      }
      return StatusBadge(label: _scannerStatusMessage!, type: BadgeType.info);
    }
    return StatusBadge(label: AppStrings.liveOcrActive, type: BadgeType.info);
  }

  Widget _buildCameraViewport({required double height}) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScanLineAnimation());

    if (_isCameraPermissionDenied) {
      return Container(
        key: const ValueKey('camera_permission_denied_card'),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 40, color: AppColors.dangerDark),
            const SizedBox(height: 10),
            Text(
              AppStrings.cameraPermissionDeniedTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.dangerDark),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.cameraPermissionDeniedDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('retry_permission_button'),
              onPressed: _retryCameraPermission,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(AppStrings.retryPermission),
            ),
          ],
        ),
      );
    }

    if (_isWeb && _isWebCameraNoDevice) {
      return Container(
        key: const ValueKey('web_camera_no_device_card'),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            const Text(
              'No Camera Detected',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'No webcam or camera hardware was found on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('retry_web_camera_button'),
              onPressed: _retryCameraPermission,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Camera'),
            ),
          ],
        ),
      );
    }

    if (_isWeb && _isWebCameraInitFailed) {
      return Container(
        key: const ValueKey('web_camera_init_failed_card'),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.dangerDark),
            const SizedBox(height: 10),
            const Text(
              'Camera Initialization Failed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.dangerDark),
            ),
            const SizedBox(height: 6),
            Text(
              _webCameraErrorMessage.isNotEmpty
                  ? _webCameraErrorMessage
                  : 'Unable to connect to the camera stream.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('retry_web_camera_init_button'),
              onPressed: _retryCameraPermission,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Camera'),
            ),
          ],
        ),
      );
    }

    if (_isWeb && _isWebCameraLoading) {
      return Container(
        key: const ValueKey('web_camera_loading_card'),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryLight),
              SizedBox(height: 12),
              Text(
                'Requesting camera permission...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Please allow camera access in your browser prompt.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    final isMobileInitialized = !_isWeb && controller != null && controller.value.isInitialized;
    final isStreamActive = _isWeb ? _isWebCameraActive : isMobileInitialized;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera Stream Preview
            if (_isWeb && _isWebCameraActive)
              SizedBox.expand(
                key: const ValueKey('web_camera_preview_view'),
                child: WebCameraPlatform.buildCameraView(
                  viewId: _webCameraViewId,
                  onReady: () {
                    if (mounted && !_isWebCameraActive) {
                      setState(() => _isWebCameraActive = true);
                    }
                  },
                ),
              )
            else if (isMobileInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 1,
                    height: controller.value.previewSize?.width ?? 1,
                    child: CameraPreview(controller),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black87,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_outlined, color: Colors.white54, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _scannerStatusMessage ?? AppStrings.scanningForQrAndPlate,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // QR Scanner-Style Responsive Number Plate Framing Guide
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final isCompact = height <= 240;

                // Significantly enlarged inner green detection box:
                // - Approximately 95% of usable camera preview width
                // - Approximately 65–70% of preview height (height * 0.68), centered
                // - Leaves a small margin around preview edges so the box does not touch camera boundary
                final targetWidth = availableWidth * 0.95;
                final frameWidth = targetWidth.clamp(260.0, availableWidth - 12.0);

                final targetHeight = height * 0.68;
                final frameHeight = targetHeight.clamp(120.0, height - 16.0);

                final themeColor = _hasConflict
                    ? AppColors.danger
                    : (_detectedQrPlate != null || _detectedOcrPlate != null
                        ? AppColors.success
                        : AppColors.primary);

                final showScanningAnimation = isStreamActive && _isScanningActive && !_isPlateConfirmed;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Viewfinder Dark Mask Scrim: softly dims outer preview while keeping framing guide clear
                    if (isStreamActive)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ScannerMaskPainter(
                            frameWidth: frameWidth,
                            frameHeight: frameHeight,
                            cornerRadius: 10.0,
                            scrimColor: Colors.black.withValues(alpha: 0.28),
                          ),
                        ),
                      ),

                    // Central Framing Guide
                    SizedBox(
                      key: const ValueKey('number_plate_framing_guide'),
                      width: frameWidth,
                      height: frameHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          clipBehavior: Clip.antiAlias,
                          children: [
                            // 1. Four clear corner brackets around scanning area & guide border
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ScannerCornerPainter(
                                  cornerColor: themeColor,
                                  cornerLength: isCompact ? 32.0 : 40.0,
                                  cornerThickness: 4.0,
                                  cornerRadius: 10.0,
                                  borderAlpha: 0.20,
                                ),
                              ),
                            ),

                            // 2. Translucent viewport background tint within the frame
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                            ),

                            // 3. Smooth animated horizontal scanning line moving vertically
                            if (showScanningAnimation)
                              _buildScanningLaserBeam(
                                frameWidth: frameWidth,
                                frameHeight: frameHeight,
                                color: themeColor,
                              ),

                            // 4. Confirmed status badge overlay when confirmed
                            if (_isPlateConfirmed)
                              _buildPlateConfirmedBadge(),

                            // 5. Framing guide label and real-time detection status
                            Positioned.fill(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Guide Pill
                                  Container(
                                    margin: const EdgeInsets.only(top: 6, left: 10, right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.70),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: themeColor.withValues(alpha: 0.45),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.crop_free,
                                          size: 11,
                                          color: themeColor.withValues(alpha: 0.9),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            AppStrings.numberPlateFramingGuide,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Bottom Status Pill / Result
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6, left: 10, right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.80),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: (_hasConflict
                                                ? AppColors.danger
                                                : (_detectedQrPlate != null || _detectedOcrPlate != null
                                                    ? AppColors.success
                                                    : Colors.white24))
                                            .withValues(alpha: 0.5),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_detectedQrPlate != null || _detectedOcrPlate != null) ...[
                                          const Icon(Icons.check_circle, color: AppColors.successLight, size: 11),
                                          const SizedBox(width: 4),
                                        ] else if (showScanningAnimation) ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: themeColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: themeColor.withValues(alpha: 0.8),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                        ],
                                        Flexible(
                                          child: Text(
                                            _hasConflict
                                                ? 'Plate Conflict Detected'
                                                : (_detectedQrPlate != null || _detectedOcrPlate != null
                                                    ? 'Plate detected: ${_detectedOcrPlate ?? _detectedQrPlate}'
                                                    : (_scannerStatusMessage != null && _scannerStatusMessage!.isNotEmpty
                                                        ? _scannerStatusMessage!
                                                        : (isStreamActive ? 'Align Plate / QR' : 'Waiting for Camera...'))),
                                            style: TextStyle(
                                              color: _hasConflict
                                                  ? AppColors.dangerLight
                                                  : (_detectedQrPlate != null || _detectedOcrPlate != null
                                                      ? AppColors.successLight
                                                      : Colors.white70),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningLaserBeam({
    required double frameWidth,
    required double frameHeight,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _scanLineAnimation,
      builder: (context, child) {
        final minY = 6.0;
        final maxY = (frameHeight - 24.0).clamp(minY, frameHeight);
        final currentY = minY + (_scanLineAnimation.value * (maxY - minY));

        return Positioned(
          key: const ValueKey('scanner_animated_scan_line'),
          top: currentY,
          left: 4.0,
          right: 4.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Laser beam upper soft glow
              Container(
                height: 10.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.0),
                      color.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
              // Sharp intense horizontal scanner laser line with radiant core
              Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color,
                      Colors.white,
                      color,
                      color.withValues(alpha: 0.2),
                    ],
                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(2.0),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.85),
                      blurRadius: 10.0,
                      spreadRadius: 1.5,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 3.0,
                    ),
                  ],
                ),
              ),
              // Laser beam lower soft glow
              Container(
                height: 10.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlateConfirmedBadge() {
    return Center(
      child: Container(
        key: const ValueKey('plate_confirmed_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              AppStrings.plateConfirmed,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatePhotoPreviewCard() {
    final hasRealPlatePhoto = _platePhotoBytes != null &&
        _platePhotoBytes!.isNotEmpty &&
        !PlateScannerService.isPlaceholder(_platePhotoBytes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasRealPlatePhoto ? AppColors.success : AppColors.border,
                width: 1.5,
              ),
            ),
            child: hasRealPlatePhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.memory(
                      _platePhotoBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.photo,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  )
                : const Icon(Icons.camera_alt, color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.numberPlatePhotoLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasRealPlatePhoto
                      ? AppStrings.autoCapturedOnDetection
                      : AppStrings.numberPlatePhotoOptional,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasRealPlatePhoto ? AppColors.successDark : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            key: const ValueKey('retake_plate_photo_button'),
            onPressed: _capturePlatePhoto,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt, size: 12),
                const SizedBox(width: 4),
                Text(
                  AppStrings.retakePlatePhoto,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT HALF: Vehicle Entry Form Section
  // ---------------------------------------------------------------------------

  Widget _buildEntryFormSection() {
    final settings = _settingsService.currentSettings;
    final bool isCapacityFull = _availableCapacity <= 0;
    final typeLabel =
        _selectedType == VehicleType.twoWheeler ? AppStrings.twoWheeler : AppStrings.fourWheeler;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Shift Check Banner
          StreamBuilder<ShiftModel?>(
            stream: _shiftService.watchGuardCurrentActiveShift(
              widget.currentGuard.uid,
              widget.currentGuard.email,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final activeShift = snapshot.data;
              if (activeShift != null) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.noActiveShiftWarning,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Capacity Status Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isCapacityFull ? AppColors.dangerLight : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCapacityFull ? AppColors.danger : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCapacityFull ? Icons.block : Icons.info_outline,
                  color: isCapacityFull ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCapacityFull
                        ? (_selectedType == VehicleType.twoWheeler
                            ? AppStrings.twoWheelerParkingFull
                            : AppStrings.fourWheelerParkingFull)
                        : '$typeLabel ${AppStrings.available}: $_availableCapacity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isCapacityFull ? AppColors.dangerDark : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_isCheckingCapacity)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live System Entry Date/Time Indicator (Read-only for Guard)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  '${AppStrings.entryDateTime}: ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${AppStrings.autoCapturedOnConfirm} (${AppFormatters.formatDateTime(DateTime.now())})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Error Alert Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.dangerDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Section 1: Vehicle Category Selector
          Text(
            '1. ${AppStrings.selectVehicleCategory}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildVehicleTypeOption(
                  type: VehicleType.fourWheeler,
                  title: AppStrings.fourWheeler,
                  rateSubtitle: '₹${AppConstants.fourWheelerFirstHourRate.toInt()} ${AppStrings.firstHourRate}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVehicleTypeOption(
                  type: VehicleType.twoWheeler,
                  title: AppStrings.twoWheeler,
                  rateSubtitle: '₹${AppConstants.twoWheelerFirstHourRate.toInt()} ${AppStrings.firstHourRate}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Section 2: Number Plate & Mandatory Confirmation
          if (settings.numberPlateVisible) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '2. ${AppStrings.numberPlate}${settings.requireNumberPlate ? ' *' : ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isPlateConfirmed)
                  StatusBadge(label: AppStrings.plateConfirmed, type: BadgeType.active)
                else
                  StatusBadge(label: AppStrings.confirm, type: BadgeType.warning),
              ],
            ),
            const SizedBox(height: 8),

            // QR vs OCR Conflict Resolution Card
            if (_hasConflict) ...[
              Container(
                key: const ValueKey('qr_ocr_conflict_card'),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.dangerDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.qrOcrConflictTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dangerDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.qrOcrConflictDesc,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (_detectedQrPlate != null)
                          ActionChip(
                            key: const ValueKey('use_qr_value_chip'),
                            label: Text('${AppStrings.useQrValue}: $_detectedQrPlate'),
                            onPressed: () => _resolveConflict(_detectedQrPlate!),
                          ),
                        if (_detectedOcrPlate != null)
                          ActionChip(
                            key: const ValueKey('use_ocr_value_chip'),
                            label: Text('${AppStrings.useOcrValue}: $_detectedOcrPlate'),
                            onPressed: () => _resolveConflict(_detectedOcrPlate!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Editable Number Plate TextField
            AppTextField(
              key: const ValueKey('vehicle_number_field'),
              controller: _vehicleNumberController,
              labelText: '${AppStrings.vehicleNumber}${settings.requireNumberPlate ? ' *' : ''}',
              hintText: 'e.g. MH 12 AB 1234',
              textCapitalization: TextCapitalization.characters,
              prefixIcon: Icons.pin_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                UpperCaseTextFormatter(),
              ],
              suffixIcon: _isPlateConfirmed
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : null,
            ),
            const SizedBox(height: 8),

            // Mandatory Plate Confirmation Action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('confirm_plate_button'),
                    onPressed: _confirmPlateNumber,
                    icon: Icon(
                      _isPlateConfirmed ? Icons.check : Icons.verified_user,
                      size: 18,
                    ),
                    label: Text(_isPlateConfirmed ? AppStrings.plateConfirmed : AppStrings.confirmPlate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlateConfirmed ? AppColors.success : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isPlateConfirmed) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const ValueKey('edit_plate_button'),
                    onPressed: () {
                      setState(() {
                        _isPlateConfirmed = false;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(AppStrings.editPlateNumber),
                  ),
                ],
              ],
            ),

            // Monthly Pass Details Check
            if (_isCheckingPass) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(AppStrings.checkingMonthlyPass, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ] else if (_passCheckResult != null) ...[
              _buildMonthlyPassBanner(),
            ],
            const SizedBox(height: 18),
          ],

          // Section 3: Customer Mobile (Admin Settings controlled)
          if (settings.customerMobileVisible) ...[
            Text(
              '3. ${AppStrings.customerMobile}${settings.requireCustomerMobile ? ' *' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            AppTextField(
              key: const ValueKey('customer_mobile_field'),
              controller: _mobileController,
              labelText: '${AppStrings.customerMobile}${settings.requireCustomerMobile ? ' *' : ''}',
              hintText: AppStrings.enter10DigitMobile,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.phone_outlined,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Section 4: Optional Vehicle Photo (Admin Settings controlled)
          if (settings.vehiclePhotoVisible) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '4. ${AppStrings.vehiclePhotoOptionalLabel}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_vehiclePhotoBytes != null)
                  StatusBadge(label: AppStrings.vehiclePhotoCaptured, type: BadgeType.active)
                else
                  StatusBadge(label: 'Optional', type: BadgeType.info),
              ],
            ),
            const SizedBox(height: 8),
            _buildOptionalVehiclePhotoPicker(),
            const SizedBox(height: 18),
          ],

          // Section 5: Optional Advance Payment (Admin Settings controlled)
          if (settings.advanceEnabled) ...[
            _buildAdvancePaymentSection(),
            const SizedBox(height: 24),
          ],

          // Submit Button (Save Entry & Generate Ticket)
          AppButton(
            key: const ValueKey('save_entry_button'),
            label: isCapacityFull ? AppStrings.capacityFullBlocked : AppStrings.saveEntryButton,
            icon: Icons.check_circle,
            isLoading: _isLoading,
            onPressed: isCapacityFull ? null : _submitEntry,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeOption({
    required VehicleType type,
    required String title,
    required String rateSubtitle,
  }) {
    final isSelected = _selectedType == type;
    final isLocked = _passCheckResult?.hasValidPass == true;

    return Card(
      elevation: 0,
      color: isSelected
          ? AppColors.primarySurface
          : (isLocked ? AppColors.surfaceVariant.withValues(alpha: 0.4) : AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.vehicleTypeLockedByMonthlyPass),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : () {
                setState(() {
                  _selectedType = type;
                });
                _checkCapacity();
              },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.icon,
                    size: 28,
                    color: isSelected
                        ? AppColors.primary
                        : (isLocked ? AppColors.textMuted : AppColors.textSecondary),
                  ),
                  if (isSelected && isLocked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : (isLocked ? AppColors.textMuted : AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rateSubtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyPassBanner() {
    if (_passCheckResult!.hasValidPass) {
      final validPass = _passCheckResult!.validPass!;
      final isTypeMatch = validPass.vehicleType == _selectedType;
      final passTypeLabel =
          validPass.vehicleType == VehicleType.twoWheeler ? AppStrings.twoWheeler : AppStrings.fourWheeler;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTypeMatch ? AppColors.successLight : AppColors.warningLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isTypeMatch ? AppColors.success : AppColors.warning,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTypeMatch ? Icons.verified : Icons.warning_amber_rounded,
                  color: isTypeMatch ? AppColors.successDark : AppColors.warningDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppStrings.monthlyPass} ✓',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isTypeMatch ? AppColors.successDark : AppColors.warningDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isTypeMatch ? AppColors.success : AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppStrings.active.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${AppStrings.vehicleType}: $passTypeLabel | ${AppStrings.validTill}: ${AppFormatters.formatDate(validPass.endDate)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildOptionalVehiclePhotoPicker() {
    if (_vehiclePhotoBytes != null) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _vehiclePhotoBytes!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.photo, color: AppColors.textSecondary, size: 36),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: ElevatedButton.icon(
                key: const ValueKey('retake_vehicle_photo_button'),
                onPressed: _captureVehiclePhoto,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(AppStrings.retakeVehiclePhoto),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      key: const ValueKey('capture_vehicle_photo_card'),
      onTap: _captureVehiclePhoto,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, size: 30, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              AppStrings.captureVehiclePhoto,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancePaymentSection() {
    final settings = _settingsService.currentSettings;

    if (_passCheckResult?.hasValidPass == true &&
        _passCheckResult!.validPass!.vehicleType == _selectedType) {
      return Card(
        elevation: 0,
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.advancePayment,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.advanceNotRequiredForPass,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: '₹0', type: BadgeType.active),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: AppColors.cashColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.advancePayment,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Switch(
                  key: const ValueKey('advance_switch'),
                  value: _takeAdvance,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _takeAdvance = val;
                      if (!val) {
                        _advanceController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            if (_takeAdvance) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      controller: _advanceController,
                      labelText: '${AppStrings.advancePaid} (₹)',
                      hintText: '50',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        if (settings.cashEnabled)
                          Expanded(
                            child: _buildPaymentMethodChip(
                              label: AppStrings.cash,
                              value: 'cash',
                              icon: Icons.money,
                            ),
                          ),
                        if (settings.cashEnabled && settings.upiEnabled) const SizedBox(width: 8),
                        if (settings.upiEnabled)
                          Expanded(
                            child: _buildPaymentMethodChip(
                              label: AppStrings.upi,
                              value: 'upi',
                              icon: Icons.qr_code,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [20, 50, 100].map((amt) {
                  return ActionChip(
                    label: Text(AppFormatters.formatCurrency(amt.toDouble())),
                    onPressed: () {
                      setState(() {
                        _advanceController.text = amt.toString();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _advancePaymentMethod == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) {
        setState(() {
          _advancePaymentMethod = value;
        });
      },
    );
  }
}

/// Custom painter for modern QR scanner style corner brackets, glow depth pass, and HUD center guides.
class _ScannerCornerPainter extends CustomPainter {
  final Color cornerColor;
  final double cornerLength;
  final double cornerThickness;
  final double cornerRadius;
  final double borderAlpha;

  const _ScannerCornerPainter({
    required this.cornerColor,
    this.cornerLength = 32.0,
    this.cornerThickness = 4.0,
    this.cornerRadius = 10.0,
    this.borderAlpha = 0.20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle bounding guide border connecting the corners
    if (borderAlpha > 0) {
      final borderPaint = Paint()
        ..color = cornerColor.withValues(alpha: borderAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final borderRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(cornerRadius),
      );
      canvas.drawRRect(borderRRect, borderPaint);
    }

    // 2. Clear four corner brackets with neon depth glow
    final r = cornerRadius;
    final l = cornerLength.clamp(r + 2, w / 2);

    final tlPath = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(l, 0);

    final trPath = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, l);

    final blPath = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(l, h);

    final brPath = Path()
      ..moveTo(w, h - l)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - l, h);

    // Glow underlayer
    final glowPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerThickness + 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(tlPath, glowPaint);
    canvas.drawPath(trPath, glowPaint);
    canvas.drawPath(blPath, glowPaint);
    canvas.drawPath(brPath, glowPaint);

    // Sharp foreground corner brackets
    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerThickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(tlPath, cornerPaint);
    canvas.drawPath(trPath, cornerPaint);
    canvas.drawPath(blPath, cornerPaint);
    canvas.drawPath(brPath, cornerPaint);

    // 3. Subtle horizontal alignment ticks at center left & right (parking HUD aiming guide)
    final tickPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final midY = h / 2;
    canvas.drawLine(Offset(4, midY), Offset(14, midY), tickPaint);
    canvas.drawLine(Offset(w - 14, midY), Offset(w - 4, midY), tickPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) {
    return oldDelegate.cornerColor != cornerColor ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.cornerThickness != cornerThickness ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.borderAlpha != borderAlpha;
  }
}

/// Custom painter for modern QR scanner viewfinder mask that softly dims preview outside detection frame.
class _ScannerMaskPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final double cornerRadius;
  final Color scrimColor;

  const _ScannerMaskPainter({
    required this.frameWidth,
    required this.frameHeight,
    required this.cornerRadius,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scrimColor.a == 0) return;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    final frameRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, Radius.circular(cornerRadius)));
    final combined = Path.combine(PathOperation.difference, bgPath, cutoutPath);

    final paint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerMaskPainter oldDelegate) {
    return oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.scrimColor != scrimColor;
  }
}

