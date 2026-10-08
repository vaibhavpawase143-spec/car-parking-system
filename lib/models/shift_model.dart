import 'package:cloud_firestore/cloud_firestore.dart';

/// Shift states representing the lifecycle of an admin-assigned 8-hour shift.
enum ShiftStatus {
  assigned,
  active,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case ShiftStatus.assigned:
        return 'ASSIGNED';
      case ShiftStatus.active:
        return 'ACTIVE';
      case ShiftStatus.completed:
        return 'COMPLETED';
      case ShiftStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

/// Authoritative Shift Model representing an Admin-scheduled fixed 8-hour shift.
class ShiftModel {
  static const int standardDurationHours = 8;

  final String shiftId;
  final String? scheduleId;
  final String guardId;
  final String? guardUid;
  final String? guardEmail;
  final String guardName;
  final DateTime shiftDate;
  final DateTime startTime;
  final DateTime endTime;
  final int durationHours;
  final String status; // 'ASSIGNED', 'ACTIVE', 'COMPLETED', 'CANCELLED'
  final String? cancellationReason;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final String? startedBy;
  final String? endedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShiftModel({
    required this.shiftId,
    this.scheduleId,
    required this.guardId,
    this.guardUid,
    this.guardEmail,
    required this.guardName,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    this.durationHours = standardDurationHours,
    this.status = 'ASSIGNED',
    this.cancellationReason,
    this.actualStartTime,
    this.actualEndTime,
    this.startedBy,
    this.endedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Safely parses a dynamic field into a local [DateTime].
  static DateTime parseDateTime(dynamic value, [DateTime? fallback]) {
    if (value == null) return (fallback ?? DateTime.now()).toLocal();
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return (fallback ?? DateTime.now()).toLocal();
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) return parsed.toLocal();

      // Check format "DD MMM YYYY" e.g. "26 Sep 2026" or "26 September 2026"
      const monthMap = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      };

      // Match "DD MMM YYYY" with optional time "HH:mm" or "hh:mm AM/PM"
      final dateNameMatch = RegExp(r'^(\d{1,2})[\s\-\/]([a-zA-Z]+)[\s\-\/](\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?)?', caseSensitive: false).firstMatch(clean);
      if (dateNameMatch != null) {
        final d = int.parse(dateNameMatch.group(1)!);
        final mStr = dateNameMatch.group(2)!.toLowerCase();
        final y = int.parse(dateNameMatch.group(3)!);
        final m = monthMap[mStr] ?? 1;
        var hour = dateNameMatch.group(4) != null ? int.parse(dateNameMatch.group(4)!) : 0;
        final minute = dateNameMatch.group(5) != null ? int.parse(dateNameMatch.group(5)!) : 0;
        final amPm = dateNameMatch.group(7)?.toUpperCase();
        if (amPm == 'PM' && hour < 12) hour += 12;
        if (amPm == 'AM' && hour == 12) hour = 0;
        return DateTime(y, m, d, hour, minute).toLocal();
      }

      // Check format "YYYY-MM-DD" or "DD/MM/YYYY" or "DD-MM-YYYY"
      final parts = clean.split(RegExp(r'[-/\s]'));
      if (parts.length >= 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p0 > 1000) {
            return DateTime(p0, p1, p2).toLocal();
          } else if (p2 > 1000) {
            return DateTime(p2, p1, p0).toLocal();
          }
        }
      }

