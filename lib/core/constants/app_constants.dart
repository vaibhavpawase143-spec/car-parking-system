import '../../models/vehicle_type.dart';
import '../../services/settings_service.dart';

/// AppConstants defines system-wide rates, thresholds, and operational limits.
/// Backed dynamically by Firestore `settings/system_config` with verified defaults.
class AppConstants {
  AppConstants._();

  // Application metadata
  static const String appName = 'CAR PARKING SYSTEM';
  static const String companyBrand = 'BIZFLOW';
  static const String guardPortalTitle = 'CAR PARKING SYSTEM';

  // Grace Period in minutes (0 = No free parking period; customer pays 1st hour charge immediately)
  static const int gracePeriodMinutes = 0;

  // Two-Wheeler Approved Default Rates
  static const double twoWheelerFirstHourRate = 20.0;
  static const double twoWheelerAdditionalHourRate = 5.0;
  static const double twoWheeler12HourCap = 60.0;
  static const double twoWheelerMonthlyRate = 600.0;

  // Four-Wheeler Approved Default Rates
  static const double fourWheelerFirstHourRate = 50.0;
  static const double fourWheelerAdditionalHourRate = 10.0;
  static const double fourWheeler12HourCapProposed = 150.0;
  static const double fourWheelerMonthlyRateProposed = 1500.0;

  // Parking slot capacity defaults
  static const int defaultCarTotalCapacity = 100;
  static const int defaultTwoWheelerTotalCapacity = 150;

  // Dynamic Rate lookups by VehicleType
  static double getFirstHourRate(VehicleType type) {
    try {
      final s = SettingsService.instance.currentSettings;
      switch (type) {
        case VehicleType.twoWheeler:
          return s.twoWheelerFirstHourRate;
        case VehicleType.fourWheeler:
          return s.fourWheelerFirstHourRate;
      }
    } catch (_) {
      switch (type) {
        case VehicleType.twoWheeler:
          return twoWheelerFirstHourRate;
        case VehicleType.fourWheeler:
          return fourWheelerFirstHourRate;
      }
    }
  }

  static double getAdditionalHourRate(VehicleType type) {
    try {
      final s = SettingsService.instance.currentSettings;
      switch (type) {
        case VehicleType.twoWheeler:
          return s.twoWheelerAdditionalHourRate;
        case VehicleType.fourWheeler:
          return s.fourWheelerAdditionalHourRate;
      }
    } catch (_) {
      switch (type) {
        case VehicleType.twoWheeler:
          return twoWheelerAdditionalHourRate;
        case VehicleType.fourWheeler:
          return fourWheelerAdditionalHourRate;
      }
    }
  }

  static double get12HourCap(VehicleType type) {
    try {
      final s = SettingsService.instance.currentSettings;
      switch (type) {
        case VehicleType.twoWheeler:
          return s.twoWheeler12HourCap;
        case VehicleType.fourWheeler:
          return s.fourWheeler12HourCap;
      }
    } catch (_) {
      switch (type) {
        case VehicleType.twoWheeler:
          return twoWheeler12HourCap;
        case VehicleType.fourWheeler:
          return fourWheeler12HourCapProposed;
      }
    }
  }

  static double getMonthlyRate(VehicleType type) {
    try {
      final s = SettingsService.instance.currentSettings;
      switch (type) {
        case VehicleType.twoWheeler:
          return s.twoWheelerMonthlyRate;
        case VehicleType.fourWheeler:
          return s.fourWheelerMonthlyRate;
      }
    } catch (_) {
      switch (type) {
        case VehicleType.twoWheeler:
          return twoWheelerMonthlyRate;
        case VehicleType.fourWheeler:
          return fourWheelerMonthlyRateProposed;
      }
    }
  }

  static int getCarTotalCapacity() {
    try {
      return SettingsService.instance.currentSettings.carTotalCapacity;
    } catch (_) {
      return defaultCarTotalCapacity;
    }
  }

  static int getTwoWheelerTotalCapacity() {
    try {
      return SettingsService.instance.currentSettings.twoWheelerTotalCapacity;
    } catch (_) {
      return defaultTwoWheelerTotalCapacity;
    }
  }

  // Shift names
  static const List<String> shifts = [
    'Shift 1 (Morning: 06:00 - 14:00)',
    'Shift 2 (Evening: 14:00 - 22:00)',
    'Shift 3 (Night: 22:00 - 06:00)',
  ];
}
