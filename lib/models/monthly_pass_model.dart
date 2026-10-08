import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/formatters.dart';
import 'vehicle_type.dart';

/// Represents a Monthly Pass record in the 'monthly_passes' Firestore collection.
/// Monthly Pass price is strictly fixed at ₹600 with full advance payment.
class MonthlyPassModel {
  static const double fixedPrice = 600.0;

  final String id;
  final String passNumber;
  final String vehicleNumber;
  final String normalizedVehicleNumber;
  final VehicleType vehicleType;
  final String customerName;
  final String customerMobile;
  final DateTime startDate;
  final DateTime endDate;
  final double amount;
  final double amountPaid;
  final double outstandingAmount;
  final String paymentStatus; // 'PAID'
  final String paymentMethod; // 'cash' or 'upi'
  final String status; // 'ACTIVE', 'UPCOMING', 'EXPIRED', 'CANCELLED'
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;

  const MonthlyPassModel({
    required this.id,
    required this.passNumber,
    required this.vehicleNumber,
    required this.normalizedVehicleNumber,
    required this.vehicleType,
    required this.customerName,
    required this.customerMobile,
    required this.startDate,
    required this.endDate,
    this.amount = fixedPrice,
    this.amountPaid = fixedPrice,
    this.outstandingAmount = 0.0,
    this.paymentStatus = 'PAID',
    required this.paymentMethod,
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
  });

  /// Computes dynamic lifecycle status based on current time
  String get dynamicStatus {
    if (status.toUpperCase() == 'CANCELLED') return 'CANCELLED';
    final now = DateTime.now();
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    if (now.isBefore(startDay)) {
      return 'UPCOMING';
    } else if (now.isAfter(endDay)) {
      return 'EXPIRED';
    } else {
      return 'ACTIVE';
    }
  }

  bool get isActive => dynamicStatus == 'ACTIVE';
  bool get isUpcoming => dynamicStatus == 'UPCOMING';
  bool get isExpired => dynamicStatus == 'EXPIRED';

  /// True if the pass is active and expires within the next 7 days
  bool get isExpiringSoon {
    if (!isActive) return false;
    final now = DateTime.now();
    final endDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    final diff = endDay.difference(now);
    return diff.inDays >= 0 && diff.inDays <= 7;
  }

  /// Whether the pass was paid in full with zero outstanding balance
  bool get isFullyPaid => amountPaid >= fixedPrice && outstandingAmount <= 0.0;

  /// Checks if this pass covers a specific timestamp
  bool isValidAt(DateTime checkTime) {
    if (status.toUpperCase() == 'CANCELLED') return false;
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return !checkTime.isBefore(startDay) && !checkTime.isAfter(endDay);
  }

  factory MonthlyPassModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MonthlyPassModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory MonthlyPassModel.fromMap(Map<String, dynamic> data, String id) {
    final typeStr = (data['vehicleType'] as String? ?? 'twoWheeler').toLowerCase();
    final vehicleType = typeStr == 'fourwheeler' || typeStr == 'four_wheeler'
        ? VehicleType.fourWheeler
        : VehicleType.twoWheeler;

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return fallback;
    }

    final rawVehicle = data['vehicleNumber'] as String? ?? '';
    final normalized = (data['normalizedVehicleNumber'] as String? ?? '').isNotEmpty
        ? data['normalizedVehicleNumber'] as String
        : AppFormatters.normalizeVehicleNumber(rawVehicle);

    return MonthlyPassModel(
      id: id,
      passNumber: data['passNumber'] as String? ?? id,
      vehicleNumber: rawVehicle,
      normalizedVehicleNumber: normalized,
      vehicleType: vehicleType,
      customerName: data['customerName'] as String? ?? '',
      customerMobile: data['customerMobile'] as String? ?? '',
      startDate: parseDate(data['startDate'], DateTime.now()),
      endDate: parseDate(data['endDate'], DateTime.now().add(const Duration(days: 30))),
      amount: (data['amount'] as num?)?.toDouble() ?? fixedPrice,
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? fixedPrice,
      outstandingAmount: (data['outstandingAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: (data['paymentStatus'] as String? ?? 'PAID').toUpperCase(),
      paymentMethod: (data['paymentMethod'] as String? ?? 'cash').toLowerCase(),
      status: (data['status'] as String? ?? 'ACTIVE').toUpperCase(),
      createdAt: parseDate(data['createdAt'], DateTime.now()),
      createdBy: data['createdBy'] as String? ?? 'Admin',
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt'], DateTime.now()) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'passNumber': passNumber,
      'vehicleNumber': vehicleNumber,
      'normalizedVehicleNumber': normalizedVehicleNumber,
      'vehicleType': vehicleType == VehicleType.fourWheeler ? 'fourWheeler' : 'twoWheeler',
      'customerName': customerName,
      'customerMobile': customerMobile,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'amount': amount,
      'amountPaid': amountPaid,
      'outstandingAmount': outstandingAmount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'status': dynamicStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MonthlyPassModel copyWith({
    String? id,
    String? passNumber,
    String? vehicleNumber,
    String? normalizedVehicleNumber,
    VehicleType? vehicleType,
    String? customerName,
    String? customerMobile,
    DateTime? startDate,
    DateTime? endDate,
    double? amount,
    double? amountPaid,
    double? outstandingAmount,
    String? paymentStatus,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return MonthlyPassModel(
      id: id ?? this.id,
      passNumber: passNumber ?? this.passNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      normalizedVehicleNumber: normalizedVehicleNumber ?? this.normalizedVehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
