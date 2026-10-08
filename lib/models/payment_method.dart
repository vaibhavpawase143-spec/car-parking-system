import 'package:flutter/material.dart';

/// Supported payment methods: Cash and UPI only.
enum PaymentMethod {
  cash,
  upi;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.upi:
        return Icons.qr_code_2;
    }
  }
}
