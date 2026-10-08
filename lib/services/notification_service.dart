import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Service managing reusable in-app global notifications.
class NotificationService {
  final FirebaseFirestore? _injectedFirestore;

  NotificationService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

  /// Real-time stream of all notifications for a specific user, sorted newest first.
  Stream<List<NotificationModel>> watchUserNotifications(String userId) {
    if (userId.isEmpty) {
      return Stream.value(<NotificationModel>[]);
    }

    try {
      return _firestore
          .collection('notifications')
          .where('recipientUserId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('[NotificationService] Error streaming notifications: $e');
        return <NotificationModel>[];
      });
    } catch (_) {
      return Stream.value(<NotificationModel>[]);
    }
  }

  /// Real-time stream of unread notification count for a specific user.
  Stream<int> watchUnreadCount(String userId) {
    if (userId.isEmpty) {
      return Stream.value(0);
    }

    return watchUserNotifications(userId).map((list) {
      return list.where((n) => !n.isRead).length;
    });
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('[NotificationService] Error marking notification read: $e');
    }
  }

  /// Marks all notifications for a user as read.
  Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) return;

    try {
      final query = await _firestore
          .collection('notifications')
          .where('recipientUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationService] Error marking all notifications read: $e');
    }
  }

  /// Creates a new in-app notification for a user with duplicate prevention for shift and entry alerts.
  Future<NotificationModel> createNotification({
    required String recipientUserId,
    required String title,
    required String message,
    String type = 'system',
    String? relatedEntityId,
  }) async {
    if (relatedEntityId != null && (type == 'shift' || type == 'shift_alert' || type == 'entry_blocked')) {
      try {
        final existing = await _firestore
            .collection('notifications')
            .where('recipientUserId', isEqualTo: recipientUserId)
            .where('relatedEntityId', isEqualTo: relatedEntityId)
            .where('type', isEqualTo: type)
            .where('isRead', isEqualTo: false)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return NotificationModel.fromFirestore(existing.docs.first);
        }
      } catch (_) {}
    }

    final docRef = _firestore.collection('notifications').doc();
    final notification = NotificationModel(
      notificationId: docRef.id,
      recipientUserId: recipientUserId,
      title: title,
      message: message,
      type: type,
      isRead: false,
      relatedEntityId: relatedEntityId,
      createdAt: DateTime.now(),
    );

    await docRef.set(notification.toFirestore());
    return notification;
  }
}
