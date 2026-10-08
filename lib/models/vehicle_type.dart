import 'package:flutter/material.dart';

/// Supported vehicle categories in the parking system.
enum VehicleType {
  twoWheeler,
  fourWheeler;

  String get displayName {
    switch (this) {
      case VehicleType.twoWheeler:
        return 'Two-Wheeler';
      case VehicleType.fourWheeler:
        return 'Four-Wheeler';
    }
  }

  String get shortLabel {
    switch (this) {
      case VehicleType.twoWheeler:
        return '2W / Bike';
      case VehicleType.fourWheeler:
        return '4W / Car';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.twoWheeler:
        return Icons.two_wheeler;
      case VehicleType.fourWheeler:
        return Icons.directions_car;
    }
  }
}
