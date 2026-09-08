import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/repositories/api_emergency_repository.dart';
import 'package:pukaar/core/services/api_service.dart';
import 'package:pukaar/core/services/realtime_service.dart';

void main() {
  group('RealtimeService URL Conversion', () {
    test('formatWebSocketUrl converts http to ws with token', () {
      final url = WebSocketRealtimeService.formatWebSocketUrl('http://10.0.2.2:8000', 'test_token_123');
      expect(url, equals('ws://10.0.2.2:8000/ws?token=test_token_123'));
    });

    test('formatWebSocketUrl converts https to wss with token', () {
      final url = WebSocketRealtimeService.formatWebSocketUrl('https://api.pukaar.app', 'token_xyz');
      expect(url, equals('wss://api.pukaar.app/ws?token=token_xyz'));
    });

    test('formatWebSocketUrl handles trailing slash gracefully', () {
      final url = WebSocketRealtimeService.formatWebSocketUrl('http://localhost:8000/', 'token_abc');
      expect(url, equals('ws://localhost:8000/ws?token=token_abc'));
    });
  });

  group('MockRealtimeService & Repository Streaming', () {
    late MockRealtimeService mockRealtimeService;
    late MockApiService mockApiService;
    late ApiEmergencyRepository repository;

    setUp(() {
      mockRealtimeService = MockRealtimeService();
      mockApiService = MockApiService();
      repository = ApiEmergencyRepository(mockApiService, mockRealtimeService);
    });

    tearDown(() {
      repository.dispose();
      mockRealtimeService.dispose();
    });

    test('connect sets isConnected to true', () async {
      expect(mockRealtimeService.isConnected, isFalse);
      await mockRealtimeService.connect('token_123');
      expect(mockRealtimeService.isConnected, isTrue);
    });

    test('disconnect sets isConnected to false', () async {
      await mockRealtimeService.connect('token_123');
      expect(mockRealtimeService.isConnected, isTrue);
      await mockRealtimeService.disconnect();
      expect(mockRealtimeService.isConnected, isFalse);
    });

    test('incoming realtime push event is emitted on repository incidentStream', () async {
      final receivedEvents = <EmergencyIncident>[];
      final subscription = repository.incidentStream.listen(receivedEvents.add);

      final mockIncident = EmergencyIncident(
        id: 'INC_TEST_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Heart Attack Alert',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.critical,
        timestamp: DateTime.now(),
      );

      mockRealtimeService.emitIncidentEvent(mockIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.id, equals('INC_TEST_001'));
      expect(receivedEvents.first.intent, equals('Heart Attack Alert'));

      await subscription.cancel();
    });

    test('status update via realtime is propagated to repository stream', () async {
      final receivedEvents = <EmergencyIncident>[];
      final subscription = repository.incidentStream.listen(receivedEvents.add);

      final acceptedIncident = EmergencyIncident(
        id: 'INC_TEST_002',
        userId: '9876543210',
        category: EmergencyCategory.womenSafety,
        intent: 'Harassment',
        status: EmergencyStatus.accepted,
        priority: EmergencyPriority.high,
        assignedResponderId: 'RESP_001',
        assignedResponderName: 'Officer Sharma',
        assignedResponderPhone: '1091',
        estimatedArrivalMinutes: 3,
        timestamp: DateTime.now(),
      );

      mockRealtimeService.emitIncidentEvent(acceptedIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.id, equals('INC_TEST_002'));
      expect(receivedEvents.first.status, equals(EmergencyStatus.accepted));
      expect(receivedEvents.first.assignedResponderName, equals('Officer Sharma'));
      expect(receivedEvents.first.estimatedArrivalMinutes, equals(3));

      await subscription.cancel();
    });
  });
}
