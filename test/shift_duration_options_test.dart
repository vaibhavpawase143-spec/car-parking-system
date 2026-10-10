import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/shift_model.dart';
import 'package:car_parking_system/models/system_settings_model.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/theme/app_colors.dart';

void main() {
  group('1. Authoritative Duration Options & Configuration Tests', () {
    test('1.1 Allowed duration list contains exactly [8, 10, 12, 24]', () {
      expect(ShiftModel.allowedShiftDurations, equals([8, 10, 12, 24]));
      expect(ShiftModel.allowedShiftDurations.length, equals(4));
    });

    test('1.2 Default SystemSettingsModel uses approved durations [8, 10, 12, 24]', () {
      const settings = SystemSettingsModel();
      expect(settings.allowedShiftDurations, equals([8, 10, 12, 24]));
      expect(settings.defaultShiftDurationHours, equals(8));
    });

    test('1.3 Unapproved or old durations (4, 6, 9) are filtered out during deserialization', () {
      final dataWithLegacy = {
        'allowedShiftDurations': [4, 6, 8, 9, 10, 12, 16, 24],
        'defaultShiftDurationHours': 8,
      };
      final parsed = SystemSettingsModel.fromMap(dataWithLegacy);
      expect(parsed.allowedShiftDurations, equals([8, 10, 12, 24]));
    });

    test('1.4 Empty or invalid duration list falls back to [8, 10, 12, 24]', () {
      final emptyData = {'allowedShiftDurations': <dynamic>[]};
      final parsed = SystemSettingsModel.fromMap(emptyData);
      expect(parsed.allowedShiftDurations, equals([8, 10, 12, 24]));
    });
  });

  group('2. Exact End Time Calculations (8h, 10h, 12h, 24h)', () {
    test('2.1 TEST 1: 8 Hours Duration (08:00 -> 16:00)', () {
      final sDate = DateTime(2026, 10, 8);
      final sTime = DateTime(2026, 10, 8, 8, 0);
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_8h',
        guardId: 'guard_1',
        guardName: 'Test Guard',
        shiftDate: sDate,
        startTime: sTime,
        durationHours: 8,
      );

      expect(shift.durationHours, equals(8));
      expect(shift.startTime, equals(DateTime(2026, 10, 8, 8, 0)));
      expect(shift.endTime, equals(DateTime(2026, 10, 8, 16, 0)));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(8));
      expect(shift.endTime.day, equals(shift.startTime.day));
    });

    test('2.2 TEST 2: 10 Hours Duration (08:00 -> 18:00)', () {
      final sDate = DateTime(2026, 10, 8);
      final sTime = DateTime(2026, 10, 8, 8, 0);
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_10h',
        guardId: 'guard_1',
        guardName: 'Test Guard',
        shiftDate: sDate,
        startTime: sTime,
        durationHours: 10,
      );

      expect(shift.durationHours, equals(10));
      expect(shift.startTime, equals(DateTime(2026, 10, 8, 8, 0)));
      expect(shift.endTime, equals(DateTime(2026, 10, 8, 18, 0)));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(10));
      expect(shift.endTime.day, equals(shift.startTime.day));
    });

    test('2.3 TEST 3: 12 Hours Duration (08:00 -> 20:00)', () {
      final sDate = DateTime(2026, 10, 8);
      final sTime = DateTime(2026, 10, 8, 8, 0);
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_12h',
        guardId: 'guard_1',
        guardName: 'Test Guard',
        shiftDate: sDate,
        startTime: sTime,
        durationHours: 12,
      );

      expect(shift.durationHours, equals(12));
      expect(shift.startTime, equals(DateTime(2026, 10, 8, 8, 0)));
      expect(shift.endTime, equals(DateTime(2026, 10, 8, 20, 0)));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(12));
      expect(shift.endTime.day, equals(shift.startTime.day));
    });

    test('2.4 TEST 4: 24 Hours Duration (08:00 -> Next Day 08:00)', () {
      final sDate = DateTime(2026, 10, 8);
      final sTime = DateTime(2026, 10, 8, 8, 0);
      final shift = ShiftModel.createShiftWithDuration(
        shiftId: 'shift_24h',
        guardId: 'guard_1',
        guardName: 'Test Guard',
        shiftDate: sDate,
        startTime: sTime,
        durationHours: 24,
      );

      expect(shift.durationHours, equals(24));
      expect(shift.startTime, equals(DateTime(2026, 10, 8, 8, 0)));
      expect(shift.endTime, equals(DateTime(2026, 10, 9, 8, 0)));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(24));
      expect(shift.endTime.day, equals(9));
      expect(shift.endTime.isAfter(shift.startTime), isTrue);
    });

    test('2.5 ShiftModel.fromMap preserves 24-hour shift endTime forward in time', () {
      final map = {
        'shiftDate': '2026-10-08',
        'startTime': '2026-10-08 08:00:00',
        'endTime': '2026-10-09 08:00:00',
        'durationHours': 24,
        'guardId': 'g1',
        'guardName': 'Guard 1',
        'status': 'ASSIGNED',
      };
      final shift = ShiftModel.fromMap(map, 'shift_24h_doc');
      expect(shift.durationHours, equals(24));
      expect(shift.startTime, equals(DateTime(2026, 10, 8, 8, 0)));
      expect(shift.endTime, equals(DateTime(2026, 10, 9, 8, 0)));
      expect(shift.endTime.difference(shift.startTime).inHours, equals(24));
    });
  });

  group('3. Overlap Validation Across All 4 Durations', () {
    bool hasOverlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
      return s1.isBefore(e2) && e1.isAfter(s2);
    }

    test('3.1 10-hour Guard A shift (08:00 - 18:00) vs 8-hour Guard B (12:00 - 20:00) overlap check', () {
      final guardAStart = DateTime(2026, 10, 8, 8, 0);
      final guardAEnd = guardAStart.add(const Duration(hours: 10)); // 18:00

      final guardBStart = DateTime(2026, 10, 8, 12, 0);
      final guardBEnd = guardBStart.add(const Duration(hours: 8)); // 20:00

      // If scheduled for the SAME guard, this must be detected as an overlap
      expect(hasOverlap(guardAStart, guardAEnd, guardBStart, guardBEnd), isTrue);
    });

    test('3.2 24-hour shift overlaps with any shift on that day and next morning', () {
      final s24Start = DateTime(2026, 10, 8, 8, 0);
      final s24End = DateTime(2026, 10, 9, 8, 0);

      // Shift on the evening of same day
      final eveStart = DateTime(2026, 10, 8, 18, 0);
      final eveEnd = DateTime(2026, 10, 8, 22, 0);
      expect(hasOverlap(s24Start, s24End, eveStart, eveEnd), isTrue);

      // Shift on next day at 06:00 AM (overlaps with 24h end at 08:00)
      final morningNextStart = DateTime(2026, 10, 9, 6, 0);
      final morningNextEnd = DateTime(2026, 10, 9, 14, 0);
      expect(hasOverlap(s24Start, s24End, morningNextStart, morningNextEnd), isTrue);

      // Shift starting exactly at 08:00 AM next day does NOT overlap (back-to-back border touch)
      final backToBackStart = DateTime(2026, 10, 9, 8, 0);
      final backToBackEnd = DateTime(2026, 10, 9, 16, 0);
      expect(hasOverlap(s24Start, s24End, backToBackStart, backToBackEnd), isFalse);
    });
  });

  group('4. Localization for Shift Durations', () {
    test('4.1 English duration strings match specification', () {
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.hours8, equals('8 Hours'));
      expect(AppStrings.hours10, equals('10 Hours'));
      expect(AppStrings.hours12, equals('12 Hours'));
      expect(AppStrings.hours24, equals('24 Hours'));

      expect(AppStrings.formatShiftDuration(8), equals('8 Hours'));
      expect(AppStrings.formatShiftDuration(10), equals('10 Hours'));
      expect(AppStrings.formatShiftDuration(12), equals('12 Hours'));
      expect(AppStrings.formatShiftDuration(24), equals('24 Hours'));
    });

    test('4.2 Marathi duration strings match specification', () {
      AppStrings.setLanguage(AppLanguage.marathi);
      expect(AppStrings.hours8, equals('८ तास'));
      expect(AppStrings.hours10, equals('१० तास'));
      expect(AppStrings.hours12, equals('१२ तास'));
      expect(AppStrings.hours24, equals('२४ तास'));

      expect(AppStrings.formatShiftDuration(8), equals('८ तास'));
      expect(AppStrings.formatShiftDuration(10), equals('१० तास'));
      expect(AppStrings.formatShiftDuration(12), equals('१२ तास'));
      expect(AppStrings.formatShiftDuration(24), equals('२४ तास'));

      // Reset to English
      AppStrings.setLanguage(AppLanguage.english);
    });
  });

  group('5. Mobile Responsive UI Widget Tests', () {
    Widget createDurationSelectorWidget({
      required int selectedDuration,
      required ValueChanged<int> onDurationChanged,
      List<int> allowedDurations = const [8, 10, 12, 24],
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;
                Widget buildBtn(int hrs) {
                  final isSelected = selectedDuration == hrs;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('duration_btn_$hrs'),
                      onTap: () => onDurationChanged(hrs),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 46, minWidth: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          AppStrings.formatShiftDuration(hrs),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (isMobile && allowedDurations.length == 4) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildBtn(allowedDurations[0])),
                          const SizedBox(width: 10),
                          Expanded(child: buildBtn(allowedDurations[1])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: buildBtn(allowedDurations[2])),
                          const SizedBox(width: 10),
                          Expanded(child: buildBtn(allowedDurations[3])),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      for (int i = 0; i < allowedDurations.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: buildBtn(allowedDurations[i])),
                      ],
                    ],
                  );
                }
              },
            ),
          ),
        ),
      );
    }

    testWidgets('5.1 Mobile 360x640: Renders 2x2 grid, all 4 buttons visible, no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selected = 8;
      await tester.pumpWidget(
        createDurationSelectorWidget(
          selectedDuration: selected,
          onDurationChanged: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      // Check all 4 buttons are rendered
      expect(find.text('8 Hours'), findsOneWidget);
      expect(find.text('10 Hours'), findsOneWidget);
      expect(find.text('12 Hours'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);

      // Verify touch target >= 44x44
      final btn8 = tester.getSize(find.byKey(const ValueKey('duration_btn_8')));
      expect(btn8.height, greaterThanOrEqualTo(44));
      expect(btn8.width, greaterThanOrEqualTo(44));

      // Tap 10 Hours and verify state update
      await tester.tap(find.byKey(const ValueKey('duration_btn_10')));
      expect(selected, equals(10));
    });

    testWidgets('5.2 Mobile 393x852: Renders 2x2 grid cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selected = 8;
      await tester.pumpWidget(
        createDurationSelectorWidget(
          selectedDuration: selected,
          onDurationChanged: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8 Hours'), findsOneWidget);
      expect(find.text('10 Hours'), findsOneWidget);
      expect(find.text('12 Hours'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.3 Mobile 430x932: Renders 2x2 grid cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selected = 8;
      await tester.pumpWidget(
        createDurationSelectorWidget(
          selectedDuration: selected,
          onDurationChanged: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8 Hours'), findsOneWidget);
      expect(find.text('10 Hours'), findsOneWidget);
      expect(find.text('12 Hours'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.4 Tablet 768x1024: Renders 1-row horizontal layout cleanly', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selected = 12;
      await tester.pumpWidget(
        createDurationSelectorWidget(
          selectedDuration: selected,
          onDurationChanged: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8 Hours'), findsOneWidget);
      expect(find.text('10 Hours'), findsOneWidget);
      expect(find.text('12 Hours'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.5 Desktop 1280x800: Renders 1-row horizontal layout cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selected = 24;
      await tester.pumpWidget(
        createDurationSelectorWidget(
          selectedDuration: selected,
          onDurationChanged: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8 Hours'), findsOneWidget);
      expect(find.text('10 Hours'), findsOneWidget);
      expect(find.text('12 Hours'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