      // Check if string is only a time like "05:30 AM" or "13:30"
      final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$', caseSensitive: false).firstMatch(clean);
      if (timeMatch != null) {
        var hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final amPm = timeMatch.group(4)?.toUpperCase();
        if (amPm == 'PM' && hour < 12) hour += 12;
        if (amPm == 'AM' && hour == 12) hour = 0;
        final base = fallback ?? DateTime.now();
        return DateTime(base.year, base.month, base.day, hour, minute).toLocal();
      }
    }
    return (fallback ?? DateTime.now()).toLocal();
  }

  /// Automatically derives the live shift status based on scheduled timestamps or explicit Admin lifecycle state.
  ShiftStatus get effectiveStatus {
    final sUpper = status.toUpperCase().trim();
    if (sUpper == 'CANCELLED') {
      return ShiftStatus.cancelled;
    }
    if (sUpper == 'COMPLETED') {
      return ShiftStatus.completed;
    }
    final now = DateTime.now();
    if (sUpper == 'ACTIVE') {
      // If actualEndTime is set or shift scheduled time has passed, treat as completed
      if (actualEndTime != null || now.isAfter(endTime)) {
        return ShiftStatus.completed;
      }
      return ShiftStatus.active;
    }
    if (now.isBefore(startTime)) {
      return ShiftStatus.assigned;
    } else if (now.isBefore(endTime)) {
      return ShiftStatus.active;
    } else {
      return ShiftStatus.completed;
    }
  }

  bool get isUpcoming => effectiveStatus == ShiftStatus.assigned;
  bool get isActive => effectiveStatus == ShiftStatus.active;
  bool get isCompleted => effectiveStatus == ShiftStatus.completed;
  bool get isCancelled => effectiveStatus == ShiftStatus.cancelled;

  /// Returns a human-friendly shift name (e.g. 'Shift 1', 'Shift 2', 'Shift 3') based on standard 8-hour windows.
  String get displayShiftName {
    final startHour = startTime.hour;
    if (startHour >= 5 && startHour < 13) {
      return 'Shift 1';
    } else if (startHour >= 13 && startHour < 21) {
      return 'Shift 2';
    } else {
      return 'Shift 3';
    }
  }

  /// Time elapsed since shift started (clamped between 0 and duration).
  Duration get timeElapsed {
    final now = DateTime.now();
    if (now.isBefore(startTime)) {
      return Duration.zero;
    }
    if (now.isAfter(endTime)) {
      return endTime.difference(startTime);
    }
    return now.difference(startTime);
  }

  /// Time remaining until shift completion (clamped between 0 and duration).
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isBefore(startTime)) {
      return endTime.difference(startTime);
    }
    if (now.isAfter(endTime)) {
      return Duration.zero;
    }
    return endTime.difference(now);
  }

  /// Creates a Shift with configurable duration (8, 9, 10 hours) and automatically calculated end time.
  factory ShiftModel.createShiftWithDuration({
    required String shiftId,
    required String guardId,
    String? guardUid,
    String? guardEmail,
    required String guardName,
    required DateTime shiftDate,
    required DateTime startTime,
    int durationHours = standardDurationHours,
  }) {
    final endTime = startTime.add(Duration(hours: durationHours));
    return ShiftModel(
      shiftId: shiftId,
      guardId: guardId,
      guardUid: guardUid ?? guardId,
      guardEmail: guardEmail,
      guardName: guardName,
      shiftDate: DateTime(shiftDate.year, shiftDate.month, shiftDate.day),
      startTime: startTime,
      endTime: endTime,
      durationHours: durationHours,
      status: 'ASSIGNED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Creates an 8-hour Shift with automatically calculated end time.
  factory ShiftModel.create8HourShift({
    required String shiftId,
    required String guardId,
    String? guardUid,
    String? guardEmail,
    required String guardName,
    required DateTime shiftDate,
    required DateTime startTime,
  }) {
    return ShiftModel.createShiftWithDuration(
      shiftId: shiftId,
      guardId: guardId,
      guardUid: guardUid,
      guardEmail: guardEmail,
      guardName: guardName,
      shiftDate: shiftDate,
      startTime: startTime,
      durationHours: standardDurationHours,
    );
  }

  factory ShiftModel.fromMap(Map<String, dynamic> data, String id) {
    final sDate = parseDateTime(data['shiftDate']);
    var sTime = parseDateTime(data['startTime'], sDate);

    // If startTime had only time components or legacy year < 2000, align with shiftDate
    if (sTime.year < 2000) {
      sTime = DateTime(sDate.year, sDate.month, sDate.day, sTime.hour, sTime.minute);
    }

    final durationHours = (data['durationHours'] as num?)?.toInt() ?? standardDurationHours;

    // Authoritative end time derived from start time + durationHours
    var eTime = sTime.add(Duration(hours: durationHours));

    if (data['endTime'] != null) {
      final parsedEndTime = parseDateTime(data['endTime'], eTime);
      final diffHours = parsedEndTime.difference(sTime).inHours;
      // Accept custom stored endTime only if it is forward in time and within valid shift duration bounds (6 to 14 hours)
      if (parsedEndTime.isAfter(sTime) && diffHours >= 6 && diffHours <= 14) {
        eTime = parsedEndTime;
      }
    }

    final rawGuardId = (data['guardId'] ?? data['guardUid'] ?? '').toString().trim();
    final rawGuardUid = (data['guardUid'] ?? data['guardId'] ?? '').toString().trim();
    final rawGuardEmail = (data['guardEmail'] ?? data['email'] ?? '').toString().trim();

    return ShiftModel(
      shiftId: id,
      scheduleId: data['scheduleId']?.toString().trim(),
      guardId: rawGuardId.isNotEmpty ? rawGuardId : rawGuardUid,
      guardUid: rawGuardUid.isNotEmpty ? rawGuardUid : null,
      guardEmail: rawGuardEmail.isNotEmpty ? rawGuardEmail : null,
      guardName: data['guardName'] as String? ?? 'Guard',
      shiftDate: DateTime(sDate.year, sDate.month, sDate.day),
      startTime: sTime,
      endTime: eTime,
      durationHours: durationHours,
      status: data['status'] as String? ?? 'ASSIGNED',
      cancellationReason: data['cancellationReason'] as String?,
      actualStartTime: data['actualStartTime'] != null ? parseDateTime(data['actualStartTime']) : null,
      actualEndTime: data['actualEndTime'] != null ? parseDateTime(data['actualEndTime']) : null,
      startedBy: data['startedBy'] as String?,
      endedBy: data['endedBy'] as String?,
      createdAt: data['createdAt'] != null ? parseDateTime(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? parseDateTime(data['updatedAt']) : null,
    );
  }

  factory ShiftModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ShiftModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shiftId': shiftId,
      if (scheduleId != null) 'scheduleId': scheduleId,
      'guardId': guardId,
      if (guardUid != null) 'guardUid': guardUid,
      if (guardEmail != null) 'guardEmail': guardEmail,
      'guardName': guardName,
      'shiftDate': Timestamp.fromDate(DateTime(shiftDate.year, shiftDate.month, shiftDate.day)),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationHours': durationHours,
      'status': status,
      'cancellationReason': cancellationReason,
      if (actualStartTime != null) 'actualStartTime': Timestamp.fromDate(actualStartTime!),
      if (actualEndTime != null) 'actualEndTime': Timestamp.fromDate(actualEndTime!),
      if (startedBy != null) 'startedBy': startedBy,
      if (endedBy != null) 'endedBy': endedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ShiftModel copyWith({
    String? scheduleId,
    String? guardId,
    String? guardUid,
    String? guardEmail,
    String? guardName,
    DateTime? shiftDate,
    DateTime? startTime,
    DateTime? endTime,
    int? durationHours,
    String? status,
    String? cancellationReason,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    String? startedBy,
    String? endedBy,
  }) {
    return ShiftModel(
      shiftId: shiftId,
      scheduleId: scheduleId ?? this.scheduleId,
      guardId: guardId ?? this.guardId,
      guardUid: guardUid ?? this.guardUid,
      guardEmail: guardEmail ?? this.guardEmail,
      guardName: guardName ?? this.guardName,
      shiftDate: shiftDate ?? this.shiftDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationHours: durationHours ?? this.durationHours,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      startedBy: startedBy ?? this.startedBy,
      endedBy: endedBy ?? this.endedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Holds real operational statistics for a specific shift.
class ShiftStats {
  final int entriesCount;
  final int exitsCount;
  final double totalCollection;
  final double cashCollection;
  final double upiCollection;

  const ShiftStats({
    required this.entriesCount,
    required this.exitsCount,
    required this.totalCollection,
    required this.cashCollection,
    required this.upiCollection,
  });

  static const ShiftStats zero = ShiftStats(
    entriesCount: 0,
    exitsCount: 0,
    totalCollection: 0.0,
    cashCollection: 0.0,
    upiCollection: 0.0,
  );
}
