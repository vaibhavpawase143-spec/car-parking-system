import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a recurring shift schedule.
enum ScheduleStatus {
  active,
  paused,
  completed,
  cancelled;

  String get value => name.toUpperCase();

  static ScheduleStatus fromString(String val) {
    switch (val.trim().toUpperCase()) {
      case 'PAUSED':
        return ScheduleStatus.paused;
      case 'COMPLETED':
        return ScheduleStatus.completed;
      case 'CANCELLED':
        return ScheduleStatus.cancelled;
      default:
        return ScheduleStatus.active;
    }
  }
}

/// Authoritative Recurring Shift Schedule Model.
/// Stores the recurring rule template used to generate individual daily shifts.
class ShiftScheduleModel {
  final String scheduleId;
  final String guardId;
  final String? guardUid;
  final String? guardEmail;
  final String guardName;
  final DateTime startDate;
  final DateTime endDate;
  final int startHour;
  final int startMinute;
  final int durationHours;
  final List<int> weekdays; // 1 = Monday ... 7 = Sunday
  final String status; // 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ShiftScheduleModel({
    required this.scheduleId,
    required this.guardId,
    this.guardUid,
    this.guardEmail,
    required this.guardName,
    required this.startDate,
    required this.endDate,
    required this.startHour,
    required this.startMinute,
    required this.durationHours,
    required this.weekdays,
    this.status = 'ACTIVE',
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isPaused => status.toUpperCase() == 'PAUSED';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  String get timeFormatted {
    final hour = startHour % 12 == 0 ? 12 : startHour % 12;
    final amPm = startHour >= 12 ? 'PM' : 'AM';
    final minuteStr = startMinute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $amPm';
  }

  String get weekdaysFormatted {
    const days = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    if (weekdays.length == 7) return 'Mon-Sun (Everyday)';
    if (weekdays.length == 5 &&
        weekdays.contains(1) &&
        weekdays.contains(2) &&
        weekdays.contains(3) &&
        weekdays.contains(4) &&
        weekdays.contains(5)) {
      return 'Mon-Fri (Weekdays)';
    }
    if (weekdays.length == 2 && weekdays.contains(6) && weekdays.contains(7)) {
      return 'Sat-Sun (Weekends)';
    }
    final sorted = List<int>.from(weekdays)..sort();
    return sorted.map((d) => days[d] ?? '$d').join(', ');
  }

  factory ShiftScheduleModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    final rawDays = data['weekdays'];
    List<int> parsedWeekdays = [1, 2, 3, 4, 5];
    if (rawDays is List) {
      parsedWeekdays = rawDays.map((e) => (e as num).toInt()).toList();
    }

    return ShiftScheduleModel(
      scheduleId: id,
      guardId: (data['guardId'] ?? data['guardUid'] ?? '').toString().trim(),
      guardUid: data['guardUid']?.toString().trim(),
      guardEmail: data['guardEmail']?.toString().trim(),
      guardName: (data['guardName'] ?? 'Guard').toString().trim(),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      startHour: (data['startHour'] as num?)?.toInt() ?? 6,
      startMinute: (data['startMinute'] as num?)?.toInt() ?? 0,
      durationHours: (data['durationHours'] as num?)?.toInt() ?? 8,
      weekdays: parsedWeekdays,
      status: (data['status'] ?? 'ACTIVE').toString().toUpperCase().trim(),
      createdBy: (data['createdBy'] ?? 'Admin').toString().trim(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  factory ShiftScheduleModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ShiftScheduleModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'scheduleId': scheduleId,
      'guardId': guardId,
      if (guardUid != null) 'guardUid': guardUid,
      if (guardEmail != null) 'guardEmail': guardEmail,
      'guardName': guardName,
      'startDate': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
      'endDate': Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)),
      'startHour': startHour,
      'startMinute': startMinute,
      'durationHours': durationHours,
      'weekdays': weekdays,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Represents an exception/skip rule for a specific date in a recurring schedule.
class ScheduleExceptionModel {
  final String exceptionId;
  final String scheduleId;
  final DateTime date;
  final String type; // 'SKIP' or 'OVERRIDE'
  final String? reason;
  final String? overrideGuardId;
  final String? overrideGuardName;
  final String createdBy;
  final DateTime createdAt;

  const ScheduleExceptionModel({
    required this.exceptionId,
    required this.scheduleId,
    required this.date,
    required this.type,
    this.reason,
    this.overrideGuardId,
    this.overrideGuardName,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isSkip => type.toUpperCase() == 'SKIP';
  bool get isOverride => type.toUpperCase() == 'OVERRIDE';

  factory ScheduleExceptionModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    return ScheduleExceptionModel(
      exceptionId: id,
      scheduleId: (data['scheduleId'] ?? '').toString().trim(),
      date: parseDate(data['date']),
      type: (data['type'] ?? 'SKIP').toString().toUpperCase().trim(),
      reason: data['reason']?.toString(),
      overrideGuardId: data['overrideGuardId']?.toString(),
      overrideGuardName: data['overrideGuardName']?.toString(),
      createdBy: (data['createdBy'] ?? 'Admin').toString().trim(),
      createdAt: parseDate(data['createdAt']),
    );
  }

  factory ScheduleExceptionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ScheduleExceptionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'exceptionId': exceptionId,
      'scheduleId': scheduleId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'type': type,
      if (reason != null) 'reason': reason,
      if (overrideGuardId != null) 'overrideGuardId': overrideGuardId,
      if (overrideGuardName != null) 'overrideGuardName': overrideGuardName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
