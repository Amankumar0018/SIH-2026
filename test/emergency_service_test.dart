import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/models/user_profile.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/service_locator.dart';


void main() {
  group('EmergencyEnums Tests', () {
    test('EmergencyCategory fromString parses all pillar names correctly', () {
      expect(EmergencyCategory.fromString('Medical Emergency'), EmergencyCategory.medical);
      expect(EmergencyCategory.fromString('medical'), EmergencyCategory.medical);
      expect(EmergencyCategory.fromString("Women's Safety"), EmergencyCategory.womenSafety);
      expect(EmergencyCategory.fromString('women safety'), EmergencyCategory.womenSafety);
      expect(EmergencyCategory.fromString('Disaster Management'), EmergencyCategory.disaster);
      expect(EmergencyCategory.fromString('disaster'), EmergencyCategory.disaster);
      expect(EmergencyCategory.fromString('Campus Emergency'), EmergencyCategory.campus);
      expect(EmergencyCategory.fromString('campus'), EmergencyCategory.campus);
    });

    test('EmergencyStatus displayName and isActive check', () {
      expect(EmergencyStatus.created.isActive, isTrue);
      expect(EmergencyStatus.searching.isActive, isTrue);
      expect(EmergencyStatus.dispatched.isActive, isTrue);
      expect(EmergencyStatus.accepted.isActive, isTrue);
      expect(EmergencyStatus.inProgress.isActive, isTrue);
      expect(EmergencyStatus.resolved.isActive, isFalse);
      expect(EmergencyStatus.cancelled.isActive, isFalse);

      expect(EmergencyStatus.fromString('dispatched'), EmergencyStatus.dispatched);
      expect(EmergencyStatus.fromString('resolved'), EmergencyStatus.resolved);
    });

    test('EmergencyPriority parsing and display', () {
      expect(EmergencyPriority.fromString('critical'), EmergencyPriority.critical);
      expect(EmergencyPriority.fromString('high'), EmergencyPriority.high);
      expect(EmergencyPriority.fromString('medium'), EmergencyPriority.medium);
      expect(EmergencyPriority.fromString('low'), EmergencyPriority.low);
    });
  });

  group('EmergencyIncident Model Tests', () {
    test('EmergencyIncident serializes to and from JSON cleanly', () {
      final now = DateTime(2026, 8, 29, 15, 30);
      final incident = EmergencyIncident(
        id: 'INC_TEST_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 5.0,
        timestamp: now,
        priority: EmergencyPriority.critical,
        status: EmergencyStatus.dispatched,
        assignedResponderId: 'RESP_MED_01',
        assignedResponderName: 'City Ambulance #1',
        assignedResponderPhone: '102',
        assignedResponderType: 'ALS Paramedic Unit',
        responderLatitude: 28.6150,
        responderLongitude: 77.2100,
        estimatedArrivalMinutes: 5,
        notes: 'Patient conscious',
      );

      final json = incident.toJson();
      final deserialized = EmergencyIncident.fromJson(json);

      expect(deserialized.id, incident.id);
      expect(deserialized.userId, incident.userId);
      expect(deserialized.category, incident.category);
      expect(deserialized.intent, incident.intent);
      expect(deserialized.latitude, incident.latitude);
      expect(deserialized.longitude, incident.longitude);
      expect(deserialized.priority, incident.priority);
      expect(deserialized.status, incident.status);
      expect(deserialized.assignedResponderId, incident.assignedResponderId);
      expect(deserialized.assignedResponderName, incident.assignedResponderName);
      expect(deserialized.assignedResponderPhone, incident.assignedResponderPhone);
      expect(deserialized.assignedResponderType, incident.assignedResponderType);
      expect(deserialized.estimatedArrivalMinutes, incident.estimatedArrivalMinutes);
      expect(deserialized.notes, incident.notes);
    });

    test('EmergencyIncident copyWith works properly', () {
      final incident = EmergencyIncident(
        id: 'INC_01',
        userId: 'user_1',
        category: EmergencyCategory.campus,
        intent: 'Active Fire',
        timestamp: DateTime.now(),
      );

      final updated = incident.copyWith(
        status: EmergencyStatus.inProgress,
        assignedResponderName: 'Campus Security #1',
      );

      expect(updated.id, incident.id);
      expect(updated.status, EmergencyStatus.inProgress);
      expect(updated.assignedResponderName, 'Campus Security #1');
      expect(incident.status, EmergencyStatus.created);
    });
  });

  group('MockEmergencyService Engine Tests', () {
    late EmergencyService emergencyService;

    setUp(() {
      ServiceLocator.instance.init(
        customLocationService: MockLocationService(),
      );
      emergencyService = ServiceLocator.instance.emergencyService;
    });


    tearDown(() {
      emergencyService.dispose();
    });

    test('Creates emergency incident and populates mock location and user profile', () async {
      // Register mock profile
      await ServiceLocator.instance.authService.registerUser(
        const UserProfile(
          name: 'Pukaar Test User',
          mobileNumber: '9988776655',
          emergencyContactName: 'Contact',
          emergencyContactPhone: '9988776600',
        ),
      );

      final result = await emergencyService.createIncident(
        category: EmergencyCategory.disaster,
        intent: 'Flood Assistance',
        priority: EmergencyPriority.high,
      );

      expect(result.isSuccess, isTrue);
      final incident = result.data!;
      expect(incident.category, EmergencyCategory.disaster);
      expect(incident.intent, 'Flood Assistance');
      expect(incident.userId, '9988776655');
      expect(incident.latitude, isNotNull);
      expect(incident.longitude, isNotNull);
      expect(incident.status, EmergencyStatus.created);

      // Verify active incident lookup
      expect(emergencyService.activeIncident?.id, incident.id);
    });

    test('Update incident status and responder assignment', () async {
      final createResult = await emergencyService.createIncident(
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
      );
      final incidentId = createResult.data!.id;

      final updateResult = await emergencyService.updateIncidentStatus(
        incidentId,
        EmergencyStatus.dispatched,
        responderId: 'AMB_01',
        responderName: 'Apex Paramedic Unit',
        responderPhone: '102',
        etaMinutes: 4,
      );

      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.data!.status, EmergencyStatus.dispatched);
      expect(updateResult.data!.assignedResponderName, 'Apex Paramedic Unit');
      expect(updateResult.data!.estimatedArrivalMinutes, 4);
    });

    test('Cancel active incident sets status to cancelled and clears active incident', () async {
      final createResult = await emergencyService.createIncident(
        category: EmergencyCategory.womenSafety,
        intent: 'Unsafe Situation',
      );
      final incidentId = createResult.data!.id;

      expect(emergencyService.activeIncident?.id, incidentId);

      final cancelResult = await emergencyService.cancelIncident(
        incidentId,
        reason: 'False alarm',
      );

      expect(cancelResult.isSuccess, isTrue);
      expect(cancelResult.data!.status, EmergencyStatus.cancelled);
      expect(emergencyService.activeIncident, isNull);
    });

    test('Incident stream broadcasts updates to subscribers', () async {
      final List<EmergencyIncident> streamEvents = [];
      final sub = emergencyService.incidentStream.listen((event) {
        streamEvents.add(event);
      });

      final result = await emergencyService.createIncident(
        category: EmergencyCategory.campus,
        intent: 'Security Escort',
      );

      await emergencyService.updateIncidentStatus(
        result.data!.id,
        EmergencyStatus.inProgress,
      );

      // Allow microtask/stream propagation
      await Future.delayed(const Duration(milliseconds: 50));

      expect(streamEvents.isNotEmpty, isTrue);
      expect(streamEvents.any((e) => e.status == EmergencyStatus.inProgress), isTrue);

      await sub.cancel();
    });
  });
}
