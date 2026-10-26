import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import 'shift_model.dart';

/// Holds all dynamic operational parameters, vehicle rate charts,
/// slot capacities, and business profile metadata.
class SystemSettingsModel {
  final int carTotalCapacity;
  final int twoWheelerTotalCapacity;

  final double twoWheelerFirstHourRate;
  final double twoWheelerAdditionalHourRate;
  final double twoWheeler12HourCap;
  final double twoWheelerMonthlyRate;

  final double fourWheelerFirstHourRate;
  final double fourWheelerAdditionalHourRate;
  final double fourWheeler12HourCap;
  final double fourWheelerMonthlyRate;

  final String marathiName;
  final String englishName;
  final String marathiAuthority;
  final String marathiLocation;
  final String englishLocation;
  final String mobile;
  final String marathiMobile;
  final bool bizflowBrandingEnabled;

  final int defaultShiftDurationHours;
  final List<int> allowedShiftDurations;
  final bool cashEnabled;
  final bool upiEnabled;
  final bool advanceEnabled;
  final bool singleActiveDeviceEnabled;

  // Entry Form Field Visibility & Requiredness
  final bool requireNumberPlate;
  final bool numberPlateVisible;
  final bool requirePlatePhoto;
  final bool platePhotoVisible;
  final bool vehiclePhotoVisible;
  final bool requireVehiclePhoto;
  final bool customerMobileVisible;
  final bool requireCustomerMobile;

  const SystemSettingsModel({
    this.carTotalCapacity = AppConstants.defaultCarTotalCapacity,
    this.twoWheelerTotalCapacity = AppConstants.defaultTwoWheelerTotalCapacity,
    this.twoWheelerFirstHourRate = AppConstants.twoWheelerFirstHourRate,
    this.twoWheelerAdditionalHourRate = AppConstants.twoWheelerAdditionalHourRate,
    this.twoWheeler12HourCap = AppConstants.twoWheeler12HourCap,
    this.twoWheelerMonthlyRate = AppConstants.twoWheelerMonthlyRate,
    this.fourWheelerFirstHourRate = AppConstants.fourWheelerFirstHourRate,
    this.fourWheelerAdditionalHourRate = AppConstants.fourWheelerAdditionalHourRate,
    this.fourWheeler12HourCap = AppConstants.fourWheeler12HourCapProposed,
    this.fourWheelerMonthlyRate = AppConstants.fourWheelerMonthlyRateProposed,
    this.marathiName = 'CAR PARKING SYSTEM',
    this.englishName = 'CAR PARKING SYSTEM',
    this.marathiAuthority = 'म. रा. मा. परिवहन महामंडळाचे अधिकृत वाहनतळ',
    this.marathiLocation = 'संगमनेर बसस्थानक',
    this.englishLocation = 'SANGAMNER BUS STAND',
    this.mobile = '9690793434',
    this.marathiMobile = '९६९०७९३४३४',
    this.bizflowBrandingEnabled = true,
    this.defaultShiftDurationHours = ShiftModel.standardDurationHours,
    this.allowedShiftDurations = ShiftModel.allowedShiftDurations,
    this.cashEnabled = true,
    this.upiEnabled = true,
    this.advanceEnabled = true,
    this.singleActiveDeviceEnabled = true,
    this.requireNumberPlate = false,
    this.numberPlateVisible = true,
    this.requirePlatePhoto = true,
    this.platePhotoVisible = true,
    this.vehiclePhotoVisible = true,
    this.requireVehiclePhoto = false,
    this.customerMobileVisible = true,
    this.requireCustomerMobile = true,
  });

