import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/utils/app_result.dart';
import 'package:pukaar/features/emergency/presentation/screens/emergency_tracking_screen.dart';

class MockTestEmergencyService implements EmergencyService {
  final StreamController<EmergencyIncident> _controller = StreamController<EmergencyIncident>.broadcast();
  EmergencyIncident? currentIncident;
  bool cancelCalled = false;

  @override
  Stream<EmergencyIncident> get incidentStream => _controller.stream;

  @override
  EmergencyIncident? get activeIncident => currentIncident;

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async {
    cancelCalled = true;
    currentIncident = currentIncident!.copyWith(status: EmergencyStatus.cancelled);
    _controller.add(currentIncident!);
    return AppResult.success(currentIncident!);
  }

  @override
  Future<AppResult<EmergencyIncident>> createIncident({required EmergencyCategory category, required String intent, EmergencyPriority priority = EmergencyPriority.high, double? latitude, double? longitude, double? accuracy, String? userId, String? notes}) {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(String incidentId, EmergencyStatus newStatus, {String? responderId, String? responderName, String? responderPhone, String? responderType, double? responderLat, double? responderLng, int? etaMinutes}) {
    throw UnimplementedError();
  }

  void simulateUpdate(EmergencyIncident incident) {
    currentIncident = incident;
    _controller.add(incident);
  }
}

void main() {
  late MockTestEmergencyService mockEmergencyService;

  setUp(() {
    mockEmergencyService = MockTestEmergencyService();
    ServiceLocator.instance.init(
      customEmergencyService: mockEmergencyService,
    );
  });

  tearDown(() {
    mockEmergencyService.dispose();
  });

  Widget createTestWidget(EmergencyIncident incident) {
    return MaterialApp(
      home: EmergencyTrackingScreen(incident: incident),
    );
  }

  testWidgets('EmergencyTrackingScreen displays incident details and timeline', (WidgetTester tester) async {
    final incident = EmergencyIncident(
      id: 'INC_TEST_123',
      userId: 'test_user',
      category: EmergencyCategory.womenSafety,
      intent: 'Harassment',
      latitude: 12.34,
      longitude: 56.78,
      timestamp: DateTime.now(),
      status: EmergencyStatus.created,
    );

    mockEmergencyService.currentIncident = incident;

    await tester.pumpWidget(createTestWidget(incident));

    // Verify Header
    expect(find.text('WOMEN\'S SAFETY'), findsOneWidget);
    expect(find.text('Harassment'), findsOneWidget);

    // Verify Location
    expect(find.text('Location Captured'), findsOneWidget);
    expect(find.text('Lat: 12.3400, Lng: 56.7800'), findsOneWidget);

    // Verify Timeline (Initial)
    expect(find.text('Incident Created'), findsOneWidget);
    expect(find.text('Searching Nearest Responders'), findsOneWidget);

    // Verify Responder info is not shown initially
    expect(find.text('Assigned Responder'), findsNothing);
  });

  testWidgets('EmergencyTrackingScreen updates when stream emits new status', (WidgetTester tester) async {
    final incident = EmergencyIncident(
      id: 'INC_TEST_123',
      userId: 'test_user',
      category: EmergencyCategory.medical,
      intent: 'Ambulance',
      timestamp: DateTime.now(),
      status: EmergencyStatus.created,
    );

    mockEmergencyService.currentIncident = incident;

    await tester.pumpWidget(createTestWidget(incident));
    
    // Simulate update to Dispatched
    final updatedIncident = incident.copyWith(
      status: EmergencyStatus.dispatched,
      assignedResponderId: 'RESP_1',
      assignedResponderName: 'City Ambulance',
      assignedResponderType: 'Paramedic',
      assignedResponderPhone: '911',
      estimatedArrivalMinutes: 5,
    );

    mockEmergencyService.simulateUpdate(updatedIncident);
    await tester.pumpAndSettle();

    // Verify Responder info appears
    expect(find.text('Assigned Responder'), findsOneWidget);
    expect(find.text('City Ambulance'), findsOneWidget);
    expect(find.text('Paramedic'), findsOneWidget);
    expect(find.text('911'), findsOneWidget);
    expect(find.text('ETA: 5 min'), findsOneWidget);
  });

  testWidgets('EmergencyTrackingScreen cancels incident and shows cancelled state', (WidgetTester tester) async {
    final incident = EmergencyIncident(
      id: 'INC_TEST_123',
      userId: 'test_user',
      category: EmergencyCategory.medical,
      intent: 'Ambulance',
      timestamp: DateTime.now(),
      status: EmergencyStatus.created,
    );

    mockEmergencyService.currentIncident = incident;

    await tester.pumpWidget(createTestWidget(incident));

    // Tap Cancel
    await tester.tap(find.text('Cancel Emergency'));
    await tester.pumpAndSettle();

    // Verify Dialog appears
    expect(find.text('Cancel Emergency?'), findsOneWidget);

    // Confirm Cancel
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();

    expect(mockEmergencyService.cancelCalled, isTrue);

    // Verify UI updates to cancelled
    expect(find.text('This emergency incident has been cancelled.'), findsOneWidget);
  });
}
