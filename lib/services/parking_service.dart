import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../models/parking_record_model.dart';
import '../models/vehicle_type.dart';
import 'cloudinary_service.dart';
import 'plate_scanner_service.dart';

/// Thrown when a vehicle is already parked with an active ticket.
class VehicleAlreadyParkedException implements Exception {
  final String vehicleNumber;
  const VehicleAlreadyParkedException(this.vehicleNumber);

  @override
  String toString() => 'This vehicle is already parked.';
}

/// Thrown when the parking capacity for the selected vehicle category is full.
class CapacityFullException implements Exception {
  final VehicleType vehicleType;
  const CapacityFullException(this.vehicleType);

  @override
  String toString() => 'Parking capacity is full for ${vehicleType.displayName}.';
}

/// Thrown when a ticket cannot be found in the database.
class TicketNotFoundException implements Exception {
  final String ticketNumber;
  const TicketNotFoundException(this.ticketNumber);

  @override
  String toString() => 'Ticket not found.';
}

/// Thrown when a record is found but is not active (and not exited).
class VehicleNotActiveException implements Exception {
  final String status;
  const VehicleNotActiveException(this.status);

  @override
  String toString() => 'Vehicle is not currently parked.';
}

/// Thrown when a vehicle attempting exit has already exited.
class VehicleAlreadyExitedException implements Exception {
  final String ticketNumber;
  const VehicleAlreadyExitedException(this.ticketNumber);

  @override
  String toString() => 'This vehicle has already exited.';
}

/// Core service managing vehicle entry, photo storage, exit settlements,
/// fee calculations, and live Firestore sync.
class ParkingService {
  final FirebaseFirestore? _customFirestore;
  final CloudinaryService? _customCloudinary;

