import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/ai_intelligence.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/models/user_profile.dart';
import 'package:pukaar/core/services/auth_service.dart';
import 'package:pukaar/core/services/notification_service.dart';
import 'package:pukaar/core/services/realtime_service.dart';
import 'package:pukaar/core/services/secure_storage_service.dart';
import 'package:pukaar/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppNotificationService Unit & Integration Tests', () {
    late MockRealtimeService mockRealtimeService;
    late MockAuthService mockAuthService;
    late InAppNotificationService notificationService;

    setUp(() {
      mockRealtimeService = MockRealtimeService();
      mockAuthService = MockAuthService(
        InMemoryStorageService(),
        InMemorySecureStorageService(),
        mockRealtimeService,
      );
      notificationService = InAppNotificationService(
        realtimeService: mockRealtimeService,
        authService: mockAuthService,
      );
    });

    tearDown(() {
      notificationService.dispose();
      mockRealtimeService.dispose();
    });

    // 1. incident.created → responder notification.
    test('1. incident.created generates prominent "New Emergency" notification for responder', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Officer John',
        mobileNumber: '9000000000',
        role: 'responder',
        emergencyContactName: 'Support',
        emergencyContactPhone: '100',
      ));

      final createdIncident = EmergencyIncident(
        id: 'INC_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Heart Attack',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.critical,
        timestamp: DateTime.now(),
      );

      mockRealtimeService.emitIncidentEvent(createdIncident);
      await Future.delayed(const Duration(milliseconds: 30));

      expect(notificationService.notificationHistory.length, equals(1));
      final notification = notificationService.notificationHistory.first;
      expect(notification.title, equals('New Emergency'));
      expect(notification.message, contains('Medical Emergency reported (Heart Attack)'));
      expect(notification.type, equals(NotificationType.alert));
      expect(notification.incidentId, equals('INC_001'));
    });

    // 2. incident.updated → citizen status notification.
    test('2. incident.updated produces appropriate status notifications for incident owner', () async {
      const citizenMobile = '9876543210';
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Alice Citizen',
        mobileNumber: citizenMobile,
        role: 'citizen',
        emergencyContactName: 'Dad',
        emergencyContactPhone: '9999999999',
      ));

      // Initial created state observed (citizen does NOT get an alert for created)
      final initialIncident = EmergencyIncident(
        id: 'INC_002',
        userId: citizenMobile,
        category: EmergencyCategory.womenSafety,
        intent: 'Harassment',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.high,
        timestamp: DateTime.now(),
      );
      mockRealtimeService.emitIncidentEvent(initialIncident);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notificationService.notificationHistory, isEmpty);

      // Transition A: accepted
      final acceptedIncident = initialIncident.copyWith(
        status: EmergencyStatus.accepted,
        assignedResponderId: 'RESP_01',
        assignedResponderName: 'Officer Davis',
      );
      mockRealtimeService.emitIncidentEvent(acceptedIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory.length, equals(1));
      expect(notificationService.notificationHistory.last.title, equals('Incident Accepted'));
      expect(notificationService.notificationHistory.last.message, equals('Responder has accepted your emergency'));

      // Transition B: dispatched
      final dispatchedIncident = acceptedIncident.copyWith(
        status: EmergencyStatus.dispatched,
      );
      mockRealtimeService.emitIncidentEvent(dispatchedIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory.length, equals(2));
      expect(notificationService.notificationHistory.last.title, equals('Responder Dispatched'));
      expect(notificationService.notificationHistory.last.message, equals('A responder has been dispatched'));

      // Transition C: inProgress
      final inProgressIncident = dispatchedIncident.copyWith(
        status: EmergencyStatus.inProgress,
      );
      mockRealtimeService.emitIncidentEvent(inProgressIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory.length, equals(3));
      expect(notificationService.notificationHistory.last.title, equals('Incident In Progress'));
      expect(notificationService.notificationHistory.last.message, equals('Help is on the way'));

      // Transition D: resolved
      final resolvedIncident = inProgressIncident.copyWith(
        status: EmergencyStatus.resolved,
      );
      mockRealtimeService.emitIncidentEvent(resolvedIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory.length, equals(4));
      expect(notificationService.notificationHistory.last.title, equals('Incident Resolved'));
      expect(notificationService.notificationHistory.last.message, equals('Your emergency has been resolved'));
    });

    // 3. Unrelated incident does not create citizen notification.
    test('3. Unrelated incident belonging to another citizen never triggers notification for citizen', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Alice Citizen',
        mobileNumber: '9876543210',
        role: 'citizen',
        emergencyContactName: 'Dad',
        emergencyContactPhone: '9999999999',
      ));

      // Another citizen's incident
      final otherCitizenIncident = EmergencyIncident(
        id: 'INC_OTHER_001',
        userId: '9123456789', // Different mobile number
        category: EmergencyCategory.medical,
        intent: 'Fall Injury',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.medium,
        timestamp: DateTime.now(),
      );

      mockRealtimeService.emitIncidentEvent(otherCitizenIncident);
      await Future.delayed(const Duration(milliseconds: 20));

      // Status update on other citizen's incident
      final otherUpdated = otherCitizenIncident.copyWith(
        status: EmergencyStatus.accepted,
      );
      mockRealtimeService.emitIncidentEvent(otherUpdated);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory, isEmpty);
    });

    // 4. Duplicate event does not create duplicate notification.
    test('4. Duplicate event with same state does not create duplicate notification', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Officer John',
        mobileNumber: '9000000000',
        role: 'responder',
        emergencyContactName: 'Support',
        emergencyContactPhone: '100',
      ));

      final incident = EmergencyIncident(
        id: 'INC_DUP_001',
        userId: '9876543210',
        category: EmergencyCategory.disaster,
        intent: 'Building Fire',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.critical,
        timestamp: DateTime.now(),
      );

      // Emit the same created event twice
      mockRealtimeService.emitIncidentEvent(incident);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notificationService.notificationHistory.length, equals(1));

      // Second emission of identical event
      mockRealtimeService.emitIncidentEvent(incident);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notificationService.notificationHistory.length, equals(1)); // Still 1, duplicate suppressed
    });

    // 5. AI update produces a lightweight notification only.
    test('5. AI enrichment produces a lightweight notification without entire summary', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Officer John',
        mobileNumber: '9000000000',
        role: 'responder',
        emergencyContactName: 'Support',
        emergencyContactPhone: '100',
      ));

      const initialAi = AIIntelligence(
        summary: 'Patient unconscious with chest pain.',
        urgencyScore: 'critical',
        hazards: ['traffic delay'],
        recommendedActions: ['Prep defibrillator'],
        missingInfo: [],
        source: 'rule_based',
        confidence: 0.6,
      );

      final incidentWithInitialAi = EmergencyIncident(
        id: 'INC_AI_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Chest Pain',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.critical,
        timestamp: DateTime.now(),
        aiIntelligence: initialAi,
      );

      mockRealtimeService.emitIncidentEvent(incidentWithInitialAi);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notificationService.notificationHistory.length, equals(1)); // "New Emergency"

      // Background task updates AI with LLM enrichment
      const enrichedAi = AIIntelligence(
        summary: 'Enriched: Suspected acute coronary syndrome with high cardiac arrest risk. Detailed notes follow.',
        urgencyScore: 'critical',
        hazards: ['traffic delay', 'staircase narrow'],
        recommendedActions: ['Prep defibrillator', 'Administer aspirin if approved', 'Request ALS backup'],
        missingInfo: ['patient age'],
        source: 'gemini_enriched',
        confidence: 0.95,
      );

      final incidentWithEnrichedAi = incidentWithInitialAi.copyWith(
        aiIntelligence: enrichedAi,
      );

      mockRealtimeService.emitIncidentEvent(incidentWithEnrichedAi);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(notificationService.notificationHistory.length, equals(2));
      final aiNotification = notificationService.notificationHistory.last;
      expect(aiNotification.title, equals('AI Incident Intelligence Updated'));
      expect(aiNotification.message, equals('New AI triage assessment available'));
      expect(aiNotification.type, equals(NotificationType.ai));
      // Must NOT contain full summary or unconfirmed claims
      expect(aiNotification.message, isNot(contains('Suspected acute coronary syndrome')));
    });

    // 6. Missing/null fields do not crash.
    test('6. Missing, empty, or null fields do not crash notification service', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Officer John',
        mobileNumber: '9000000000',
        role: 'responder',
        emergencyContactName: 'Support',
        emergencyContactPhone: '100',
      ));

      final sparseIncident = EmergencyIncident(
        id: '',
        userId: '',
        category: EmergencyCategory.medical,
        intent: '',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.low,
        timestamp: DateTime.now(),
        aiIntelligence: null,
      );

      // Should not throw or crash
      expect(() => mockRealtimeService.emitIncidentEvent(sparseIncident), returnsNormally);
      await Future.delayed(const Duration(milliseconds: 30));

      expect(notificationService.notificationHistory.length, equals(1));
      expect(notificationService.notificationHistory.first.title, equals('New Emergency'));
    });

    // 7. Notification failure does not break incident stream.
    test('7. Internal error during notification processing is non-fatal and preserves incident stream', () async {
      await mockAuthService.updateCurrentUser(const UserProfile(
        name: 'Officer John',
        mobileNumber: '9000000000',
        role: 'responder',
        emergencyContactName: 'Support',
        emergencyContactPhone: '100',
      ));

      // Inject a callback that throws an exception
      notificationService.onNotificationShown = (notification) {
        throw Exception('Simulated UI rendering crash');
      };

      final incidentA = EmergencyIncident(
        id: 'INC_ERR_1',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Asthma Attack',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.high,
        timestamp: DateTime.now(),
      );

      final incidentB = EmergencyIncident(
        id: 'INC_ERR_2',
        userId: '9876543210',
        category: EmergencyCategory.campus,
        intent: 'Lab Chemical Spill',
        status: EmergencyStatus.created,
        priority: EmergencyPriority.critical,
        timestamp: DateTime.now(),
      );

      // First incident triggers the throwing callback
      expect(() => mockRealtimeService.emitIncidentEvent(incidentA), returnsNormally);
      await Future.delayed(const Duration(milliseconds: 30));

      // Stream must STILL be alive and receive incidentB
      expect(() => mockRealtimeService.emitIncidentEvent(incidentB), returnsNormally);
      await Future.delayed(const Duration(milliseconds: 30));

      // History should contain both despite callback throwing
      expect(notificationService.notificationHistory.length, equals(2));
      expect(notificationService.notificationHistory[0].incidentId, equals('INC_ERR_1'));
      expect(notificationService.notificationHistory[1].incidentId, equals('INC_ERR_2'));
    });

    testWidgets('8. In-app notification renders floating SnackBar UI with title and DISMISS action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: InAppNotificationService.scaffoldMessengerKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );

      notificationService.showNotification(
        title: 'New Emergency',
        message: 'Medical Emergency reported (Cardiac Arrest)',
        type: NotificationType.alert,
      );
      await tester.pumpAndSettle();

      expect(find.text('New Emergency'), findsOneWidget);
      expect(find.text('Medical Emergency reported (Cardiac Arrest)'), findsOneWidget);

      // Dismiss programmatically via notificationService
      notificationService.dismissNotification();
      await tester.pumpAndSettle();

      expect(find.text('New Emergency'), findsNothing);
    });
  });
}
