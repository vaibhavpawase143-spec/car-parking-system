import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/formatters.dart';
import 'vehicle_type.dart';

/// Represents a parking session record stored in Firestore ('parking_records').
class ParkingRecord {
  final String id;
  final String ticketId;
  final String ticketNumber;
  final String vehicleNumber;
  final VehicleType vehicleType;
  final String customerMobile;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status; // 'ACTIVE', 'EXITED'
  final String entryGuardUid;
  final String entryGuardName;
  final String? entryShiftId;
  final String entryShift;
  final double advanceAmount;
  final String advancePaymentMethod;
  final String? advanceCollectorGuardUid;
  final String? advanceCollectorGuardName;
  final String? advanceCollectorShift;
  final double? grossCharge;
  final double? finalCharge;
  final double? paidAmount;
  final double? balanceDue;
  final double? refundAmount;
  final String? exitGuardUid;
  final String? exitGuardName;
  final String? exitShift;
  final String? paymentMethod;
  final String? balanceCollectorGuardUid;
  final String? balanceCollectorShift;
  final String? refundCollectorGuardUid;
  final String? refundCollectorShift;
  final String? photoUrl;
  final String? vehiclePhotoUrl;
  final String? storagePath;
  final String? photoPublicId;
  final String? photoStorageProvider;
  final String? photoCleanupStatus; // 'PENDING', 'DELETED', 'FAILED'
  final String? photoDeleteToken;
  final String? qrReference;
  final bool isMonthlyPass;
  final String? monthlyPassId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ParkingRecord({
    required this.id,
    String? ticketId,
    required this.ticketNumber,
    required this.vehicleNumber,
    required this.vehicleType,
    this.customerMobile = '',
    required this.entryTime,
    this.exitTime,
    this.status = 'ACTIVE',
    required this.entryGuardUid,
    required this.entryGuardName,
    this.entryShiftId,
    required this.entryShift,
    this.advanceAmount = 0.0,
    this.advancePaymentMethod = 'cash',
    this.advanceCollectorGuardUid,
    this.advanceCollectorGuardName,
    this.advanceCollectorShift,
    this.grossCharge,
    this.finalCharge,
    this.paidAmount,
    this.balanceDue,
    this.refundAmount,
    this.exitGuardUid,
    this.exitGuardName,
    this.exitShift,
    this.paymentMethod,
    this.balanceCollectorGuardUid,
    this.balanceCollectorShift,
    this.refundCollectorGuardUid,
    this.refundCollectorShift,
    this.photoUrl,
    this.vehiclePhotoUrl,
    this.storagePath,
    this.photoPublicId,
    this.photoStorageProvider,
    this.photoCleanupStatus,
    this.photoDeleteToken,
    this.qrReference,
    this.isMonthlyPass = false,
    this.monthlyPassId,
    this.createdAt,
    this.updatedAt,
  }) : ticketId = ticketId ?? ticketNumber;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isExited => status.toUpperCase() == 'EXITED';
  String get guardName => entryGuardName;
  String get guardUid => entryGuardUid;

