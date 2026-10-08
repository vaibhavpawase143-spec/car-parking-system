import 'package:flutter_test/flutter_test.dart';
import 'package:car_parking_system/models/notification_model.dart';

void main() {
  group('Global In-App Notification System Tests', () {
    test('1. NotificationModel creation and serialization', () {
      final now = DateTime(2026, 9, 25, 12, 0);
      final notif = NotificationModel(
        notificationId: 'notif-101',
        recipientUserId: 'guard-abc',
        title: 'New Shift Assigned',
        message: 'You have been assigned an 8-hour shift on 25/09/2026.',
        type: 'shift',
        isRead: false,
        relatedEntityId: 'shift-101',
        createdAt: now,
      );

      expect(notif.notificationId, equals('notif-101'));
      expect(notif.recipientUserId, equals('guard-abc'));
      expect(notif.title, equals('New Shift Assigned'));
      expect(notif.type, equals('shift'));
      expect(notif.isRead, isFalse);

      final map = notif.toFirestore();
      expect(map['recipientUserId'], equals('guard-abc'));
      expect(map['isRead'], isFalse);
      expect(map['type'], equals('shift'));
    });

    test('2. NotificationModel copyWith updates isRead correctly', () {
      final notif = NotificationModel(
        notificationId: 'notif-102',
        recipientUserId: 'guard-xyz',
        title: 'Vehicle Entry Blocked',
        message: 'No active shift is assigned to you.',
        type: 'entry_blocked',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, isTrue);
      expect(readNotif.notificationId, equals(notif.notificationId));
      expect(readNotif.type, equals('entry_blocked'));
    });

    test('3. Supports multiple generic notification types', () {
      const types = ['shift', 'entry_blocked', 'payment', 'capacity', 'pass_expiry', 'system'];

      for (final t in types) {
        final n = NotificationModel(
          notificationId: 'notif-$t',
          recipientUserId: 'uid-1',
          title: 'Title for $t',
          message: 'Message for $t',
          type: t,
          createdAt: DateTime.now(),
        );
        expect(n.type, equals(t));
      }
    });
  });
}
