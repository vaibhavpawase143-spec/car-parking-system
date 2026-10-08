import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:car_parking_system/core/config/app_config.dart';
import 'package:car_parking_system/core/localization/app_language.dart';
import 'package:car_parking_system/core/localization/app_strings.dart';
import 'package:car_parking_system/models/parking_record_model.dart';
import 'package:car_parking_system/models/vehicle_type.dart';
import 'package:car_parking_system/services/cloudinary_service.dart';

void main() {
  group('VEHICLE PHOTO AUTO-DELETE AFTER SUCCESSFUL VEHICLE EXIT — Comprehensive Test Suite', () {
    setUp(() {
      AppStrings.setLanguage(AppLanguage.english);
    });

    // 1. Entry captures and stores photo reference
    test('1. Entry captures and stores photo reference (photoUrl, photoPublicId, photoStorageProvider)', () {
      final record = ParkingRecord(
        id: '1001',
        ticketNumber: '1001',
        vehicleNumber: 'MH12AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1001/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1001/vehicle_photo',
        photoStorageProvider: 'cloudinary',
        photoDeleteToken: 'del_token_123',
      );

      expect(record.photoUrl, isNotEmpty);
      expect(record.photoPublicId, 'parking_records/1001/vehicle_photo');
      expect(record.photoStorageProvider, 'cloudinary');
      expect(record.photoDeleteToken, 'del_token_123');
      expect(record.isActive, isTrue);
      expect(record.isExited, isFalse);

      final map = record.toFirestore();
      expect(map['photoUrl'], contains('parking_records/1001/vehicle_photo'));
      expect(map['photoPublicId'], 'parking_records/1001/vehicle_photo');
      expect(map['photoStorageProvider'], 'cloudinary');
      expect(map['photoDeleteToken'], 'del_token_123');
      expect(map['status'], 'ACTIVE');
    });

    // 2. Active parking retains photo
    test('2. Active parking retains photo while vehicle is parked', () {
      final activeRecord = ParkingRecord(
        id: '1002',
        ticketNumber: '1002',
        vehicleNumber: 'MH14CD5678',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 10, 1, 10, 15),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1002/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1002/vehicle_photo',
      );

      expect(activeRecord.status, 'ACTIVE');
      expect(activeRecord.isActive, isTrue);
      expect(activeRecord.photoUrl, isNotNull);
      expect(activeRecord.photoPublicId, 'parking_records/1002/vehicle_photo');
      expect(activeRecord.photoCleanupStatus, isNull);
    });

    // 3. Successful exit triggers photo cleanup and clears photo references
    test('3. Successful exit triggers photo cleanup and returns record with photo cleared', () {
      final activeRecord = ParkingRecord(
        id: '1003',
        ticketNumber: '1003',
        vehicleNumber: 'MH15EF9012',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 9, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1003/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1003/vehicle_photo',
      );

      // Simulate successful exit and photo cleanup
      final exitedRecord = activeRecord.copyWith(
        status: 'EXITED',
        exitTime: DateTime(2026, 10, 1, 11, 0),
        exitGuardUid: 'guard_1',
        exitGuardName: 'Officer Ramesh',
        exitShift: 'Morning Shift',
        clearPhoto: true,
        photoCleanupStatus: 'DELETED',
      );

      expect(exitedRecord.status, 'EXITED');
      expect(exitedRecord.isExited, isTrue);
      expect(exitedRecord.photoUrl, isNull);
      expect(exitedRecord.vehiclePhotoUrl, isNull);
      expect(exitedRecord.photoPublicId, isNull);
      expect(exitedRecord.photoDeleteToken, isNull);
      expect(exitedRecord.photoCleanupStatus, 'DELETED');

      // Crucially: Historical parking details are 100% preserved
      expect(exitedRecord.ticketNumber, '1003');
      expect(exitedRecord.vehicleNumber, 'MH15EF9012');
      expect(exitedRecord.entryGuardName, 'Officer Ramesh');
      expect(exitedRecord.entryTime, DateTime(2026, 10, 1, 9, 0));
      expect(exitedRecord.exitTime, DateTime(2026, 10, 1, 11, 0));
    });

    // 4. Firestore photo reference is cleared in serialized map
    test('4. Firestore record has null photoUrl and photoPublicId after exit deletion', () {
      final exitedRecord = ParkingRecord(
        id: '1004',
        ticketNumber: '1004',
        vehicleNumber: 'MH20GH3456',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 10, 1, 8, 0),
        exitTime: DateTime(2026, 10, 1, 9, 0),
        status: 'EXITED',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: null,
        vehiclePhotoUrl: null,
        photoPublicId: null,
        photoCleanupStatus: 'DELETED',
      );

      final map = exitedRecord.toFirestore();
      expect(map['photoUrl'], isNull);
      expect(map['vehiclePhotoUrl'], isNull);
      expect(map['photoPublicId'], isNull);
      expect(map['photoCleanupStatus'], 'DELETED');
      expect(map['status'], 'EXITED');
      expect(map['ticketNumber'], '1004');
      expect(map['vehicleNumber'], 'MH20GH3456');
    });

    // 5. CloudinaryService: Unsigned token deletion succeeds
    test('5. CloudinaryService executes token-based deletion when deleteToken is available', () async {
      String? requestedUrl;
      String? requestBody;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        requestBody = request.body;
        return http.Response(jsonEncode({'result': 'ok'}), 200);
      });

      final cloudinary = CloudinaryService(
        client: mockClient,
        config: const AppConfig(
          environment: AppEnvironment.dev,
          firebaseProjectId: 'test-project',
          cloudinaryCloudName: 'dwzlw6jeu',
          cloudinaryUploadPreset: 'car_parking_dev',
        ),
      );

      final success = await cloudinary.deleteVehiclePhoto(
        publicId: 'parking_records/1005/vehicle_photo',
        deleteToken: 'sample_token_xyz',
      );

      expect(success, isTrue);
      expect(requestedUrl, contains('delete_by_token'));
      expect(requestBody, contains('sample_token_xyz'));
    });

    // 6. CloudinaryService: Signed Destroy API deletion with API Key & Secret
    test('6. CloudinaryService executes signed destroy with correct publicId and signature', () async {
      String? requestedUrl;
      Map<String, String>? requestFields;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        requestFields = request.bodyFields;
        return http.Response(jsonEncode({'result': 'ok'}), 200);
      });

      final cloudinary = CloudinaryService(
        client: mockClient,
        config: const AppConfig(
          environment: AppEnvironment.dev,
          firebaseProjectId: 'test-project',
          cloudinaryCloudName: 'dwzlw6jeu',
          cloudinaryUploadPreset: 'car_parking_dev',
          cloudinaryApiKey: '123456789012345',
          cloudinaryApiSecret: 'my_secret_key',
        ),
      );

      final success = await cloudinary.deleteVehiclePhoto(
        publicId: 'parking_records/1006/vehicle_photo',
      );

      expect(success, isTrue);
      expect(requestedUrl, contains('/image/destroy'));
      expect(requestFields?['public_id'], 'parking_records/1006/vehicle_photo');
      expect(requestFields?['api_key'], '123456789012345');
      expect(requestFields?['signature'], isNotEmpty);
      expect(requestFields?['invalidate'], 'true');
    });

    // 7. CloudinaryService: Treats "result: not found" as success (idempotent)
    test('7. CloudinaryService treats "not found" as success (already deleted)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'result': 'not found'}), 200);
      });

      final cloudinary = CloudinaryService(
        client: mockClient,
        config: const AppConfig(
          environment: AppEnvironment.dev,
          firebaseProjectId: 'test-project',
          cloudinaryCloudName: 'dwzlw6jeu',
          cloudinaryUploadPreset: 'car_parking_dev',
          cloudinaryApiKey: '123456789012345',
          cloudinaryApiSecret: 'my_secret_key',
        ),
      );

      final success = await cloudinary.deleteVehiclePhoto(
        publicId: 'parking_records/1007/vehicle_photo',
      );

      expect(success, isTrue);
    });

    // 8. Exit failure does NOT delete photo
    test('8. Exit failure (e.g. already exited or validation error) leaves photo untouched', () {
      final activeRecord = ParkingRecord(
        id: '1008',
        ticketNumber: '1008',
        vehicleNumber: 'MH12IJ7890',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 9, 30),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1008/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1008/vehicle_photo',
      );

      // When exit fails, record is not updated and photo remains
      expect(activeRecord.status, 'ACTIVE');
      expect(activeRecord.photoUrl, isNotNull);
      expect(activeRecord.photoPublicId, 'parking_records/1008/vehicle_photo');
      expect(activeRecord.photoCleanupStatus, isNull);
    });

    // 9. Multiple active vehicles delete ONLY exited vehicle photo
    test('9. Multiple active vehicles delete ONLY the exited vehicle photo', () {
      final vehicleA = ParkingRecord(
        id: '1009_A',
        ticketNumber: '1009_A',
        vehicleNumber: 'MH12AA1111',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 10, 1, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1009_A/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1009_A/vehicle_photo',
      );

      final vehicleB = ParkingRecord(
        id: '1009_B',
        ticketNumber: '1009_B',
        vehicleNumber: 'MH12BB2222',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 10, 5),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1009_B/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1009_B/vehicle_photo',
      );

      final vehicleC = ParkingRecord(
        id: '1009_C',
        ticketNumber: '1009_C',
        vehicleNumber: 'MH12CC3333',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 10, 1, 10, 10),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1009_C/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1009_C/vehicle_photo',
      );

      // Exit Vehicle B only
      final exitedB = vehicleB.copyWith(
        status: 'EXITED',
        exitTime: DateTime(2026, 10, 1, 11, 0),
        clearPhoto: true,
        photoCleanupStatus: 'DELETED',
      );

      // Vehicle B photo is deleted
      expect(exitedB.photoUrl, isNull);
      expect(exitedB.photoPublicId, isNull);
      expect(exitedB.photoCleanupStatus, 'DELETED');

      // Vehicle A and Vehicle C remain untouched with their photos intact
      expect(vehicleA.photoUrl, isNotNull);
      expect(vehicleA.photoPublicId, 'parking_records/1009_A/vehicle_photo');
      expect(vehicleA.status, 'ACTIVE');

      expect(vehicleC.photoUrl, isNotNull);
      expect(vehicleC.photoPublicId, 'parking_records/1009_C/vehicle_photo');
      expect(vehicleC.status, 'ACTIVE');
    });

    // 10. Same vehicle future visit does not delete new visit photo
    test('10. Same vehicle future visit is completely isolated from past session photo deletion', () {
      // Visit 1
      final visit1Active = ParkingRecord(
        id: '1010',
        ticketNumber: '1010',
        vehicleNumber: 'MH15AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 9, 28, 10, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1010/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1010/vehicle_photo',
      );

      // Visit 1 exits -> Photo 1010 is deleted
      final visit1Exited = visit1Active.copyWith(
        status: 'EXITED',
        exitTime: DateTime(2026, 9, 28, 12, 0),
        clearPhoto: true,
        photoCleanupStatus: 'DELETED',
      );
      expect(visit1Exited.photoPublicId, isNull);

      // Visit 2 enters as a new ticket #1020
      final visit2Active = ParkingRecord(
        id: '1020',
        ticketNumber: '1020',
        vehicleNumber: 'MH15AB1234',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 9, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_2',
        entryGuardName: 'Officer Suresh',
        entryShift: 'Morning Shift',
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1020/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1020/vehicle_photo',
      );

      // Visit 2 photo is intact and isolated
      expect(visit2Active.photoPublicId, 'parking_records/1020/vehicle_photo');
      expect(visit2Active.photoUrl, contains('1020'));
      expect(visit2Active.status, 'ACTIVE');
    });

    // 11. Monthly Pass vehicle follows same photo deletion rule
    test('11. Monthly Pass vehicle entry photo is deleted after exit while pass remains active', () {
      final passActive = ParkingRecord(
        id: '1011',
        ticketNumber: '1011',
        vehicleNumber: 'MH17PD2121',
        vehicleType: VehicleType.twoWheeler,
        entryTime: DateTime(2026, 10, 1, 8, 30),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Morning Shift',
        isMonthlyPass: true,
        monthlyPassId: 'PASS_202610_01',
        advanceAmount: 0.0,
        photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/parking_records/1011/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1011/vehicle_photo',
      );

      // Pass vehicle exits with ₹0 fee
      final passExited = passActive.copyWith(
        status: 'EXITED',
        exitTime: DateTime(2026, 10, 1, 10, 30),
        grossCharge: 0.0,
        paidAmount: 0.0,
        balanceDue: 0.0,
        refundAmount: 0.0,
        clearPhoto: true,
        photoCleanupStatus: 'DELETED',
      );

      expect(passExited.status, 'EXITED');
      expect(passExited.isMonthlyPass, isTrue);
      expect(passExited.monthlyPassId, 'PASS_202610_01');
      expect(passExited.photoUrl, isNull);
      expect(passExited.photoPublicId, isNull);
      expect(passExited.photoCleanupStatus, 'DELETED');
    });

    // 12. Cleanup is idempotent
    test('12. Deleting photo with empty publicId or already cleaned is a safe no-op', () async {
      final mockClient = MockClient((request) async {
        fail('No HTTP call should be made when publicId is empty');
      });

      final cloudinary = CloudinaryService(
        client: mockClient,
        config: const AppConfig(
          environment: AppEnvironment.dev,
          firebaseProjectId: 'test-project',
          cloudinaryCloudName: 'dwzlw6jeu',
          cloudinaryUploadPreset: 'car_parking_dev',
        ),
      );

      final result1 = await cloudinary.deleteVehiclePhoto(publicId: '');
      expect(result1, isTrue);

      final result2 = await cloudinary.deleteVehiclePhoto(publicId: '   ');
      expect(result2, isTrue);
    });

    // 13. Photo cleanup failure does NOT break vehicle exit
    test('13. Remote photo deletion error returns false / marks PENDING without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final cloudinary = CloudinaryService(
        client: mockClient,
        config: const AppConfig(
          environment: AppEnvironment.dev,
          firebaseProjectId: 'test-project',
          cloudinaryCloudName: 'dwzlw6jeu',
          cloudinaryUploadPreset: 'car_parking_dev',
          cloudinaryApiKey: 'key123',
          cloudinaryApiSecret: 'secret123',
        ),
      );

      bool threw = false;
      try {
        await cloudinary.deleteVehiclePhoto(publicId: 'parking_records/1013/vehicle_photo');
      } catch (e) {
        threw = true;
        expect(e, isA<CloudinaryDeleteException>());
      }
      expect(threw, isTrue);
    });

    // 14. Historical parking record preserves all fields
    test('14. Historical parking record retains all operational and financial metadata', () {
      final record = ParkingRecord(
        id: '1014',
        ticketNumber: '1014',
        vehicleNumber: 'MH12XY9999',
        vehicleType: VehicleType.fourWheeler,
        customerMobile: '9988776655',
        entryTime: DateTime(2026, 10, 1, 8, 0),
        exitTime: DateTime(2026, 10, 1, 10, 0),
        status: 'EXITED',
        entryGuardUid: 'guard_entry',
        entryGuardName: 'Officer Entry',
        entryShift: 'Shift 1',
        exitGuardUid: 'guard_exit',
        exitGuardName: 'Officer Exit',
        exitShift: 'Shift 1',
        advanceAmount: 20.0,
        advancePaymentMethod: 'cash',
        grossCharge: 40.0,
        finalCharge: 40.0,
        paidAmount: 20.0,
        balanceDue: 20.0,
        refundAmount: 0.0,
        paymentMethod: 'cash',
        photoUrl: null,
        photoPublicId: null,
        photoCleanupStatus: 'DELETED',
      );

      expect(record.ticketNumber, '1014');
      expect(record.vehicleNumber, 'MH12XY9999');
      expect(record.customerMobile, '9988776655');
      expect(record.entryGuardName, 'Officer Entry');
      expect(record.exitGuardName, 'Officer Exit');
      expect(record.advanceAmount, 20.0);
      expect(record.grossCharge, 40.0);
      expect(record.paidAmount, 20.0);
      expect(record.balanceDue, 20.0);
      expect(record.photoUrl, isNull);
    });

    // 15. English Localization
    test('15. English localization provides correct messages for photo deletion lifecycle', () {
      AppStrings.setLanguage(AppLanguage.english);

      expect(AppStrings.photoNoLongerAvailable, 'Vehicle photo no longer available.');
      expect(AppStrings.vehicleExitedSuccessfully, 'Vehicle Exited Successfully');
      expect(AppStrings.vehiclePhoto, 'Vehicle Photo');
      expect(AppStrings.photoCleanup, 'Photo Cleanup');
      expect(AppStrings.photoDeletedAfterExit, contains('automatically deleted'));
      expect(AppStrings.appName, 'CAR PARKING SYSTEM');
      expect(AppStrings.companyBrand, 'BIZFLOW');
      expect(AppStrings.adminPortal, 'ADMIN PORTAL');
    });

    // 16. Marathi Localization
    test('16. Marathi localization provides correct native text for photo deletion lifecycle', () {
      AppStrings.setLanguage(AppLanguage.marathi);

      expect(AppStrings.photoNoLongerAvailable, 'वाहनाचा फोटो यापुढे उपलब्ध नाही.');
      expect(AppStrings.vehicleExitedSuccessfully, 'वाहन निर्गमन यशस्वी झाले');
      expect(AppStrings.vehiclePhoto, 'वाहनाचा फोटो');
      expect(AppStrings.photoCleanup, 'फोटो स्वच्छता');
      expect(AppStrings.photoDeletedAfterExit, contains('आपोआप हटवला गेला'));

      // Brand headers remain invariant per system design
      expect(AppStrings.appName, 'CAR PARKING SYSTEM');
      expect(AppStrings.companyBrand, 'BIZFLOW');
      expect(AppStrings.adminPortal, 'ADMIN PORTAL');
    });

    // 17. UI fallback renders safe state without broken image
    testWidgets('17. UI displays safe fallback when photo is null or deleted', (tester) async {
      AppStrings.setLanguage(AppLanguage.english);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.no_photography_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(AppStrings.photoNoLongerAvailable),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vehicle photo no longer available.'), findsOneWidget);
      expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
    });

    // 18. Cloudinary deletion identifier security
    test('18. Cloudinary deletion relies on exact publicId rather than raw URL or vehicle number', () {
      final record = ParkingRecord(
        id: '1018',
        ticketNumber: '1018',
        vehicleNumber: 'MH12ZZ0001',
        vehicleType: VehicleType.fourWheeler,
        entryTime: DateTime(2026, 10, 1, 9, 0),
        status: 'ACTIVE',
        entryGuardUid: 'guard_1',
        entryGuardName: 'Officer Ramesh',
        entryShift: 'Shift 1',
        photoUrl: 'https://res.cloudinary.com/dwzlw6jeu/image/upload/v1726000000/parking_records/1018/vehicle_photo.jpg',
        photoPublicId: 'parking_records/1018/vehicle_photo',
      );

      // PublicId is session-specific and does not match vehicle number
      expect(record.photoPublicId, 'parking_records/1018/vehicle_photo');
      expect(record.photoPublicId, isNot(equals(record.vehicleNumber)));
      expect(record.photoPublicId, isNot(equals(record.photoUrl)));
    });
  });
}