  factory SystemSettingsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) {
      return const SystemSettingsModel();
    }
    final data = doc.data()!;
    return SystemSettingsModel.fromMap(data);
  }

  factory SystemSettingsModel.fromMap(Map<String, dynamic> data) {
    final rawAllowed = data['allowedShiftDurations'];
    List<int> parsedAllowed = List<int>.from(ShiftModel.allowedShiftDurations);
    if (rawAllowed is List) {
      final list = rawAllowed
          .map((e) => (e as num).toInt())
          .where((e) => ShiftModel.allowedShiftDurations.contains(e))
          .toList();
      if (list.isNotEmpty) parsedAllowed = list;
    }

    final rawMName = data['marathiName'] as String?;
    final cleanMName = (rawMName == null || rawMName.contains('जय गणेश') || rawMName.toUpperCase().contains('GANESH'))
        ? 'CAR PARKING SYSTEM'
        : rawMName;

    final rawEName = data['englishName'] as String?;
    final cleanEName = (rawEName == null || rawEName.contains('जय गणेश') || rawEName.toUpperCase().contains('GANESH'))
        ? 'CAR PARKING SYSTEM'
        : rawEName;

    return SystemSettingsModel(
      carTotalCapacity: (data['carTotalCapacity'] as num?)?.toInt() ?? AppConstants.defaultCarTotalCapacity,
      twoWheelerTotalCapacity: (data['twoWheelerTotalCapacity'] as num?)?.toInt() ?? AppConstants.defaultTwoWheelerTotalCapacity,
      twoWheelerFirstHourRate: (data['twoWheelerFirstHourRate'] as num?)?.toDouble() ?? AppConstants.twoWheelerFirstHourRate,
      twoWheelerAdditionalHourRate: (data['twoWheelerAdditionalHourRate'] as num?)?.toDouble() ?? AppConstants.twoWheelerAdditionalHourRate,
      twoWheeler12HourCap: (data['twoWheeler12HourCap'] as num?)?.toDouble() ?? AppConstants.twoWheeler12HourCap,
      twoWheelerMonthlyRate: (data['twoWheelerMonthlyRate'] as num?)?.toDouble() ?? AppConstants.twoWheelerMonthlyRate,
      fourWheelerFirstHourRate: (data['fourWheelerFirstHourRate'] as num?)?.toDouble() ?? AppConstants.fourWheelerFirstHourRate,
      fourWheelerAdditionalHourRate: (data['fourWheelerAdditionalHourRate'] as num?)?.toDouble() ?? AppConstants.fourWheelerAdditionalHourRate,
      fourWheeler12HourCap: (data['fourWheeler12HourCap'] as num?)?.toDouble() ?? AppConstants.fourWheeler12HourCapProposed,
      fourWheelerMonthlyRate: (data['fourWheelerMonthlyRate'] as num?)?.toDouble() ?? AppConstants.fourWheelerMonthlyRateProposed,
      marathiName: cleanMName,
      englishName: cleanEName,
      marathiAuthority: data['marathiAuthority'] as String? ?? 'म. रा. मा. परिवहन महामंडळाचे अधिकृत वाहनतळ',
      marathiLocation: data['marathiLocation'] as String? ?? 'संगमनेर बसस्थानक',
      englishLocation: data['englishLocation'] as String? ?? 'SANGAMNER BUS STAND',
      mobile: data['mobile'] as String? ?? '9690793434',
      marathiMobile: data['marathiMobile'] as String? ?? '९६९०७९३४३४',
      bizflowBrandingEnabled: data['bizflowBrandingEnabled'] as bool? ?? true,
      defaultShiftDurationHours: (data['defaultShiftDurationHours'] as num?)?.toInt() ?? 8,
      allowedShiftDurations: parsedAllowed,
      cashEnabled: data['cashEnabled'] as bool? ?? true,
      upiEnabled: data['upiEnabled'] as bool? ?? true,
      advanceEnabled: data['advanceEnabled'] as bool? ?? true,
      singleActiveDeviceEnabled: data['singleActiveDeviceEnabled'] as bool? ?? true,
      requireNumberPlate: data['requireNumberPlate'] as bool? ?? false,
      numberPlateVisible: data['numberPlateVisible'] as bool? ?? true,
      requirePlatePhoto: data['requirePlatePhoto'] as bool? ?? true,
      platePhotoVisible: data['platePhotoVisible'] as bool? ?? true,
      vehiclePhotoVisible: data['vehiclePhotoVisible'] as bool? ?? true,
      requireVehiclePhoto: data['requireVehiclePhoto'] as bool? ?? false,
      customerMobileVisible: data['customerMobileVisible'] as bool? ?? true,
      requireCustomerMobile: data['requireCustomerMobile'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'carTotalCapacity': carTotalCapacity,
      'twoWheelerTotalCapacity': twoWheelerTotalCapacity,
      'twoWheelerFirstHourRate': twoWheelerFirstHourRate,
      'twoWheelerAdditionalHourRate': twoWheelerAdditionalHourRate,
      'twoWheeler12HourCap': twoWheeler12HourCap,
      'twoWheelerMonthlyRate': twoWheelerMonthlyRate,
      'fourWheelerFirstHourRate': fourWheelerFirstHourRate,
      'fourWheelerAdditionalHourRate': fourWheelerAdditionalHourRate,
      'fourWheeler12HourCap': fourWheeler12HourCap,
      'fourWheelerMonthlyRate': fourWheelerMonthlyRate,
      'marathiName': marathiName,
      'englishName': englishName,
      'marathiAuthority': marathiAuthority,
      'marathiLocation': marathiLocation,
      'englishLocation': englishLocation,
      'mobile': mobile,
      'marathiMobile': marathiMobile,
      'bizflowBrandingEnabled': bizflowBrandingEnabled,
      'defaultShiftDurationHours': defaultShiftDurationHours,
      'allowedShiftDurations': allowedShiftDurations,
      'cashEnabled': cashEnabled,
      'upiEnabled': upiEnabled,
      'advanceEnabled': advanceEnabled,
      'singleActiveDeviceEnabled': singleActiveDeviceEnabled,
      'requireNumberPlate': requireNumberPlate,
      'numberPlateVisible': numberPlateVisible,
      'requirePlatePhoto': requirePlatePhoto,
      'platePhotoVisible': platePhotoVisible,
      'vehiclePhotoVisible': vehiclePhotoVisible,
      'requireVehiclePhoto': requireVehiclePhoto,
      'customerMobileVisible': customerMobileVisible,
      'requireCustomerMobile': requireCustomerMobile,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SystemSettingsModel copyWith({
    int? carTotalCapacity,
    int? twoWheelerTotalCapacity,
    double? twoWheelerFirstHourRate,
    double? twoWheelerAdditionalHourRate,
    double? twoWheeler12HourCap,
    double? twoWheelerMonthlyRate,
    double? fourWheelerFirstHourRate,
    double? fourWheelerAdditionalHourRate,
    double? fourWheeler12HourCap,
    double? fourWheelerMonthlyRate,
    String? marathiName,
    String? englishName,
    String? marathiAuthority,
    String? marathiLocation,
    String? englishLocation,
    String? mobile,
    String? marathiMobile,
    bool? bizflowBrandingEnabled,
    int? defaultShiftDurationHours,
    List<int>? allowedShiftDurations,
    bool? cashEnabled,
    bool? upiEnabled,
    bool? advanceEnabled,
    bool? singleActiveDeviceEnabled,
    bool? requireNumberPlate,
    bool? numberPlateVisible,
    bool? requirePlatePhoto,
    bool? platePhotoVisible,
    bool? vehiclePhotoVisible,
    bool? requireVehiclePhoto,
    bool? customerMobileVisible,
    bool? requireCustomerMobile,
  }) {
    return SystemSettingsModel(
      carTotalCapacity: carTotalCapacity ?? this.carTotalCapacity,
      twoWheelerTotalCapacity: twoWheelerTotalCapacity ?? this.twoWheelerTotalCapacity,
      twoWheelerFirstHourRate: twoWheelerFirstHourRate ?? this.twoWheelerFirstHourRate,
      twoWheelerAdditionalHourRate: twoWheelerAdditionalHourRate ?? this.twoWheelerAdditionalHourRate,
      twoWheeler12HourCap: twoWheeler12HourCap ?? this.twoWheeler12HourCap,
      twoWheelerMonthlyRate: twoWheelerMonthlyRate ?? this.twoWheelerMonthlyRate,
      fourWheelerFirstHourRate: fourWheelerFirstHourRate ?? this.fourWheelerFirstHourRate,
      fourWheelerAdditionalHourRate: fourWheelerAdditionalHourRate ?? this.fourWheelerAdditionalHourRate,
      fourWheeler12HourCap: fourWheeler12HourCap ?? this.fourWheeler12HourCap,
      fourWheelerMonthlyRate: fourWheelerMonthlyRate ?? this.fourWheelerMonthlyRate,
      marathiName: marathiName ?? this.marathiName,
      englishName: englishName ?? this.englishName,
      marathiAuthority: marathiAuthority ?? this.marathiAuthority,
      marathiLocation: marathiLocation ?? this.marathiLocation,
      englishLocation: englishLocation ?? this.englishLocation,
      mobile: mobile ?? this.mobile,
      marathiMobile: marathiMobile ?? this.marathiMobile,
      bizflowBrandingEnabled: bizflowBrandingEnabled ?? this.bizflowBrandingEnabled,
      defaultShiftDurationHours: defaultShiftDurationHours ?? this.defaultShiftDurationHours,
      allowedShiftDurations: allowedShiftDurations ?? this.allowedShiftDurations,
      cashEnabled: cashEnabled ?? this.cashEnabled,
      upiEnabled: upiEnabled ?? this.upiEnabled,
      advanceEnabled: advanceEnabled ?? this.advanceEnabled,
      singleActiveDeviceEnabled: singleActiveDeviceEnabled ?? this.singleActiveDeviceEnabled,
      requireNumberPlate: requireNumberPlate ?? this.requireNumberPlate,
      numberPlateVisible: numberPlateVisible ?? this.numberPlateVisible,
      requirePlatePhoto: requirePlatePhoto ?? this.requirePlatePhoto,
      platePhotoVisible: platePhotoVisible ?? this.platePhotoVisible,
      vehiclePhotoVisible: vehiclePhotoVisible ?? this.vehiclePhotoVisible,
      requireVehiclePhoto: requireVehiclePhoto ?? this.requireVehiclePhoto,
      customerMobileVisible: customerMobileVisible ?? this.customerMobileVisible,
      requireCustomerMobile: requireCustomerMobile ?? this.requireCustomerMobile,
    );
  }
}
