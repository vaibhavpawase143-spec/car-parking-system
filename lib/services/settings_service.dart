import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/config/business_profile.dart';
import '../models/system_settings_model.dart';
import 'audit_service.dart';
import 'notification_service.dart';

/// Central service for streaming, caching, and updating dynamic system configuration.
class SettingsService {
  static final SettingsService instance = SettingsService._internal();

  SettingsService._internal();

  factory SettingsService({FirebaseFirestore? firestore, AuditService? auditService}) {
    if (firestore != null) {
      return SettingsService._custom(firestore, auditService);
    }
    return instance;
  }

  SettingsService._custom(this._customFirestore, this._customAuditService);

  FirebaseFirestore? _customFirestore;
  AuditService? _customAuditService;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  AuditService get _auditService => _customAuditService ?? AuditService(firestore: _firestore);

  SystemSettingsModel _current = const SystemSettingsModel();
  SystemSettingsModel get currentSettings => _current;

  bool _initialized = false;
  StreamSubscription? _sub;

  /// Initializes the settings service and starts listening for Firestore updates.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final doc = await _firestore.collection('settings').doc('system_config').get();
      if (doc.exists && doc.data() != null) {
        _current = SystemSettingsModel.fromFirestore(doc);
        _syncToBusinessProfile(_current);
      }
    } catch (e) {
      debugPrint('[SettingsService] Failed to load initial settings: $e');
    } finally {
      _initialized = true;
    }

    _sub = watchSettings().listen((settings) {
      _current = settings;
      _syncToBusinessProfile(settings);
    }, onError: (e) {
      debugPrint('[SettingsService] Snapshot error on system_config: $e');
    });
  }

  /// Real-time stream of dynamic system settings.
  Stream<SystemSettingsModel> watchSettings() {
    try {
      return _firestore
          .collection('settings')
          .doc('system_config')
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return const SystemSettingsModel();
        }
        final s = SystemSettingsModel.fromFirestore(snapshot);
        _current = s;
        _syncToBusinessProfile(s);
        return s;
      }).handleError((e) {
        debugPrint('[SettingsService] Error watching settings: $e');
        return _current;
      });
    } catch (_) {
      return Stream.value(_current);
    }
  }

  /// Saves updated system configuration and records an audit log.
  Future<void> saveSettings({
    required SystemSettingsModel settings,
    required String adminUid,
    required String adminName,
  }) async {
    // Validation
    if (settings.carTotalCapacity <= 0 || settings.twoWheelerTotalCapacity <= 0) {
      throw ArgumentError('Parking capacity must be greater than zero.');
    }
    if (settings.twoWheelerFirstHourRate < 0 ||
        settings.twoWheelerAdditionalHourRate < 0 ||
        settings.twoWheeler12HourCap < 0 ||
        settings.fourWheelerFirstHourRate < 0 ||
        settings.fourWheelerAdditionalHourRate < 0 ||
        settings.fourWheeler12HourCap < 0) {
      throw ArgumentError('Rates cannot be negative.');
    }
    if (settings.mobile.trim().isEmpty) {
      throw ArgumentError('Business contact number cannot be empty.');
    }

    final docRef = _firestore.collection('settings').doc('system_config');
    await docRef.set(settings.toFirestore(), SetOptions(merge: true));

    _current = settings;
    _syncToBusinessProfile(settings);

    // Audit log
    await _auditService.logAction(
      adminUid: adminUid,
      adminName: adminName,
      action: 'UPDATE_SETTINGS',
      targetEntity: 'settings',
      targetId: 'system_config',
      details: {
        'carCapacity': settings.carTotalCapacity,
        'twoWheelerCapacity': settings.twoWheelerTotalCapacity,
        'twoWheelerRates': '${settings.twoWheelerFirstHourRate}/${settings.twoWheelerAdditionalHourRate}/${settings.twoWheeler12HourCap}',
        'fourWheelerRates': '${settings.fourWheelerFirstHourRate}/${settings.fourWheelerAdditionalHourRate}/${settings.fourWheeler12HourCap}',
        'businessName': settings.englishName,
      },
    );
  }

  /// Updates parking capacity and records audit log + guard notification.
  Future<void> updateCapacity({
    required int fourWheelerCapacity,
    required int twoWheelerCapacity,
    required String adminUid,
    required String adminName,
    int? currentFourWheelerOccupied,
    int? currentTwoWheelerOccupied,
  }) async {
    if (fourWheelerCapacity <= 0 || twoWheelerCapacity <= 0) {
      throw ArgumentError('Parking capacity must be greater than zero.');
    }
    if (currentFourWheelerOccupied != null && fourWheelerCapacity < currentFourWheelerOccupied) {
      throw ArgumentError(
        'Four-Wheeler capacity cannot be less than the current occupied vehicles ($currentFourWheelerOccupied).'
      );
    }
    if (currentTwoWheelerOccupied != null && twoWheelerCapacity < currentTwoWheelerOccupied) {
      throw ArgumentError(
        'Two-Wheeler capacity cannot be less than the current occupied vehicles ($currentTwoWheelerOccupied).'
      );
    }

    final oldCar = _current.carTotalCapacity;
    final oldBike = _current.twoWheelerTotalCapacity;

    final updated = _current.copyWith(
      carTotalCapacity: fourWheelerCapacity,
      twoWheelerTotalCapacity: twoWheelerCapacity,
    );

    final docRef = _firestore.collection('settings').doc('system_config');
    await docRef.set({
      'carTotalCapacity': fourWheelerCapacity,
      'twoWheelerTotalCapacity': twoWheelerCapacity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _current = updated;
    _syncToBusinessProfile(updated);

    // Audit log
    try {
      await _auditService.logAction(
        adminUid: adminUid,
        adminName: adminName,
        action: 'CAPACITY_CHANGED',
        targetEntity: 'settings',
        targetId: 'system_config',
        details: {
          'oldFourWheelerCapacity': oldCar,
          'newFourWheelerCapacity': fourWheelerCapacity,
          'oldTwoWheelerCapacity': oldBike,
          'newTwoWheelerCapacity': twoWheelerCapacity,
        },
      );
    } catch (e) {
      debugPrint('[SettingsService] Failed to log capacity audit: $e');
    }

    // Send notification to guards
    try {
      final notif = NotificationService(firestore: _firestore);
      await notif.createNotification(
        recipientUserId: 'all',
        title: 'Parking Capacity Updated',
        message: 'Parking capacity has been updated by Admin (4W: $fourWheelerCapacity, 2W: $twoWheelerCapacity).',
        type: 'capacity',
        relatedEntityId: 'system_config',
      );
    } catch (e) {
      debugPrint('[SettingsService] Failed to send capacity notification: $e');
    }
  }

  void _syncToBusinessProfile(SystemSettingsModel s) {
    try {
      BusinessProfileController.instance.updateProfile(
        marathiName: s.marathiName,
        englishName: s.englishName,
        marathiLocation: s.marathiLocation,
        englishLocation: s.englishLocation,
        mobile: s.mobile,
        marathiMobile: s.marathiMobile,
        bizflowBrandingEnabled: s.bizflowBrandingEnabled,
      );
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
  }
}
