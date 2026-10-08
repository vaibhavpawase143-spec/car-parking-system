import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an authorized Guard in the Car Parking Management System.
class GuardModel {
  final String uid;
  final String name;
  final String email;
  final String mobile;
  final String role; // Must be 'guard' for guard module access
  final bool isActive;
  final String currentShift; // e.g. 'Shift 1'
  final String shiftStatus; // 'active', 'ended', 'offline'
  final DateTime? shiftStartTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GuardModel({
    required this.uid,
    required this.name,
    required this.email,
    this.mobile = '',
    this.role = 'guard',
    this.isActive = true,
    this.currentShift = 'Shift 1',
    this.shiftStatus = 'active',
    this.shiftStartTime,
    this.createdAt,
    this.updatedAt,
  });

  /// Validates whether this profile has active guard privileges.
  bool get isGuard => role.trim().toLowerCase() == 'guard' && isActive;

  /// Validates whether this profile has active admin privileges.
  bool get isAdmin => role.trim().toLowerCase() == 'admin' && isActive;

  factory GuardModel.fromMap(Map<String, dynamic> data, String id) {
    final rawUid = (data['uid'] as String? ?? id).trim();
    return GuardModel(
      uid: rawUid.isNotEmpty ? rawUid : id,
      name: data['name'] as String? ?? 'Guard',
      email: data['email'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      role: data['role'] as String? ?? 'guard',
      isActive: data['isActive'] as bool? ?? true,
      currentShift: data['currentShift'] as String? ?? 'Shift 1',
      shiftStatus: data['shiftStatus'] as String? ?? 'active',
      shiftStartTime: (data['shiftStartTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory GuardModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return GuardModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'mobile': mobile,
      'role': role,
      'isActive': isActive,
      'currentShift': currentShift,
      'shiftStatus': shiftStatus,
      'shiftStartTime': shiftStartTime != null ? Timestamp.fromDate(shiftStartTime!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GuardModel copyWith({
    String? name,
    String? email,
    String? mobile,
    String? role,
    bool? isActive,
    String? currentShift,
    String? shiftStatus,
    DateTime? shiftStartTime,
  }) {
    return GuardModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      currentShift: currentShift ?? this.currentShift,
      shiftStatus: shiftStatus ?? this.shiftStatus,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
