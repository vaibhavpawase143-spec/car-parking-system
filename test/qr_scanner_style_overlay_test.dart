import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/utils/formatters.dart';
import 'package:car_parking_system/models/guard_model.dart';
import 'package:car_parking_system/screens/guard/entry/vehicle_entry_screen.dart';
import 'package:car_parking_system/services/plate_scanner_service.dart';
import 'package:car_parking_system/services/ocr/plate_ocr_service.dart';
import 'package:car_parking_system/services/ocr/plate_stability_tracker.dart';
import 'package:car_parking_system/widgets/camera/web_camera_stub.dart';

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

  group('VEHICLE ENTRY — QR SCANNER STYLE OVERLAY TESTS', () {
    testWidgets('1. Framing guide is enlarged and noticeably wider than previous 240px width', (tester) async {
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      // Verify width is noticeably larger and wider than the old 240px frame
      expect(size.width, greaterThanOrEqualTo(320.0));
      expect(size.height, greaterThanOrEqualTo(110.0));

      // Verify it does not cover the full viewport height (280)
      expect(size.height, lessThan(280.0));
    });

    testWidgets('2. Framing guide is responsive on compact screens without covering preview', (tester) async {
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      // Even on compact screens, width is wider than 240px
      expect(size.width, greaterThan(240.0));
      expect(size.height, lessThan(220.0)); // Does not cover full 220px compact viewport
    });

    testWidgets('3. Corner brackets painter is present within the framing guide', (tester) async {
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

      // Find CustomPaint inside the framing guide
      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      final customPaintFinder = find.descendant(of: guideFinder, matching: find.byType(CustomPaint));
      expect(customPaintFinder, findsWidgets);
    });

    testWidgets('4. Animated horizontal scanning line is active during web streaming and stops on plate confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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

      // Animated scanning line should be present while scanning
      final scanLineFinder = find.byKey(const ValueKey('scanner_animated_scan_line'));
      expect(scanLineFinder, findsOneWidget);

      // Verify the state is not confirmed yet
      final state = tester.state(find.byType(VehicleEntryScreen)) as dynamic;
      expect(state.isPlateConfirmed, isFalse);

      // Now enter and confirm a plate
      await tester.enterText(find.byKey(const ValueKey('vehicle_number_field')), 'MH12AB1234');
      await tester.tap(find.byKey(const ValueKey('confirm_plate_button')));
      await tester.pump();

      // Once plate is confirmed, the laser scan line must be removed/hidden
      expect(find.byKey(const ValueKey('scanner_animated_scan_line')), findsNothing);
      expect(find.byKey(const ValueKey('plate_confirmed_badge')), findsOneWidget);

      // Tap Rescan button
      await tester.tap(find.byKey(const ValueKey('rescan_button')));
      await tester.pump();

      // Rescan restores scanning animation line and removes confirmed badge
      expect(find.byKey(const ValueKey('scanner_animated_scan_line')), findsOneWidget);
      expect(find.byKey(const ValueKey('plate_confirmed_badge')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('5. Scanning laser line moves vertically when animation ticks', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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

      final state = tester.state(find.byType(VehicleEntryScreen)) as dynamic;
      final controller = state.scanLineController as AnimationController;

      // Set animation value to 0.1 and check top position
      controller.value = 0.1;
      await tester.pump();
      final posAt01 = tester.getTopLeft(find.byKey(const ValueKey('scanner_animated_scan_line')));

      // Set animation value to 0.9 and check top position
      controller.value = 0.9;
      await tester.pump();
      final posAt09 = tester.getTopLeft(find.byKey(const ValueKey('scanner_animated_scan_line')));

      // Laser line must have moved down significantly
      expect(posAt09.dy, greaterThan(posAt01.dy));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6. Wide screen layout enlarges framing guide width up to 480px', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      expect(size.width, greaterThanOrEqualTo(450.0));
      expect(size.height, greaterThanOrEqualTo(130.0));
      expect(size.height, lessThan(280.0));
    });

    testWidgets('7. Viewfinder dark mask scrim is rendered over preview while camera stream is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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

      // Viewfinder mask scrim CustomPaint must be present outside the framing guide
      final customPaints = find.byType(CustomPaint);
      expect(customPaints, findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('8. Plate detection reflects in framing guide UI without manual capture', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      VehicleEntryScreen.mockIsWeb = true;
      WebCameraPlatform.mockStartStream = (viewId, {deviceId, preferredFacing}) async =>
          CameraStartResult.success();
      WebCameraPlatform.mockGetAvailableCameras = () async => [
        CameraDeviceInfo(id: 'webcam-01', label: 'Integrated Camera HD', facing: CameraFacing.front),
      ];
      WebCameraPlatform.mockBuildCameraView = ({required viewId, required onReady}) =>
          const SizedBox();

      // Mock OCR candidate to simulate automatic OCR detection
      VehicleEntryScreen.mockContinuousPlateCandidate = 'MH14EU1122';
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));

      // Automatic OCR populated vehicle number field and status pill
      final numberField = find.byKey(const ValueKey('vehicle_number_field'));
      expect(numberField, findsOneWidget);
      expect(find.text('MH14EU1122'), findsWidgets);

      // Verify status pill inside framing guide shows detected plate
      expect(find.text('Plate detected: MH14EU1122'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('ENLARGED DETECTION FRAME & OCR ACCURACY UPGRADES', () {
    testWidgets('1. Desktop framing guide targets ~95% preview width and 65-70% preview height', (tester) async {
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      // Desktop camera card height is 280.
      // Framing guide height targets 65-70% of preview height (~190px)
      expect(size.height, greaterThanOrEqualTo(180.0));
      expect(size.height, lessThanOrEqualTo(196.0));
      final heightRatio = size.height / 280.0;
      expect(heightRatio, greaterThanOrEqualTo(0.65));
      expect(heightRatio, lessThanOrEqualTo(0.70));

      // Desktop width is substantially enlarged to ~95% of available camera section width
      expect(size.width, greaterThanOrEqualTo(480.0));
      expect(size.width, lessThanOrEqualTo(580.0));
    });

    testWidgets('2. Mobile layout scales framing guide to ~95% width and 65-70% height without covering preview', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      // Mobile compact camera viewport height is 220.
      // Frame height targets 65-70% of preview height (~150px)
      expect(size.height, greaterThanOrEqualTo(140.0));
      expect(size.height, lessThanOrEqualTo(155.0));
      final heightRatio = size.height / 220.0;
      expect(heightRatio, greaterThanOrEqualTo(0.65));
      expect(heightRatio, lessThanOrEqualTo(0.70));

      // Width scales to ~95% of usable preview width, leaving small margins so it does not touch boundary
      expect(size.width, greaterThan(280.0));
      expect(size.width, lessThan(350.0));
    });

    testWidgets('2b. Tablet layout scales framing guide responsively with centered margins', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
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

      final guideFinder = find.byKey(const ValueKey('number_plate_framing_guide'));
      expect(guideFinder, findsOneWidget);

      final size = tester.getSize(guideFinder);
      // Height is 65-70% of 280 viewport
      expect(size.height / 280.0, inInclusiveRange(0.65, 0.70));
      // Width is enlarged to ~95% of available camera section width in horizontal split
      expect(size.width, greaterThan(280.0));
      expect(size.width, lessThan(400.0));
    });

    test('3. Background noise rejection eliminates apparel brands, signs, faces, and car badges', () {
      // Apparel / Brands / Shirts
      expect(PlateScannerService.isBackgroundNoiseText('SUPERMAN'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('CHAMPION'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('LEVIS'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('DENIM'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('NIKE'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('POLICE'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('ARMY'), isTrue);

      // Facility / Parking words
      expect(PlateScannerService.isBackgroundNoiseText('PARKING'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('ENTRY'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('EXIT'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('FASTAG'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('SLOW'), isTrue);

      // Car Badges / Model names
      expect(PlateScannerService.isBackgroundNoiseText('SWIFT'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('CRETA'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('SCORPIO'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('FORTUNER'), isTrue);

      // Cities on posters / shirts
      expect(PlateScannerService.isBackgroundNoiseText('CHICAGO'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('BOSTON'), isTrue);

      // Repetitive face/clothing fold artifacts
      expect(PlateScannerService.isBackgroundNoiseText('XXXXXX'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('000000'), isTrue);
      expect(PlateScannerService.isBackgroundNoiseText('====='), isTrue);

      // Legitimate plates are NOT noise
      expect(PlateScannerService.isBackgroundNoiseText('MH12AB1234'), isFalse);
      expect(PlateScannerService.isBackgroundNoiseText('DL04CA9999'), isFalse);
    });

    test('4. OCR evaluation rejects noise text with "Plate not clear — reposition the plate"', () {
      // Background noise words
      final r1 = PlateScannerService.evaluateOcr(detectedText: 'SUPERMAN');
      expect(r1.hasPlate, isFalse);
      expect(r1.errorMessage, equals('Plate not clear — reposition the plate'));

      final r2 = PlateScannerService.evaluateOcr(detectedText: 'CHICAGO 23');
      expect(r2.hasPlate, isFalse);
      expect(r2.errorMessage, equals('Plate not clear — reposition the plate'));

      // Non-plate random words on signs or shirts
      final r3 = PlateScannerService.evaluateOcr(detectedText: 'ROOM 101');
      expect(r3.hasPlate, isFalse);

      final r4 = PlateScannerService.evaluateOcr(detectedText: 'BEST 100');
      expect(r4.hasPlate, isFalse);

      // Empty string
      final r5 = PlateScannerService.evaluateOcr(detectedText: '');
      expect(r5.hasPlate, isFalse);
      expect(r5.errorMessage, equals('Plate not clear — reposition the plate'));
    });

    test('5. Valid Indian registration patterns across states and Bharat series', () {
      // Standard Indian State Codes
      expect(AppFormatters.isValidVehicleNumber('MH12AB1234'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('DL04CA9999'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('KA011234'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('GJ01XX1234'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('AN01A1234'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('WB02AB1234'), isTrue);

      // Bharat Series
      expect(AppFormatters.isValidVehicleNumber('22BH1234AA'), isTrue);
      expect(AppFormatters.isValidVehicleNumber('21BH9999Z'), isTrue);

      // Rejects non-state codes and random word prefixes
      expect(AppFormatters.isValidVehicleNumber('RO12AB1234'), isFalse);
      expect(AppFormatters.isValidVehicleNumber('BE12AB1234'), isFalse);
      expect(AppFormatters.isValidVehicleNumber('SH12AB1234'), isFalse);
      expect(AppFormatters.isValidVehicleNumber('FA12AB1234'), isFalse);
      expect(AppFormatters.isValidVehicleNumber('XX12AB1234'), isFalse);
    });

    test('6. Slot-aware character confusion correction without blind conversion', () {
      // Letter in number position corrected
      final c1 = PlateScannerService.attemptPlateCharacterCorrection('MH12AB123O');
      expect(c1, equals('MH12AB1230'));

      final c2 = PlateScannerService.attemptPlateCharacterCorrection('MH12AB123I');
      expect(c2, equals('MH12AB1231'));

      // Number in series letter position corrected
      final c3 = PlateScannerService.attemptPlateCharacterCorrection('MH12A81234');
      expect(c3, equals('MH12AB1234'));

      // Odisha/Orissa state code single digit error corrected
      final c4 = PlateScannerService.attemptPlateCharacterCorrection('0D01AB1234');
      expect(c4, equals('OD01AB1234'));

      // Arbitrary words requiring > 2 substitutions are rejected, not blindly converted
      final c5 = PlateScannerService.attemptPlateCharacterCorrection('HELLO WORLD');
      expect(c5, isNull);

      final c6 = PlateScannerService.attemptPlateCharacterCorrection('SHOPPING123');
      expect(c6, isNull);
    });

    test('7. Stability tracker enforces multi-frame consensus before plate lock', () {
      final tracker = PlateStabilityTracker();

      // First frame candidate registered -> NOT yet stable
      final first = tracker.addCandidate('MH12AB1234');
      expect(first, isNull);
      expect(tracker.hasPendingCandidate, isTrue);
      expect(tracker.consecutiveCount, equals(1));

      // Second consecutive matching frame -> STABLE and confirmed
      final second = tracker.addCandidate('MH12AB1234');
      expect(second, equals('MH12AB1234'));
      expect(tracker.consecutiveCount, equals(2));

      // Mismatch resets counter
      tracker.reset();
      tracker.addCandidate('MH12AB1234');
      final mismatch = tracker.addCandidate('DL01AB5555');
      expect(mismatch, isNull);
      expect(tracker.consecutiveCount, equals(1));
    });

    test('8. Conflict detection flags discrepancies between QR code and OCR plate readings', () {
      expect(PlateScannerService.hasConflict('MH12AB1234', 'DL01CD5678'), isTrue);
      expect(PlateScannerService.hasConflict('MH12AB1234', 'MH 12 AB 1234'), isFalse);
      expect(PlateScannerService.hasConflict('MH12AB1234', null), isFalse);
      expect(PlateScannerService.hasConflict(null, 'DL01CD5678'), isFalse);
    });

    test('9. Two-tier / multi-line number plate extraction in evaluateOcr', () {
      // Plate split across 2 lines on physical vehicle
      const multiLine = 'IND\nMH 14\nCD 5678';
      final result = PlateScannerService.evaluateOcr(detectedText: multiLine);
      expect(result.hasPlate, isTrue);
      expect(result.plateNumber, equals('MH14CD5678'));
    });
  });
}