  ParkingService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinary,
  })  : _customFirestore = firestore,
        _customCloudinary = cloudinary;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  CloudinaryService get _cloudinary => _customCloudinary ?? CloudinaryService();

  /// Checks if a vehicle is already parked with status 'ACTIVE'.
  /// Uses normalized registration number (e.g. MH12AB1234) and also checks
  /// raw uppercase for backward compatibility with existing legacy records.
  Future<bool> isVehicleAlreadyParked(String vehicleNumber) async {
    final cleanNumber = AppFormatters.normalizeVehicleNumber(vehicleNumber);
    if (cleanNumber.isEmpty) return false;

    // 1. Primary check: Query by normalized vehicleNumber
    final query = await _firestore
        .collection('parking_records')
        .where('vehicleNumber', isEqualTo: cleanNumber)
        .where('status', isEqualTo: 'ACTIVE')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return true;
    }

    // 2. Compatibility check with legacy records that might have had spaces/hyphens
    final rawUpper = vehicleNumber.toUpperCase().trim();
    if (rawUpper != cleanNumber) {
      final legacyQuery = await _firestore
          .collection('parking_records')
          .where('vehicleNumber', isEqualTo: rawUpper)
          .where('status', isEqualTo: 'ACTIVE')
          .limit(1)
          .get();
      if (legacyQuery.docs.isNotEmpty) {
        return true;
      }
    }

    // 3. In-memory fallback scan over active records to guarantee compatibility
    // if legacy records contained arbitrary spacing or hyphenation
    try {
      final activeDocs = await _firestore
          .collection('parking_records')
          .where('status', isEqualTo: 'ACTIVE')
          .get();
      for (final doc in activeDocs.docs) {
        final storedNum = doc.data()['vehicleNumber'] as String? ?? '';
        if (AppFormatters.normalizeVehicleNumber(storedNum) == cleanNumber) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Checks available capacity for the specified vehicle type.
  Future<int> getAvailableCapacity(VehicleType type) async {
    int total = type == VehicleType.twoWheeler
        ? AppConstants.getTwoWheelerTotalCapacity()
        : AppConstants.getCarTotalCapacity();

    try {
      final doc = await _firestore.collection('settings').doc('system_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (type == VehicleType.twoWheeler && data['twoWheelerTotalCapacity'] != null) {
          total = (data['twoWheelerTotalCapacity'] as num).toInt();
        } else if (type == VehicleType.fourWheeler && data['carTotalCapacity'] != null) {
          total = (data['carTotalCapacity'] as num).toInt();
        }
      }
    } catch (_) {}

    final query = await _firestore
        .collection('parking_records')
        .where('vehicleType', isEqualTo: type == VehicleType.twoWheeler ? 'twoWheeler' : 'fourWheeler')
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    final occupied = query.docs.length;
    return (total - occupied).clamp(0, total);
  }

  /// Uploads vehicle photo bytes to Cloudinary under `parking_records/{ticketId}/vehicle_photo`.
  Future<CloudinaryUploadResult> uploadVehiclePhoto({
    required String ticketId,
    required Uint8List imageBytes,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    return await _cloudinary.uploadVehiclePhoto(
      ticketId: ticketId,
      imageBytes: imageBytes,
      timeout: timeout,
    );
  }

  /// Generates the next sequential numeric ticket number (e.g. '1001', '1002'...).
  /// Uses a Firestore transaction on `counters/ticket_counter` with collision protection:
  /// - Inspects existing numeric ticket numbers only if the counter document does not exist.
  /// - Candidate = current counter + 1 (starts from 1001 if no prior numeric tickets).
  /// - Verifies the candidate does not already exist as a ticketNumber/ticketId in parking_records.
  /// - If collision exists, increments again until an unused numeric ticket is found.
  /// - Updates the counter document atomically to the assigned number.
  Future<String> generateNextTicketNumber() async {
    final counterRef = _firestore.collection('counters').doc('ticket_counter');

    // 1. If counter document doesn't exist yet, inspect existing parking_records once for initialization
    try {
      final counterSnap = await counterRef.get();
      if (!counterSnap.exists || counterSnap.data() == null) {
        int highestNumeric = 1000;
        try {
          final recordsSnap = await _firestore.collection('parking_records').get();
          for (final doc in recordsSnap.docs) {
            final data = doc.data();
            final tNum = data['ticketNumber'] as String? ?? data['ticketId'] as String? ?? doc.id;
            final parsed = int.tryParse(tNum);
            if (parsed != null && parsed > highestNumeric) {
              highestNumeric = parsed;
            }
          }
        } catch (_) {}

        // Initialize counter document
        await counterRef.set({
          'lastTicketNumber': highestNumeric,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    // 2. Transactionally increment and verify against collision
    return await _firestore.runTransaction<String>((transaction) async {
      final snap = await transaction.get(counterRef);
      int currentCounter = 1000;
      if (snap.exists && snap.data() != null && snap.data()!.containsKey('lastTicketNumber')) {
        currentCounter = (snap.data()!['lastTicketNumber'] as num).toInt();
      }

      int candidate = currentCounter + 1;
      if (candidate < 1001) candidate = 1001;

      // Ensure candidate does not already exist as doc ID or ticketNumber
      bool unusedFound = false;
      while (!unusedFound) {
        final candidateStr = candidate.toString();
        final docRef = _firestore.collection('parking_records').doc(candidateStr);
        final existingDoc = await transaction.get(docRef);

        if (existingDoc.exists) {
          candidate++;
        } else {
          unusedFound = true;
        }
      }

      transaction.set(counterRef, {
        'lastTicketNumber': candidate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return candidate.toString();
    });
  }

  /// Executes vehicle entry with capacity check, duplicate check, photo upload, and atomic Firestore storage.
  Future<ParkingRecord> createVehicleEntry({
    required String vehicleNumber,
    required VehicleType vehicleType,
    Uint8List? vehiclePhotoBytes,
    Uint8List? platePhotoBytes,
    required String customerMobile,
    required String guardUid,
    required String guardName,
    required String guardShift,
    double advanceAmount = 0.0,
    String advancePaymentMethod = 'cash',
    bool isMonthlyPass = false,
    String? monthlyPassId,
  }) async {
    final cleanVehicleNumber = AppFormatters.normalizeVehicleNumber(vehicleNumber);
    final effectiveVehicleNumber = cleanVehicleNumber.isEmpty ? 'NO-PLATE' : cleanVehicleNumber;

    // Pass vehicle pays ₹0 advance
    final effectiveAdvance = isMonthlyPass ? 0.0 : advanceAmount;

    // Execute duplicate and capacity checks concurrently
    final checkResults = await Future.wait([
      cleanVehicleNumber.isNotEmpty
          ? isVehicleAlreadyParked(cleanVehicleNumber)
          : Future.value(false),
      getAvailableCapacity(vehicleType),
    ]);

    final isDuplicate = checkResults[0] as bool;
    final available = checkResults[1] as int;

    if (isDuplicate) {
      throw VehicleAlreadyParkedException(cleanVehicleNumber);
    }

    if (available <= 0) {
      throw CapacityFullException(vehicleType);
    }

    final ticketId = await generateNextTicketNumber();
    final entryTime = DateTime.now();

    // Determine primary and secondary photo bytes (filter out any 1x1 placeholders)
    final realPlatePhoto = (platePhotoBytes != null &&
            platePhotoBytes.isNotEmpty &&
            !PlateScannerService.isPlaceholder(platePhotoBytes))
        ? platePhotoBytes
        : null;
    final realVehiclePhoto = (vehiclePhotoBytes != null &&
            vehiclePhotoBytes.isNotEmpty &&
            !PlateScannerService.isPlaceholder(vehiclePhotoBytes))
        ? vehiclePhotoBytes
        : null;

    final primaryBytes = realPlatePhoto ?? realVehiclePhoto;
    final secondaryBytes = (realPlatePhoto != null && realVehiclePhoto != null)
        ? realVehiclePhoto
        : null;

    String? photoUrl;
    String? vehiclePhotoUrl;
    String? photoPublicId;
    String? photoDeleteToken;

    if (primaryBytes != null && primaryBytes.isNotEmpty) {
      try {
        final uploadResult = await uploadVehiclePhoto(
          ticketId: ticketId,
          imageBytes: primaryBytes,
        );
        photoUrl = uploadResult.secureUrl;
        vehiclePhotoUrl = uploadResult.secureUrl;
        photoPublicId = uploadResult.publicId;
        photoDeleteToken = uploadResult.deleteToken;
      } catch (e) {
        debugPrint('[ParkingService] Primary photo upload warning: $e');
      }
    }

    if (secondaryBytes != null && secondaryBytes.isNotEmpty) {
      try {
        final secondaryUpload = await uploadVehiclePhoto(
          ticketId: '${ticketId}_vehicle',
          imageBytes: secondaryBytes,
        );
        vehiclePhotoUrl = secondaryUpload.secureUrl;
      } catch (e) {
        debugPrint('[ParkingService] Secondary photo upload warning: $e');
      }
    }

    try {
      final record = ParkingRecord(
        id: ticketId,
        ticketId: ticketId,
        ticketNumber: ticketId,
        vehicleNumber: effectiveVehicleNumber,
        vehicleType: vehicleType,
        customerMobile: customerMobile.trim(),
        entryTime: entryTime,
        status: 'ACTIVE',
        entryGuardUid: guardUid,
        entryGuardName: guardName,
        entryShiftId: guardShift,
        entryShift: guardShift,
        advanceAmount: effectiveAdvance,
        advancePaymentMethod: advancePaymentMethod,
        advanceCollectorGuardUid: effectiveAdvance > 0 ? guardUid : null,
        advanceCollectorGuardName: effectiveAdvance > 0 ? guardName : null,
        advanceCollectorShift: effectiveAdvance > 0 ? guardShift : null,
        photoUrl: photoUrl,
        vehiclePhotoUrl: vehiclePhotoUrl ?? photoUrl,
        photoPublicId: photoPublicId,
        photoDeleteToken: photoDeleteToken,
        photoStorageProvider: 'cloudinary',
        qrReference: ticketId,
        isMonthlyPass: isMonthlyPass,
        monthlyPassId: monthlyPassId,
        createdAt: entryTime,
      );

      final recordMap = record.toFirestore();
      recordMap['entryTime'] = Timestamp.fromDate(entryTime);
      recordMap['createdAt'] = Timestamp.fromDate(entryTime);
      recordMap['vehiclePhotoUrl'] = vehiclePhotoUrl ?? photoUrl;
      recordMap['photoUrl'] = photoUrl;
      recordMap['photoPublicId'] = photoPublicId;
      recordMap['photoDeleteToken'] = photoDeleteToken;
      recordMap['photoStorageProvider'] = 'cloudinary';
      recordMap['updatedAt'] = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      final recordDocRef = _firestore.collection('parking_records').doc(ticketId);
      batch.set(recordDocRef, recordMap);

      if (advanceAmount > 0) {
        final txnDocRef = _firestore.collection('payment_transactions').doc();
        batch.set(txnDocRef, {
          'ticketId': ticketId,
          'vehicleNumber': cleanVehicleNumber,
          'amount': advanceAmount,
          'paymentMethod': advancePaymentMethod.toLowerCase(),
          'paymentType': 'ADVANCE',
          'guardUid': guardUid,
          'guardName': guardName,
          'shift': guardShift,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  /// Detects whether a query string looks like a parking ticket number.
  /// Matches digits-only query or legacy "TKT-" query.
  static bool isTicketQuery(String query) => AppFormatters.isTicketQuery(query);

  /// Looks up a specific ticket for vehicle exit (exact full ticket).
  /// Throws:
  /// - [TicketNotFoundException] ("Ticket not found.") if ticket doesn't exist
  /// - [VehicleAlreadyExitedException] ("This vehicle has already exited.") if record status is EXITED
  /// - [VehicleNotActiveException] ("Vehicle is not currently parked.") if record status is not ACTIVE
  Future<ParkingRecord> lookupTicketForExit(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      throw const TicketNotFoundException('');
    }

    final isLegacy = AppFormatters.isLegacyTicketQuery(trimmed);
    final cleanTicket = isLegacy ? trimmed.toUpperCase() : trimmed;

    ParkingRecord? record;

    // 1. Direct document lookup by ticket ID / doc ID
    try {
      final doc = await _firestore.collection('parking_records').doc(cleanTicket).get();
      if (doc.exists && doc.data() != null) {
        record = ParkingRecord.fromFirestore(doc);
      }
    } catch (_) {}

    // 2. Query by ticketNumber field
    if (record == null) {
      final query = await _firestore
          .collection('parking_records')
          .where('ticketNumber', isEqualTo: cleanTicket)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        record = ParkingRecord.fromFirestore(query.docs.first);
      }
    }

    // 3. Query by ticketId field
    if (record == null) {
      final query = await _firestore
          .collection('parking_records')
          .where('ticketId', isEqualTo: cleanTicket)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        record = ParkingRecord.fromFirestore(query.docs.first);
      }
    }

    // 4. Query by qrReference field
    if (record == null) {
      final query = await _firestore
          .collection('parking_records')
          .where('qrReference', isEqualTo: cleanTicket)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        record = ParkingRecord.fromFirestore(query.docs.first);
      }
    }

    if (record == null) {
      throw TicketNotFoundException(cleanTicket);
    }

    if (record.status == 'EXITED') {
      throw VehicleAlreadyExitedException(record.ticketNumber);
    }

    if (record.status != 'ACTIVE') {
      throw VehicleNotActiveException(record.status);
    }

    return record;
  }

  /// Searches active tickets for exit.
  /// Detects query type:
  /// - Numeric query (1-4 digits or full numeric ticket):
  ///   Matches the END of numeric ticketNumber for ACTIVE records.
  ///   If no active matches found, checks if an exact matching record exists and throws
  ///   VehicleAlreadyExitedException (if EXITED) or VehicleNotActiveException (if non-active),
  ///   or TicketNotFoundException if ticket doesn't exist.
  /// - Legacy ticket query (TKT-...):
  ///   Exact lookup via lookupTicketForExit.
  Future<List<ParkingRecord>> searchTicketsForExit(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      throw const TicketNotFoundException('');
    }

    final isLegacy = AppFormatters.isLegacyTicketQuery(trimmed);

    final activeMatches = await searchActiveVehicles(trimmed);
    if (activeMatches.isNotEmpty) {
      return activeMatches;
    }

    // If no active matches found, check if an exact ticket or vehicle exists in Firestore to give precise feedback
    ParkingRecord? exactRecord;
    final lookupKey = isLegacy ? trimmed.toUpperCase() : trimmed;
    try {
      final doc = await _firestore.collection('parking_records').doc(lookupKey).get();
      if (doc.exists && doc.data() != null) {
        exactRecord = ParkingRecord.fromFirestore(doc);
      }
    } catch (_) {}

    if (exactRecord == null) {
      final q = await _firestore
          .collection('parking_records')
          .where('ticketNumber', isEqualTo: lookupKey)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        exactRecord = ParkingRecord.fromFirestore(q.docs.first);
      }
    }

    if (exactRecord == null && isLegacy) {
      final qId = await _firestore
          .collection('parking_records')
          .where('ticketId', isEqualTo: lookupKey)
          .limit(1)
          .get();
      if (qId.docs.isNotEmpty) {
        exactRecord = ParkingRecord.fromFirestore(qId.docs.first);
      }
    }

    if (exactRecord == null) {
      final qVeh = await _firestore
          .collection('parking_records')
          .where('vehicleNumber', isEqualTo: AppFormatters.normalizeVehicleNumber(trimmed))
          .limit(1)
          .get();
      if (qVeh.docs.isNotEmpty) {
        exactRecord = ParkingRecord.fromFirestore(qVeh.docs.first);
      }
    }

    if (exactRecord != null) {
      if (exactRecord.status == 'EXITED') {
        throw VehicleAlreadyExitedException(exactRecord.ticketNumber);
      }
      if (!exactRecord.isActive) {
        throw VehicleNotActiveException(exactRecord.status);
      }
    }

    throw TicketNotFoundException(trimmed);
  }

  /// Searches currently ACTIVE parking records by either Ticket Number or Vehicle Number.
  /// Detects query type before searching:
  /// - IF query is numeric-only:
  ///     Searches BOTH:
  ///     1. Vehicle number suffix (e.g. '5656', '656', '56', '6' matches 'MH23ER5656')
  ///     2. Numeric ticket number suffix/exact match (e.g. '4', '04', '004', '1004' matches '1004')
  /// - IF query starts with TKT-:
  ///     Searches legacy ticket number only (exact normalized lookup).
  /// - OTHERWISE:
  ///     Searches normalized vehicle number.
  Future<List<ParkingRecord>> searchActiveVehicles(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return [];

    final isNumeric = AppFormatters.isNumericTicketQuery(trimmed);
    final isLegacy = AppFormatters.isLegacyTicketQuery(trimmed);

    if (isNumeric) {
      // NUMERIC QUERY: Search BOTH vehicle number suffix AND numeric ticket number suffix/exact match
      final Set<String> foundIds = {};
      final List<ParkingRecord> results = [];

      try {
        final activeSnap = await _firestore
            .collection('parking_records')
            .where('status', isEqualTo: 'ACTIVE')
            .get();

        debugPrint('[ParkingService] searchActiveVehicles numeric query="$trimmed". Fetched ${activeSnap.docs.length} ACTIVE docs.');

        for (final doc in activeSnap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          final normVehicle = AppFormatters.normalizeVehicleNumber(r.vehicleNumber);
          final tNum = r.ticketNumber.trim();
          final tId = r.ticketId.trim();
          final qr = r.qrReference?.trim() ?? '';

          // Suffix match against normalized vehicle registration (e.g. MH23ER5656 ends with 5656, 656, 56, 6)
          final matchesVehicleSuffix = normVehicle.endsWith(trimmed);

          // Suffix or exact match against numeric ticket number (e.g. 1004 ends with 1004, 004, 04, 4)
          final matchesTicket = (AppFormatters.isNumericTicketQuery(tNum) && tNum.endsWith(trimmed)) ||
              (AppFormatters.isNumericTicketQuery(tId) && tId.endsWith(trimmed)) ||
              (AppFormatters.isNumericTicketQuery(qr) && qr.endsWith(trimmed)) ||
              (AppFormatters.isNumericTicketQuery(r.id) && r.id.endsWith(trimmed));

          debugPrint('[ParkingService] Doc ${doc.id}: vehicle="${r.vehicleNumber}" (norm="$normVehicle"), ticket="$tNum", status="${r.status}" -> vehMatch=$matchesVehicleSuffix, tktMatch=$matchesTicket');

          if (matchesVehicleSuffix || matchesTicket) {
            if (foundIds.add(r.id)) {
              results.add(r);
            }
          }
        }
      } catch (e) {
        debugPrint('[ParkingService] Error searching active vehicles (numeric): $e');
      }

      debugPrint('[ParkingService] Numeric search "$trimmed" returned ${results.length} active match(es).');

      // Sort results deterministically: exact ticket match first, then vehicle number suffix, then entry time
      results.sort((a, b) {
        final aExactTicket = a.ticketNumber == trimmed;
        final bExactTicket = b.ticketNumber == trimmed;
        if (aExactTicket && !bExactTicket) return -1;
        if (!aExactTicket && bExactTicket) return 1;

        final aNorm = AppFormatters.normalizeVehicleNumber(a.vehicleNumber);
        final bNorm = AppFormatters.normalizeVehicleNumber(b.vehicleNumber);
        final aExactVehicle = aNorm == trimmed;
        final bExactVehicle = bNorm == trimmed;
        if (aExactVehicle && !bExactVehicle) return -1;
        if (!aExactVehicle && bExactVehicle) return 1;

        return b.entryTime.compareTo(a.entryTime);
      });

      return results;
    } else if (isLegacy) {
      // LEGACY TICKET SEARCH: normalize ONLY by trim + uppercase (preserve hyphens)
      final cleanTicket = trimmed.toUpperCase();
      final Set<String> foundIds = {};
      final List<ParkingRecord> results = [];

      // 1. Direct document check
      try {
        final doc = await _firestore.collection('parking_records').doc(cleanTicket).get();
        if (doc.exists && doc.data() != null) {
          final r = ParkingRecord.fromFirestore(doc);
          if (r.isActive && foundIds.add(r.id)) {
            results.add(r);
          }
        }
      } catch (_) {}

      // 2. Query ticketNumber
      if (results.isEmpty) {
        final snap = await _firestore
            .collection('parking_records')
            .where('ticketNumber', isEqualTo: cleanTicket)
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in snap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          if (foundIds.add(r.id)) {
            results.add(r);
          }
        }
      }

      // 3. Query ticketId
      if (results.isEmpty) {
        final snapId = await _firestore
            .collection('parking_records')
            .where('ticketId', isEqualTo: cleanTicket)
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in snapId.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          if (foundIds.add(r.id)) {
            results.add(r);
          }
        }
      }

      // 4. Query qrReference
      if (results.isEmpty) {
        final qrSnap = await _firestore
            .collection('parking_records')
            .where('qrReference', isEqualTo: cleanTicket)
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in qrSnap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          if (foundIds.add(r.id)) {
            results.add(r);
          }
        }
      }

      // 5. In-memory fallback scan over active records to guarantee lookup
      if (results.isEmpty) {
        try {
          final activeSnap = await _firestore
              .collection('parking_records')
              .where('status', isEqualTo: 'ACTIVE')
              .get();
          for (final doc in activeSnap.docs) {
            final r = ParkingRecord.fromFirestore(doc);
            final storedTicket = r.ticketNumber.toUpperCase();
            final storedQr = r.qrReference?.toUpperCase() ?? '';
            if (storedTicket == cleanTicket ||
                storedQr == cleanTicket ||
                r.id.toUpperCase() == cleanTicket) {
              if (foundIds.add(r.id)) {
                results.add(r);
              }
            }
          }
        } catch (_) {}
      }

      return results;
    } else {
      // Vehicle number search: normalize spaces and hyphens
      final cleanVehicle = AppFormatters.normalizeVehicleNumber(trimmed);
      final rawUpper = trimmed.toUpperCase();

      final Set<String> foundIds = {};
      final List<ParkingRecord> results = [];

      // 1. Query by normalized vehicleNumber
      if (cleanVehicle.isNotEmpty) {
        final snap = await _firestore
            .collection('parking_records')
            .where('vehicleNumber', isEqualTo: cleanVehicle)
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in snap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          if (foundIds.add(r.id)) {
            results.add(r);
          }
        }
      }

      // 2. Query by raw uppercase (legacy compatibility)
      if (rawUpper != cleanVehicle && rawUpper.isNotEmpty) {
        final snap = await _firestore
            .collection('parking_records')
            .where('vehicleNumber', isEqualTo: rawUpper)
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in snap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          if (foundIds.add(r.id)) {
            results.add(r);
          }
        }
      }

      // 3. In-memory scan of active vehicles to guarantee compatibility with arbitrary spacing/hyphenation
      try {
        final activeSnap = await _firestore
            .collection('parking_records')
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        for (final doc in activeSnap.docs) {
          final r = ParkingRecord.fromFirestore(doc);
          final normStored = AppFormatters.normalizeVehicleNumber(r.vehicleNumber);
          if (cleanVehicle.isNotEmpty && (normStored == cleanVehicle || normStored.contains(cleanVehicle))) {
            if (foundIds.add(r.id)) {
              results.add(r);
            }
          }
        }
      } catch (_) {}

      return results;
    }
  }

  /// Finds an ACTIVE parking record by QR reference, ticket number, or vehicle registration number.
  /// Normalizes vehicle search query so spaces and hyphens do not prevent lookup.
  Future<ParkingRecord?> findActiveVehicle(String query) async {
    final list = await searchActiveVehicles(query);
    return list.isNotEmpty ? list.first : null;
  }

  /// Atomically settles vehicle exit: updates parking record status to 'EXITED',
  /// calculates final balances, and records the final payment or refund transaction.
  /// Uses a Firestore transaction to strictly prevent duplicate exit attempts.
  Future<ParkingRecord> settleVehicleExit({
    required String ticketId,
    required String vehicleNumber,
    required VehicleType vehicleType,
    required DateTime entryTime,
    required DateTime exitTime,
    required double grossCharge,
    required double advancePaid,
    required double balanceDue,
    required double refundAmount,
    required String paymentMethod,
    required String exitGuardUid,
    required String exitGuardName,
    required String exitGuardShift,
  }) async {
    final docRef = _firestore.collection('parking_records').doc(ticketId);

    final settledRecord = await _firestore.runTransaction<ParkingRecord>((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Parking record $ticketId not found.');
      }

      final currentRecord = ParkingRecord.fromFirestore(snapshot);
      if (currentRecord.status == 'EXITED' || !currentRecord.isActive) {
        throw VehicleAlreadyExitedException(ticketId);
      }

      final bool isPass = currentRecord.isMonthlyPass;
      final effectiveGross = isPass ? 0.0 : grossCharge;
      final effectiveAdvance = isPass ? 0.0 : advancePaid;
      final effectiveBalance = isPass ? 0.0 : balanceDue;
      final effectiveRefund = isPass ? 0.0 : refundAmount;

      // 1. Update parking record to EXITED
      final updateMap = <String, dynamic>{
        'status': 'EXITED',
        'exitTime': Timestamp.fromDate(exitTime),
        'exitGuardUid': exitGuardUid,
        'exitGuardName': exitGuardName,
        'exitShift': exitGuardShift,
        'grossCharge': effectiveGross,
        'advanceAmount': effectiveAdvance,
        'finalAmount': effectiveBalance,
        'paidAmount': effectiveBalance,
        'balanceDue': effectiveBalance,
        'refundAmount': effectiveRefund,
        'paymentMethod': paymentMethod.toLowerCase(),
        'balanceCollectorGuardUid': effectiveBalance > 0 ? exitGuardUid : null,
        'balanceCollectorShift': effectiveBalance > 0 ? exitGuardShift : null,
        'refundCollectorGuardUid': effectiveRefund > 0 ? exitGuardUid : null,
        'refundCollectorShift': effectiveRefund > 0 ? exitGuardShift : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.update(docRef, updateMap);

      // 2. Record payment transaction for final balance collected
      if (effectiveBalance > 0) {
        final txnRef = _firestore.collection('payment_transactions').doc();
        transaction.set(txnRef, {
          'ticketId': ticketId,
          'vehicleNumber': vehicleNumber,
          'amount': effectiveBalance,
          'paymentMethod': paymentMethod.toLowerCase(),
          'paymentType': 'FINAL',
          'guardUid': exitGuardUid,
          'guardName': exitGuardName,
          'shift': exitGuardShift,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Record refund transaction if advance was greater than gross charge
      if (effectiveRefund > 0) {
        final refundTxnRef = _firestore.collection('payment_transactions').doc();
        transaction.set(refundTxnRef, {
          'ticketId': ticketId,
          'vehicleNumber': vehicleNumber,
          'amount': effectiveRefund,
          'paymentMethod': paymentMethod.toLowerCase(),
          'paymentType': 'REFUND',
          'guardUid': exitGuardUid,
          'guardName': exitGuardName,
          'shift': exitGuardShift,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return ParkingRecord(
        id: ticketId,
        ticketNumber: ticketId,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        customerMobile: currentRecord.customerMobile,
        entryTime: entryTime,
        exitTime: exitTime,
        status: 'EXITED',
        entryGuardUid: currentRecord.entryGuardUid,
        entryGuardName: currentRecord.entryGuardName,
        entryShift: currentRecord.entryShift,
        advanceAmount: effectiveAdvance,
        advancePaymentMethod: currentRecord.advancePaymentMethod,
        advanceCollectorGuardUid: currentRecord.advanceCollectorGuardUid,
        advanceCollectorShift: currentRecord.advanceCollectorShift,
        grossCharge: effectiveGross,
        finalCharge: effectiveGross,
        paidAmount: effectiveBalance,
        balanceDue: effectiveBalance,
        refundAmount: effectiveRefund,
        exitGuardUid: exitGuardUid,
        exitGuardName: exitGuardName,
        exitShift: exitGuardShift,
        paymentMethod: paymentMethod.toLowerCase(),
        balanceCollectorGuardUid: effectiveBalance > 0 ? exitGuardUid : null,
        balanceCollectorShift: effectiveBalance > 0 ? exitGuardShift : null,
        refundCollectorGuardUid: effectiveRefund > 0 ? exitGuardUid : null,
        refundCollectorShift: effectiveRefund > 0 ? exitGuardShift : null,
        photoUrl: currentRecord.photoUrl,
        vehiclePhotoUrl: currentRecord.vehiclePhotoUrl,
        storagePath: currentRecord.storagePath,
        photoPublicId: currentRecord.photoPublicId,
        photoStorageProvider: currentRecord.photoStorageProvider,
        photoCleanupStatus: currentRecord.photoCleanupStatus,
        photoDeleteToken: currentRecord.photoDeleteToken,
        qrReference: currentRecord.qrReference,
        isMonthlyPass: currentRecord.isMonthlyPass,
        monthlyPassId: currentRecord.monthlyPassId,
        createdAt: currentRecord.createdAt,
        updatedAt: exitTime,
      );
    });

    // 4. CRITICAL PHOTO LIFECYCLE: Remote photo deletion runs ONLY AFTER authoritative exit succeeds.
    // If the exit transaction above threw any exception, execution never reaches here and the photo remains.
    bool cleanupSuccess = false;
    try {
      cleanupSuccess = await cleanupExitedVehiclePhoto(
        ticketId: settledRecord.ticketNumber,
        publicId: settledRecord.photoPublicId,
        photoUrl: settledRecord.photoUrl,
        deleteToken: settledRecord.photoDeleteToken,
      );
    } catch (e) {
      debugPrint('[ParkingService] Non-fatal photo cleanup error: $e');
    }

    if (cleanupSuccess) {
      return settledRecord.copyWith(
        clearPhoto: true,
        photoCleanupStatus: 'DELETED',
      );
    } else {
      return settledRecord.copyWith(
        photoCleanupStatus: 'PENDING',
      );
    }
  }

  /// Safely cleans up the vehicle photo asset after authoritative exit has committed.
  ///
  /// - Evicts from local/in-memory Flutter image cache.
  /// - Invokes Cloudinary deletion using exact stored publicId.
  /// - Clears photo references in Firestore (photoUrl: null, vehiclePhotoUrl: null, photoPublicId: null).
  /// - Sets photoCleanupStatus to 'DELETED' upon success, or 'PENDING' / 'FAILED' on failure.
  /// - Safe and idempotent: returns immediately if publicId is empty or already deleted.
  /// - Crucially: NEVER throws to callers, guaranteeing vehicle exit remains successful.
  Future<bool> cleanupExitedVehiclePhoto({
    required String ticketId,
    required String? publicId,
    String? photoUrl,
    String? deleteToken,
  }) async {
    final cleanPublicId = publicId?.trim() ?? '';
    final cleanPhotoUrl = photoUrl?.trim() ?? '';

    // 1. Evict from local / network image cache immediately
    if (cleanPhotoUrl.isNotEmpty) {
      try {
        PaintingBinding.instance.imageCache.evict(NetworkImage(cleanPhotoUrl));
      } catch (_) {}
    }

    final docRef = _firestore.collection('parking_records').doc(ticketId);

    // If already empty or cleaned up, return idempotent true
    if (cleanPublicId.isEmpty && cleanPhotoUrl.isEmpty) {
      try {
        await docRef.update({
          'photoUrl': null,
          'vehiclePhotoUrl': null,
          'photoPublicId': null,
          'photoDeleteToken': null,
          'storagePath': null,
          'photoCleanupStatus': 'DELETED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return true;
    }

    try {
      // 2. Perform remote Cloudinary asset deletion using exact publicId
      bool deleted = false;
      if (cleanPublicId.isNotEmpty) {
        deleted = await _cloudinary.deleteVehiclePhoto(
          publicId: cleanPublicId,
          deleteToken: deleteToken,
        );
      } else {
        deleted = true;
      }

      if (deleted) {
        // 3. Clear photo references from Firestore
        await docRef.update({
          'photoUrl': null,
          'vehiclePhotoUrl': null,
          'photoPublicId': null,
          'photoDeleteToken': null,
          'storagePath': null,
          'photoCleanupStatus': 'DELETED',
          'photoCleanedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[ParkingService] Photo for ticket $ticketId cleaned up successfully.');
        return true;
      } else {
        // Deletion didn't complete (e.g. pending backend processing)
        await docRef.update({
          'photoCleanupStatus': 'PENDING',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return false;
      }
    } catch (e) {
      // Photo deletion failure MUST NOT break or rollback exit
      debugPrint('[ParkingService] Remote photo cleanup failed for ticket $ticketId: $e. Marked as PENDING for retry.');
      try {
        await docRef.update({
          'photoCleanupStatus': 'PENDING',
          'photoCleanupError': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return false;
    }
  }

  /// Retries cleaning up any photos marked as PENDING or FAILED.
  Future<int> retryPendingPhotoCleanups() async {
    int cleaned = 0;
    try {
      final snap = await _firestore
          .collection('parking_records')
          .where('status', isEqualTo: 'EXITED')
          .where('photoCleanupStatus', isEqualTo: 'PENDING')
          .limit(20)
          .get();

      for (final doc in snap.docs) {
        final rec = ParkingRecord.fromFirestore(doc);
        final pubId = rec.photoPublicId;
        if (pubId != null && pubId.isNotEmpty) {
          final ok = await cleanupExitedVehiclePhoto(
            ticketId: rec.ticketNumber,
            publicId: pubId,
            photoUrl: rec.photoUrl,
            deleteToken: rec.photoDeleteToken,
          );
          if (ok) cleaned++;
        }
      }
    } catch (e) {
      debugPrint('[ParkingService] Error retrying photo cleanups: $e');
    }
    return cleaned;
  }

  Stream<List<ParkingRecord>> watchActiveVehicles({
    String? searchQuery,
    VehicleType? filterType,
    bool onlyWithAdvance = false,
  }) {
    return _firestore
        .collection('parking_records')
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
      var records = snapshot.docs.map((doc) => ParkingRecord.fromFirestore(doc)).toList();
      records.sort((a, b) => b.entryTime.compareTo(a.entryTime));

      if (filterType != null) {
        records = records.where((r) => r.vehicleType == filterType).toList();
      }

      if (onlyWithAdvance) {
        records = records.where((r) => r.advanceAmount > 0).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryRaw = searchQuery.toUpperCase().trim();
        final isTicket = isTicketQuery(searchQuery);

        records = records.where((r) {
          if (isTicket) {
            return r.ticketNumber.toUpperCase().contains(queryRaw) ||
                (r.qrReference != null && r.qrReference!.toUpperCase().contains(queryRaw));
          } else {
            final queryNormalized = AppFormatters.normalizeVehicleNumber(searchQuery);
            final recVehicleNormalized = AppFormatters.normalizeVehicleNumber(r.vehicleNumber);
            return (queryNormalized.isNotEmpty && recVehicleNormalized.contains(queryNormalized)) ||
                r.vehicleNumber.toUpperCase().contains(queryRaw) ||
                r.ticketNumber.toUpperCase().contains(queryRaw);
          }
        }).toList();
      }

      return records;
    });
  }
}
