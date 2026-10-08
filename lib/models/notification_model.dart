import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/localization/app_language.dart';
import '../core/localization/notification_localizer.dart';

/// Reusable global in-app notification model.
class NotificationModel {
  final String notificationId;
  final String recipientUserId;
  final String title;
  final String message;
  final String type; // 'shift', 'entry_blocked', 'payment', 'capacity', 'pass_expiry', 'system'
  final bool isRead;
  final String? relatedEntityId;
  final DateTime createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.recipientUserId,
    required this.title,
    required this.message,
    this.type = 'system',
    this.isRead = false,
    this.relatedEntityId,
    required this.createdAt,
  });

  /// Real-time localized title based on active application language.
  String get localizedTitle => NotificationLocalizer.localizeTitle(this);

  /// Real-time localized message based on active application language.
  String get localizedMessage => NotificationLocalizer.localizeMessage(this);

  /// Real-time localized category tag based on active application language.
  String get localizedCategory => NotificationLocalizer.localizeCategory(type);

  /// Specific language localized title.
  String getLocalizedTitle(AppLanguage language) =>
      NotificationLocalizer.localizeTitle(this, language: language);

  /// Specific language localized message.
  String getLocalizedMessage(AppLanguage language) =>
      NotificationLocalizer.localizeMessage(this, language: language);

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return NotificationModel(
      notificationId: doc.id,
      recipientUserId: data['recipientUserId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'system',
      isRead: data['isRead'] as bool? ?? false,
      relatedEntityId: data['relatedEntityId'] as String?,
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'notificationId': notificationId,
      'recipientUserId': recipientUserId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'relatedEntityId': relatedEntityId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      notificationId: notificationId,
      recipientUserId: recipientUserId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedEntityId: relatedEntityId,
      createdAt: createdAt,
    );
  }
}

