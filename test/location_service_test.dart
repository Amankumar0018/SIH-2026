import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/service_locator.dart';

void main() {
  group('EmergencyLocation Model Tests', () {
    test('EmergencyLocation serialization and deserialization', () {
      final now = DateTime(2026, 8, 29, 15, 45);
      final loc = EmergencyLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 4.5,
        altitude: 215.0,
        speed: 1.2,
        heading: 90.0,
        timestamp: now,
        isMocked: true,
      );

      final json = loc.toJson();
      final fromJson = EmergencyLocation.fromJson(json);

      expect(fromJson.latitude, 28.6139);
      expect(fromJson.longitude, 77.2090);
      expect(fromJson.accuracy, 4.5);
      expect(fromJson.altitude, 215.0);
      expect(fromJson.speed, 1.2);
      expect(fromJson.heading, 90.0);
      expect(fromJson.isMocked, isTrue);
    });

    test('EmergencyLocation copyWith works as expected', () {
      final loc = EmergencyLocation(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2026, 1, 1),
      );

      final updated = loc.copyWith(latitude: 12.34, accuracy: 10.0);
      expect(updated.latitude, 12.34);
      expect(updated.longitude, 20.0);
      expect(updated.accuracy, 10.0);
    });

  });

  group('LocationPermissionStatus Tests', () {
    test('Permission properties', () {
      expect(LocationPermissionStatus.granted.isGranted, isTrue);
      expect(LocationPermissionStatus.denied.isGranted, isFalse);
      expect(LocationPermissionStatus.permanentlyDenied.isGranted, isFalse);
      expect(LocationPermissionStatus.serviceDisabled.isGranted, isFalse);

      expect(LocationPermissionStatus.denied.canRequestAgain, isTrue);
      expect(LocationPermissionStatus.permanentlyDenied.canRequestAgain, isFalse);
      expect(LocationPermissionStatus.granted.canRequestAgain, isFalse);
    });
  });

  group('MockLocationService Tests', () {
    late MockLocationService locationService;

    setUp(() {
      locationService = MockLocationService();
    });

    test('Returns coordinates when permission granted and service enabled', () async {
      final result = await locationService.getCurrentLocation();
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.latitude, 28.6139);
      expect(result.data!.longitude, 77.2090);
    });

    test('Returns failure when location service is disabled', () async {
      locationService.isEnabled = false;
      final result = await locationService.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('disabled'));
    });

    test('Returns failure when permission is denied', () async {
      locationService.permissionStatus = LocationPermissionStatus.denied;
      final result = await locationService.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('denied'));
    });

    test('Returns failure when permission is permanently denied', () async {
      locationService.permissionStatus = LocationPermissionStatus.permanentlyDenied;
      final result = await locationService.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('permanently denied'));
    });

    test('Requesting permission upgrades denied to granted', () async {
      locationService.permissionStatus = LocationPermissionStatus.denied;
      final status = await locationService.requestPermission();
      expect(status, LocationPermissionStatus.granted);
    });

    test('Returns failure when simulateError is true', () async {
      locationService.simulateError = true;
      final result = await locationService.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Simulated location error'));
    });
  });

  group('EmergencyService and LocationService Integration Tests', () {
    test('Incident creation captures GPS coordinates when location is active', () async {
      final mockLocation = MockLocationService(
        mockLocation: EmergencyLocation(
          latitude: 19.0760,
          longitude: 72.8777,
          accuracy: 3.0,
          timestamp: DateTime.now(),
        ),
      );

      ServiceLocator.instance.init(
        customLocationService: mockLocation,
      );

      final emergencyService = ServiceLocator.instance.emergencyService;
      final result = await emergencyService.createIncident(
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.latitude, 19.0760);
      expect(result.data!.longitude, 72.8777);
      expect(result.data!.accuracy, 3.0);
    });

    test('Incident creation succeeds with diagnostic note when GPS is disabled', () async {
      final mockLocation = MockLocationService(isEnabled: false);

      ServiceLocator.instance.init(
        customLocationService: mockLocation,
      );

      final emergencyService = ServiceLocator.instance.emergencyService;
      final result = await emergencyService.createIncident(
        category: EmergencyCategory.womenSafety,
        intent: 'Harassment',
      );

      // Emergency dispatch creation MUST succeed even if GPS fails
      expect(result.isSuccess, isTrue);
      expect(result.data!.latitude, isNull);
      expect(result.data!.longitude, isNull);
      expect(result.data!.notes, contains('GPS info'));
      expect(result.data!.notes, contains('disabled'));
    });
  });
}