  ParkingRecord copyWith({
    String? id,
    String? ticketId,
    String? ticketNumber,
    String? vehicleNumber,
    VehicleType? vehicleType,
    String? customerMobile,
    DateTime? entryTime,
    DateTime? exitTime,
    String? status,
    String? entryGuardUid,
    String? entryGuardName,
    String? entryShiftId,
    String? entryShift,
    double? advanceAmount,
    String? advancePaymentMethod,
    String? advanceCollectorGuardUid,
    String? advanceCollectorGuardName,
    String? advanceCollectorShift,
    double? grossCharge,
    double? finalCharge,
    double? paidAmount,
    double? balanceDue,
    double? refundAmount,
    String? exitGuardUid,
    String? exitGuardName,
    String? exitShift,
    String? paymentMethod,
    String? balanceCollectorGuardUid,
    String? balanceCollectorShift,
    String? refundCollectorGuardUid,
    String? refundCollectorShift,
    String? photoUrl,
    String? vehiclePhotoUrl,
    String? storagePath,
    String? photoPublicId,
    String? photoStorageProvider,
    String? photoCleanupStatus,
    String? photoDeleteToken,
    String? qrReference,
    bool? isMonthlyPass,
    String? monthlyPassId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearPhoto = false,
  }) {
    return ParkingRecord(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      customerMobile: customerMobile ?? this.customerMobile,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      status: status ?? this.status,
      entryGuardUid: entryGuardUid ?? this.entryGuardUid,
      entryGuardName: entryGuardName ?? this.entryGuardName,
      entryShiftId: entryShiftId ?? this.entryShiftId,
      entryShift: entryShift ?? this.entryShift,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      advancePaymentMethod: advancePaymentMethod ?? this.advancePaymentMethod,
      advanceCollectorGuardUid: advanceCollectorGuardUid ?? this.advanceCollectorGuardUid,
      advanceCollectorGuardName: advanceCollectorGuardName ?? this.advanceCollectorGuardName,
      advanceCollectorShift: advanceCollectorShift ?? this.advanceCollectorShift,
      grossCharge: grossCharge ?? this.grossCharge,
      finalCharge: finalCharge ?? this.finalCharge,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      refundAmount: refundAmount ?? this.refundAmount,
      exitGuardUid: exitGuardUid ?? this.exitGuardUid,
      exitGuardName: exitGuardName ?? this.exitGuardName,
      exitShift: exitShift ?? this.exitShift,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      balanceCollectorGuardUid: balanceCollectorGuardUid ?? this.balanceCollectorGuardUid,
      balanceCollectorShift: balanceCollectorShift ?? this.balanceCollectorShift,
      refundCollectorGuardUid: refundCollectorGuardUid ?? this.refundCollectorGuardUid,
      refundCollectorShift: refundCollectorShift ?? this.refundCollectorShift,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      vehiclePhotoUrl: clearPhoto ? null : (vehiclePhotoUrl ?? this.vehiclePhotoUrl),
      storagePath: clearPhoto ? null : (storagePath ?? this.storagePath),
      photoPublicId: clearPhoto ? null : (photoPublicId ?? this.photoPublicId),
      photoStorageProvider: clearPhoto ? null : (photoStorageProvider ?? this.photoStorageProvider),
      photoCleanupStatus: photoCleanupStatus ?? this.photoCleanupStatus,
      photoDeleteToken: clearPhoto ? null : (photoDeleteToken ?? this.photoDeleteToken),
      qrReference: qrReference ?? this.qrReference,
      isMonthlyPass: isMonthlyPass ?? this.isMonthlyPass,
      monthlyPassId: monthlyPassId ?? this.monthlyPassId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ParkingRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeString = data['vehicleType'] as String? ?? 'fourWheeler';
    final vehicleType = typeString == 'twoWheeler'
        ? VehicleType.twoWheeler
        : VehicleType.fourWheeler;

    final tId = data['ticketId'] as String? ?? data['ticketNumber'] as String? ?? doc.id;
    final photo = data['vehiclePhotoUrl'] as String? ?? data['photoUrl'] as String?;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return ParkingRecord(
      id: doc.id,
      ticketId: tId,
      ticketNumber: tId,
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
      vehicleType: vehicleType,
      customerMobile: data['customerMobile'] as String? ?? '',
      entryTime: parseDate(data['entryTime']) ?? DateTime.now(),
      exitTime: parseDate(data['exitTime']),
      status: data['status'] as String? ?? 'ACTIVE',
      entryGuardUid: data['entryGuardUid'] as String? ?? '',
      entryGuardName: data['entryGuardName'] as String? ?? 'Guard',
      entryShiftId: data['entryShiftId'] as String? ?? data['entryShift'] as String? ?? 'Shift 1',
      entryShift: data['entryShift'] as String? ?? 'Shift 1',
      advanceAmount: (data['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      advancePaymentMethod: data['advancePaymentMethod'] as String? ?? 'cash',
      advanceCollectorGuardUid: data['advanceCollectorGuardUid'] as String?,
      advanceCollectorGuardName: data['advanceCollectorGuardName'] as String?,
      advanceCollectorShift: data['advanceCollectorShift'] as String?,
      grossCharge: (data['grossCharge'] as num?)?.toDouble(),
      finalCharge: (data['finalCharge'] as num?)?.toDouble(),
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? (data['finalAmount'] as num?)?.toDouble(),
      balanceDue: (data['balanceDue'] as num?)?.toDouble(),
      refundAmount: (data['refundAmount'] as num?)?.toDouble(),
      exitGuardUid: data['exitGuardUid'] as String?,
      exitGuardName: data['exitGuardName'] as String?,
      exitShift: data['exitShift'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      balanceCollectorGuardUid: data['balanceCollectorGuardUid'] as String?,
      balanceCollectorShift: data['balanceCollectorShift'] as String?,
      refundCollectorGuardUid: data['refundCollectorGuardUid'] as String?,
      refundCollectorShift: data['refundCollectorShift'] as String?,
      photoUrl: photo,
      vehiclePhotoUrl: photo,
      storagePath: data['storagePath'] as String?,
      photoPublicId: data['photoPublicId'] as String?,
      photoStorageProvider: data['photoStorageProvider'] as String? ?? 'cloudinary',
      photoCleanupStatus: data['photoCleanupStatus'] as String?,
      photoDeleteToken: data['photoDeleteToken'] as String?,
      qrReference: data['qrReference'] as String?,
      isMonthlyPass: data['isMonthlyPass'] as bool? ?? false,
      monthlyPassId: data['monthlyPassId'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketId': ticketId,
      'ticketNumber': ticketNumber,
      'vehicleNumber': vehicleNumber,
      'normalizedVehicleNumber': AppFormatters.normalizeVehicleNumber(vehicleNumber),
      'vehicleType': vehicleType == VehicleType.twoWheeler ? 'twoWheeler' : 'fourWheeler',
      'customerMobile': customerMobile,
      'entryTime': Timestamp.fromDate(entryTime),
      'exitTime': exitTime != null ? Timestamp.fromDate(exitTime!) : null,
      'status': status,
      'entryGuardUid': entryGuardUid,
      'entryGuardName': entryGuardName,
      'entryShiftId': entryShiftId ?? entryShift,
      'entryShift': entryShift,
      'advanceAmount': advanceAmount,
      'advancePaymentMethod': advancePaymentMethod,
      'advanceCollectorGuardUid': advanceCollectorGuardUid,
      'advanceCollectorGuardName': advanceCollectorGuardName,
      'advanceCollectorShift': advanceCollectorShift,
      'storagePath': storagePath,
      'photoPublicId': photoPublicId,
      'photoStorageProvider': photoStorageProvider ?? 'cloudinary',
      'photoCleanupStatus': photoCleanupStatus,
      'photoDeleteToken': photoDeleteToken,
      'vehiclePhotoUrl': vehiclePhotoUrl ?? photoUrl,
      'photoUrl': photoUrl ?? vehiclePhotoUrl,
      'qrReference': qrReference,
      'isMonthlyPass': isMonthlyPass,
      'monthlyPassId': monthlyPassId,
      'grossCharge': grossCharge,
      'finalCharge': finalCharge,
      'finalAmount': paidAmount,
      'paidAmount': paidAmount,
      'balanceDue': balanceDue,
      'refundAmount': refundAmount,
      'exitGuardUid': exitGuardUid,
      'exitGuardName': exitGuardName,
      'exitShift': exitShift,
      'paymentMethod': paymentMethod,
      'balanceCollectorGuardUid': balanceCollectorGuardUid,
      'balanceCollectorShift': balanceCollectorShift,
      'refundCollectorGuardUid': refundCollectorGuardUid,
      'refundCollectorShift': refundCollectorShift,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
