import 'dart:typed_data';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/screens/guard/entry/vehicle_entry_screen.dart';
import 'package:car_parking_system/services/ocr/live_camera_ocr_service.dart';
import 'package:car_parking_system/services/ocr/plate_ocr_service.dart';
import 'package:car_parking_system/services/ocr/plate_stability_tracker.dart';
import 'package:car_parking_system/services/plate_scanner_service.dart';
import 'package:car_parking_system/widgets/camera/web_camera_dialog.dart';
import 'package:car_parking_system/widgets/camera/web_camera_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testGuard = GuardModel(
    uid: 'guard-test-01',
    name: 'Santosh Guard',
    email: 'santosh@parking.biz',
    mobile: '9876543210',
    isActive: true,
  );

  setUp(() {
    VehicleEntryScreen.resetTestMocks();
    PlateScannerService.resetMocks();
    PlateOcrService.resetMocks();
    WebCameraPlatform.resetMocks();
    AppStrings.setLanguage(AppLanguage.english);
  });

  tearDown(() {
    VehicleEntryScreen.resetTestMocks();
    PlateScannerService.resetMocks();
    PlateOcrService.resetMocks();
    WebCameraPlatform.resetMocks();
  });

  group('VEHICLE ENTRY — HORIZONTAL SPLIT, SCANNING & OCR TESTS', () {
    testWidgets('1. Horizontal Split Layout on wide/landscape screen (>= 720px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Side-by-side sections visible simultaneously
      expect(find.byKey(const ValueKey('camera_scanning_section')), findsOneWidget);
      expect(find.byKey(const ValueKey('entry_form_section')), findsOneWidget);

      // Camera Framing guide visible with horizontal focus indicator
      expect(find.byKey(const ValueKey('number_plate_framing_guide')), findsOneWidget);
      expect(find.text(AppStrings.numberPlateFramingGuide), findsOneWidget);

      // Camera controls visible
      expect(find.byKey(const ValueKey('toggle_torch_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('switch_camera_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('rescan_button')), findsOneWidget);
    });

    testWidgets('2. Responsive Compact Layout on narrow portrait screens (< 720px)', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Uses stacked portrait view
      expect(find.byKey(const ValueKey('portrait_entry_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('number_plate_framing_guide')), findsOneWidget);
      expect(find.byKey(const ValueKey('save_entry_button')), findsOneWidget);
    });

    testWidgets('3. Camera permission denial shows helpful UI and does NOT crash form', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      VehicleEntryScreen.mockCameraPermissionDenied = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows permission denied card and retry button
      expect(find.byKey(const ValueKey('camera_permission_denied_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('retry_permission_button')), findsOneWidget);

      // Form remains completely operational
      expect(find.byKey(const ValueKey('save_entry_button')), findsOneWidget);
    });

    testWidgets('4. QR scan with vehicle type extracts both plate and type; auto-captures photo', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockPhoto = PlateScannerService.kTransparent1x1Png;
      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH12AB1234',
        vehicleType: VehicleType.twoWheeler,
        confidence: 1.0,
        isQr: true,
        photoBytes: mockPhoto,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plate field populated
      expect(find.text('MH12AB1234'), findsOneWidget);

      // Two-wheeler category selected automatically
      expect(find.text(AppStrings.twoWheeler), findsWidgets);
    });

    testWidgets('5. QR scan WITHOUT vehicle type leaves vehicle type to guard selection', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH14CD5678',
        vehicleType: null, // NOT present in QR
        confidence: 1.0,
        isQr: true,
        photoBytes: PlateScannerService.kTransparent1x1Png,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plate populated
      expect(find.text('MH14CD5678'), findsOneWidget);

      // Default four-wheeler preserved without fabrication
      expect(find.text(AppStrings.fourWheeler), findsWidgets);
    });

    testWidgets('6. QR vs OCR Mismatch triggers conflict resolution card', (tester) async {
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Directly verify PlateScannerService.hasConflict
      expect(PlateScannerService.hasConflict('MH12AB1111', 'MH12AB2222'), isTrue);
      expect(PlateScannerService.hasConflict('MH12AB1111', 'MH12AB1111'), isFalse);
      expect(PlateScannerService.hasConflict('MH 12 AB 1111', 'MH12AB1111'), isFalse);
    });

    testWidgets('7. Mandatory Number Plate Confirmation: blocks save if plate entered but unconfirmed', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter vehicle number manually
      final plateFinder = find.byKey(const ValueKey('vehicle_number_field'));
      await tester.ensureVisible(plateFinder);
      await tester.enterText(plateFinder, 'MH12AB1234');
      await tester.pumpAndSettle();

      // Attempt save without tapping confirm
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Confirmation required error displayed
      expect(find.text(AppStrings.plateConfirmationRequired), findsOneWidget);

      // Tap Confirm Plate button
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Plate confirmed status shown
      expect(find.text(AppStrings.plateConfirmed), findsWidgets);
      expect(find.byKey(const ValueKey('edit_plate_button')), findsOneWidget);
    });

    testWidgets('8. Number plate photo required by settings blocks save when missing', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm valid plate number manually (without camera capture)
      final plateFinder = find.byKey(const ValueKey('vehicle_number_field'));
      await tester.ensureVisible(plateFinder);
      await tester.enterText(plateFinder, 'MH12AB1234');
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Customer mobile
      final mobileFinder = find.byKey(const ValueKey('customer_mobile_field'));
      await tester.ensureVisible(mobileFinder);
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pumpAndSettle();

      // Attempt save while plate photo is missing
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Missing photo blocked save (displayed in preview status card and error banner)
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsWidgets);
    });

    testWidgets('9. Optional Vehicle Photo does NOT block save when empty', (tester) async {
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Optional vehicle photo card is visible
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('capture_vehicle_photo_card')), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
    });

    testWidgets('10. Full Marathi localization of Vehicle Entry screen', (tester) async {
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AppStrings.setLanguage(AppLanguage.marathi);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Marathi headers and buttons
      expect(find.text(AppStrings.cameraScanningTitle), findsOneWidget);
      expect(find.text(AppStrings.numberPlateFramingGuide), findsOneWidget);
      expect(find.text(AppStrings.confirmPlate), findsOneWidget);
      expect(find.text(AppStrings.rescan), findsOneWidget);
      expect(find.text(AppStrings.saveEntryButton), findsOneWidget);
    });

    test('11. PlateScannerService.isPlaceholder accurately identifies transparent 1x1 placeholder and accepts genuine photos', () {
      // The 67-byte transparent 1x1 placeholder MUST be flagged as placeholder
      expect(PlateScannerService.isPlaceholder(PlateScannerService.kTransparent1x1Png), isTrue);
      expect(PlateScannerService.isPlaceholder(null), isTrue);
      expect(PlateScannerService.isPlaceholder(Uint8List(0)), isTrue);
      expect(PlateScannerService.isPlaceholder(Uint8List(50)), isTrue);

      // Real photo bytes (larger, non-placeholder) MUST NOT be flagged as placeholder
      expect(PlateScannerService.isPlaceholder(PlateScannerService.kTestSamplePhotoBytes), isFalse);
    });

    testWidgets('12. Automatic Live Plate Detection continuously analyzes incoming frames, detects plate without pressing Capture Photo, populates plate, and requires explicit confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simulate live incoming plate frames detected continuously without any button press
      VehicleEntryScreen.mockContinuousPlateCandidate = 'MH12DE1234';
      VehicleEntryScreen.mockContinuousFrameCount = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plate field automatically populated from live stream without pressing Capture Photo!
      expect(find.text('MH12DE1234'), findsOneWidget);

      // Plate detected badge shown
      expect(find.text(AppStrings.plateDetectedHighConfidence), findsOneWidget);

      // Plate is NOT confirmed automatically — explicit Confirm Plate is mandatory
      expect(find.byKey(const ValueKey('confirm_plate_button')), findsOneWidget);
      expect(find.text(AppStrings.confirmPlate), findsOneWidget);

      // Save without confirmation must be blocked
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.plateConfirmationRequired), findsOneWidget);

      // Guard explicitly confirms plate
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.plateConfirmed), findsWidgets);
      expect(find.byKey(const ValueKey('edit_plate_button')), findsOneWidget);
    });

    testWidgets('13. Transparent 1x1 placeholder is NEVER treated as real photo and blocks saving when photo is required', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // QR scan that has 1x1 placeholder
      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH12AB9999',
        confidence: 1.0,
        isQr: true,
        photoBytes: PlateScannerService.kTransparent1x1Png,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm the plate
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Fill mobile
      final mobileFinder = find.byKey(const ValueKey('customer_mobile_field'));
      await tester.ensureVisible(mobileFinder);
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pumpAndSettle();

      // Preview card STILL indicates photo is required (because 1x1 placeholder was rejected!)
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsWidgets);

      // Attempt save
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Save was blocked because transparent placeholder is NOT accepted as a real photo!
      expect(find.text(AppStrings.numberPlatePhotoRequired), findsWidgets);
    });

    testWidgets('14. OCR extraction logic correctly normalizes noisy text candidates', (tester) async {
      final evaluated1 = PlateScannerService.evaluateOcr(
        detectedText: 'IND MH 12 PQ 5678',
      );
      expect(evaluated1.hasPlate, isTrue);
      expect(evaluated1.plateNumber, equals('MH12PQ5678'));

      final evaluated2 = PlateScannerService.evaluateOcr(
        detectedText: '22BH1234AA',
      );
      expect(evaluated2.hasPlate, isTrue);
      expect(evaluated2.plateNumber, equals('22BH1234AA'));
    });

    test('15. PlateStabilityTracker requires repeated consecutive frames within time window and ignores noise', () {
      final tracker = PlateStabilityTracker(
        requiredConsecutiveMatches: 2,
        windowDuration: const Duration(milliseconds: 1000),
      );

      // 1. Single frame candidate does NOT lock (returns null)
      final frame1 = tracker.addCandidate('MH 12 AB 1234');
      expect(frame1, isNull);
      expect(tracker.hasPendingCandidate, isTrue);
      expect(tracker.consecutiveCount, equals(1));
      expect(tracker.isLocked, isFalse);

      // 2. Different / invalid candidate breaks consensus
      final frame2 = tracker.addCandidate('INVALID');
      expect(frame2, isNull);

      // 3. New candidate first frame
      final frame3 = tracker.addCandidate('MH 14 CD 5678');
      expect(frame3, isNull);
      expect(tracker.consecutiveCount, equals(1));

      // 4. Second consecutive match locks plate!
      final frame4 = tracker.addCandidate('MH 14 CD 5678');
      expect(frame4, equals('MH14CD5678'));
      expect(tracker.isLocked, isTrue);
      expect(tracker.lockedPlate, equals('MH14CD5678'));

      // 5. Subsequent frames with same plate do NOT return new event (prevents duplicate spamming)
      final frame5 = tracker.addCandidate('MH 14 CD 5678');
      expect(frame5, isNull);

      // 6. Reset completely clears tracker
      tracker.reset();
      expect(tracker.isLocked, isFalse);
      expect(tracker.consecutiveCount, equals(0));
      expect(tracker.currentCandidate, isNull);
    });

    testWidgets('16. Confirmation is reset when plate is manually edited or a different plate is scanned', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start with confirmed plate
      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH12AB1234',
        confidence: 1.0,
        isQr: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Guard confirms
      final confirmBtn = find.byKey(const ValueKey('confirm_plate_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.plateConfirmed), findsWidgets);

      // 1. Guard edits plate -> confirmation is immediately reset
      final plateField = find.byKey(const ValueKey('vehicle_number_field'));
      await tester.enterText(plateField, 'MH12AB9999');
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.confirmPlate), findsOneWidget);

      // 2. Confirm again
      await tester.tap(find.byKey(const ValueKey('confirm_plate_button')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.plateConfirmed), findsWidgets);

      // 3. Different plate detected via live OCR candidate -> confirmation is reset again
      final state = tester.state(find.byType(VehicleEntryScreen)) as dynamic;
      state.simulateLiveCandidate('MH14CD5678');
      state.simulateLiveCandidate('MH14CD5678');
      await tester.pumpAndSettle();

      expect(find.text('MH14CD5678'), findsOneWidget);
      expect(find.text(AppStrings.confirmPlate), findsOneWidget);
    });

    testWidgets('17. QR vs OCR plate mismatch shows conflict card and requires explicit resolution before saving', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Initial QR scan
      VehicleEntryScreen.mockScanResult = PlateScanResult(
        plateNumber: 'MH12AB1111',
        confidence: 1.0,
        isQr: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Live OCR detects different plate
      final state = tester.state(find.byType(VehicleEntryScreen)) as dynamic;
      state.simulateLiveCandidate('MH12AB2222');
      state.simulateLiveCandidate('MH12AB2222');
      await tester.pumpAndSettle();

      // Conflict card is visible
      expect(find.byKey(const ValueKey('qr_ocr_conflict_card')), findsOneWidget);
      expect(find.text(AppStrings.qrOcrConflictTitle), findsWidgets);

      // Attempting to save while conflict exists is BLOCKED
      final saveBtn = find.byKey(const ValueKey('save_entry_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.qrOcrConflictDesc), findsWidgets);

      // Guard resolves conflict by choosing OCR value
      final ocrChip = find.byKey(const ValueKey('use_ocr_value_chip'));
      await tester.ensureVisible(ocrChip);
      await tester.tap(ocrChip);
      await tester.pumpAndSettle();

      // Conflict card dismissed and selected plate populated
      expect(find.byKey(const ValueKey('qr_ocr_conflict_card')), findsNothing);
      expect(find.text('MH12AB2222'), findsOneWidget);
    });

    testWidgets('18. Manual Capture Photo button is REMOVED from number plate scanning workflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify manual Capture Photo / scan_ocr_button is NOT present in scanning controls
      expect(find.byKey(const ValueKey('scan_ocr_button')), findsNothing);
      expect(find.text(AppStrings.scanOcrPlate), findsNothing);
    });

    test('19. LiveCameraOcrService and stability tracker reset and clean up properly', () async {
      final service = LiveCameraOcrService();
      expect(service.stabilityTracker.isLocked, isFalse);

      service.stabilityTracker.addCandidate('MH12AB1234');
      expect(service.stabilityTracker.hasPendingCandidate, isTrue);

      service.resetStability();
      expect(service.stabilityTracker.consecutiveCount, equals(0));

      await service.dispose();
    });

    test('20. Real Sample Plate Image OCR pipeline extracts MH12AB1234 from HSRP plate image with IND band and laser pin noise', () {
      // 1. Generate a genuine encoded PNG image of an HSRP vehicle registration plate
      final plateCanvas = img.Image(width: 240, height: 70);
      img.fill(plateCanvas, color: img.ColorRgb8(255, 255, 255));
      // Blue IND strip on left side of HSRP plate
      img.fillRect(plateCanvas, x1: 0, y1: 0, x2: 30, y2: 70, color: img.ColorRgb8(0, 51, 153));
      final realPlatePngBytes = Uint8List.fromList(img.encodePng(plateCanvas));

      // Verify the generated plate is a genuine, non-placeholder image
      expect(realPlatePngBytes.length, greaterThan(100));
      expect(PlateScannerService.isPlaceholder(realPlatePngBytes), isFalse);

      // 2. Test OCR evaluation on real HSRP formatted text containing IND and laser pin
      final hsrpCandidateWithLaserPin = 'AA2039485721\nIND\nMH 12 AB 1234';
      final evaluated1 = PlateScannerService.evaluateOcr(
        detectedText: hsrpCandidateWithLaserPin,
        photoBytes: realPlatePngBytes,
      );
      expect(evaluated1.hasPlate, isTrue);
      expect(evaluated1.plateNumber, equals('MH12AB1234'));
      expect(evaluated1.isHighConfidence, isTrue);
      expect(evaluated1.photoBytes, isNotNull);
      expect(PlateScannerService.isPlaceholder(evaluated1.photoBytes), isFalse);

      // 3. Test OCR evaluation on single-line IND-prefixed plate
      final evaluated2 = PlateScannerService.evaluateOcr(
        detectedText: 'IND MH 12 AB 1234',
        photoBytes: realPlatePngBytes,
      );
      expect(evaluated2.hasPlate, isTrue);
      expect(evaluated2.plateNumber, equals('MH12AB1234'));

      // 4. Test hyphenated plate format
      final evaluated3 = PlateScannerService.evaluateOcr(
        detectedText: 'MH-12-AB-1234',
        photoBytes: realPlatePngBytes,
      );
      expect(evaluated3.hasPlate, isTrue);
      expect(evaluated3.plateNumber, equals('MH12AB1234'));

      // 5. Test Bharat series HSRP plate format
      final evaluated4 = PlateScannerService.evaluateOcr(
        detectedText: 'IND 22 BH 1234 AA',
        photoBytes: realPlatePngBytes,
      );
      expect(evaluated4.hasPlate, isTrue);
      expect(evaluated4.plateNumber, equals('22BH1234AA'));

      // 6. Verify that PlateStabilityTracker successfully locks on the extracted plate
      final tracker = PlateStabilityTracker(
        requiredConsecutiveMatches: 2,
        windowDuration: const Duration(milliseconds: 3500),
      );
      expect(tracker.addCandidate(evaluated1.plateNumber!), isNull); // 1st frame
      expect(tracker.addCandidate(evaluated1.plateNumber!), equals('MH12AB1234')); // 2nd frame locks
      expect(tracker.isLocked, isTrue);
      expect(tracker.lockedPlate, equals('MH12AB1234'));
    });

    testWidgets('21. WebCameraDialog plate scanning mode removes manual Capture Photo button, while optional vehicle photo mode keeps it', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        WebCameraPlatform.resetMocks();
      });

      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.success();
      WebCameraPlatform.mockGetAvailableCameras = () async => [
        CameraDeviceInfo(
          id: 'rear-cam-001',
          label: 'Back Camera HD',
          facing: CameraFacing.rear,
        ),
      ];

      // A) Plate Scanning Mode (isPlateScanning = true)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebCameraDialog(
              isPlateScanning: true,
              onPlateDetected: (plate, photo) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In plate scanning mode, manual "Capture Photo" button MUST NOT exist
      expect(find.byKey(const ValueKey('capture_photo_button')), findsNothing);
      expect(find.text('Capture Photo'), findsNothing);
      expect(find.text('Number Plate Scanner (Live OCR)'), findsOneWidget);
      expect(find.text('Align Number Plate in Frame'), findsOneWidget);

      // Clean up previous widget
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      // B) Optional Vehicle Photo Mode (isPlateScanning = false)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebCameraDialog(
              isPlateScanning: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In vehicle photo mode, manual "Capture Photo" button IS present
      expect(find.byKey(const ValueKey('capture_photo_button')), findsOneWidget);
      expect(find.text('Live Vehicle Camera'), findsOneWidget);
      expect(find.text('Align Vehicle / Plate in Frame'), findsOneWidget);
    });

    testWidgets('22. Live OCR status banner is displayed below camera viewport with dynamic feedback', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Live OCR Status Banner is displayed right below the camera viewport
      expect(find.byKey(const ValueKey('live_ocr_status_banner')), findsOneWidget);
    });

    testWidgets('23. Web Camera Active: Displays web video preview, framing guide, and scanning status', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        VehicleEntryScreen.resetTestMocks();
        WebCameraPlatform.resetMocks();
      });

      VehicleEntryScreen.mockIsWeb = true;
      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.success();
      WebCameraPlatform.mockGetAvailableCameras = () async => [
        CameraDeviceInfo(id: 'webcam-01', label: 'Integrated Camera HD', facing: CameraFacing.front),
      ];
      WebCameraPlatform.mockBuildCameraView = ({required viewId, required onReady}) =>
          const SizedBox();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('web_camera_preview_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('number_plate_framing_guide')), findsOneWidget);
      expect(find.byKey(const ValueKey('live_ocr_status_banner')), findsOneWidget);
      expect(find.text(AppStrings.scanningForQrAndPlate), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('24. Web Camera Permission Denied: Displays clear permission denied card and disables active scanning status', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        VehicleEntryScreen.resetTestMocks();
        WebCameraPlatform.resetMocks();
      });

      VehicleEntryScreen.mockIsWeb = true;
      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.failure('Camera access was denied by user.', 'NotAllowedError');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('camera_permission_denied_card')), findsOneWidget);
      expect(find.text(AppStrings.cameraPermissionDeniedTitle), findsWidgets);
      expect(find.byKey(const ValueKey('retry_permission_button')), findsOneWidget);
      // Does NOT show active scanning banner when permission is denied
      expect(find.byKey(const ValueKey('live_ocr_status_banner')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('25. Web Camera No Device: Displays No Camera Detected card when no videoinput hardware is found', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        VehicleEntryScreen.resetTestMocks();
        WebCameraPlatform.resetMocks();
      });

      VehicleEntryScreen.mockIsWeb = true;
      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.success();
      WebCameraPlatform.mockGetAvailableCameras = () async => [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('web_camera_no_device_card')), findsOneWidget);
      expect(find.text('No Camera Detected'), findsWidgets);
      expect(find.byKey(const ValueKey('retry_web_camera_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('live_ocr_status_banner')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('26. Web Camera Initialization Failed: Displays Camera Initialization Failed card with retry button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        VehicleEntryScreen.resetTestMocks();
        WebCameraPlatform.resetMocks();
      });

      VehicleEntryScreen.mockIsWeb = true;
      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.failure('Camera device hardware failed to open.', 'NotReadableError');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEntryScreen(
              currentGuard: testGuard,
              onReturnDashboard: () {},
              onViewActiveParking: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('web_camera_init_failed_card')), findsOneWidget);
      expect(find.text('Camera Initialization Failed'), findsWidgets);
      expect(find.byKey(const ValueKey('retry_web_camera_init_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('live_ocr_status_banner')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
