import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/utils/app_result.dart';
import 'package:pukaar/features/responder/presentation/screens/responder_dashboard_screen.dart';

class MockResponderEmergencyService implements EmergencyService {
  final StreamController<EmergencyIncident> _controller =
      StreamController<EmergencyIncident>.broadcast();
  List<EmergencyIncident> incidents = [];

  @override
  Stream<EmergencyIncident> get incidentStream => _controller.stream;

  @override
  EmergencyIncident? get activeIncident =>
      incidents.isNotEmpty ? incidents.firstWhere((i) => i.status.isActive, orElse: () => incidents.first) : null;

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async {
    final active = incidents.where((i) => i.status.isActive).toList();
    return AppResult.success(active);
  }

  @override
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(
    String incidentId,
    EmergencyStatus newStatus, {
    String? responderId,
    String? responderName,
    String? responderPhone,
    String? responderType,
    double? responderLat,
    double? responderLng,
    int? etaMinutes,
  }) async {
    final index = incidents.indexWhere((i) => i.id == incidentId);
    if (index == -1) return AppResult.failure('Incident not found');

    final updated = incidents[index].copyWith(
      status: newStatus,
      assignedResponderId: responderId ?? incidents[index].assignedResponderId,
      assignedResponderName: responderName ?? incidents[index].assignedResponderName,
      assignedResponderPhone: responderPhone ?? incidents[index].assignedResponderPhone,
      assignedResponderType: responderType ?? incidents[index].assignedResponderType,
      estimatedArrivalMinutes: etaMinutes ?? incidents[index].estimatedArrivalMinutes,
    );

    incidents[index] = updated;
    _controller.add(updated);
    return AppResult.success(updated);
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async {
    final index = incidents.indexWhere((i) => i.id == incidentId);
    if (index == -1) return AppResult.failure('Incident not found');

    final updated = incidents[index].copyWith(status: EmergencyStatus.cancelled);
    incidents[index] = updated;
    _controller.add(updated);
    return AppResult.success(updated);
  }

  @override
  Future<AppResult<EmergencyIncident>> createIncident({
    required EmergencyCategory category,
    required String intent,
    EmergencyPriority priority = EmergencyPriority.high,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? userId,
    String? notes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async {
    return AppResult.success(incidents);
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) async {
    final found = incidents.firstWhere((i) => i.id == incidentId);
    return AppResult.success(found);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  late MockResponderEmergencyService mockService;

  setUp(() {
    mockService = MockResponderEmergencyService();
    ServiceLocator.instance.init(customEmergencyService: mockService);
  });

  tearDown(() {
    mockService.dispose();
  });

  Widget createWidget() {
    return const MaterialApp(
      home: ResponderDashboardScreen(),
    );
  }

  testWidgets('ResponderDashboardScreen displays empty state when no active emergencies', (WidgetTester tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('No Active Emergencies'), findsOneWidget);
    expect(find.text('Responder Dashboard'), findsOneWidget);
    expect(find.text('Return to Citizen Home'), findsOneWidget);
  });

  testWidgets('ResponderDashboardScreen displays active incident cards', (WidgetTester tester) async {
    mockService.incidents = [
      EmergencyIncident(
        id: 'INC_RSP_101',
        userId: 'user_1',
        category: EmergencyCategory.medical,
        intent: 'Ambulance Call',
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        status: EmergencyStatus.created,
      ),
    ];

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Ambulance Call'), findsOneWidget);
    expect(find.text('Medical Emergency'), findsOneWidget);
    expect(find.text('Accept Incident Response'), findsOneWidget);
  });

  testWidgets('Responder can accept an active incident', (WidgetTester tester) async {
    mockService.incidents = [
      EmergencyIncident(
        id: 'INC_RSP_102',
        userId: 'user_1',
        category: EmergencyCategory.womenSafety,
        intent: 'Threat Alert',
        timestamp: DateTime.now(),
        status: EmergencyStatus.dispatched,
      ),
    ];

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Tap Accept
    await tester.tap(find.text('Accept Incident Response'));
    await tester.pumpAndSettle();

    expect(mockService.incidents.first.status, equals(EmergencyStatus.accepted));
    expect(mockService.incidents.first.assignedResponderName, equals('Safety Patrol Unit Alpha'));
    expect(find.text('Start Response (In Progress)'), findsOneWidget);
  });

  testWidgets('Responder can start response and resolve incident', (WidgetTester tester) async {
    mockService.incidents = [
      EmergencyIncident(
        id: 'INC_RSP_103',
        userId: 'user_1',
        category: EmergencyCategory.disaster,
        intent: 'Flood Alert',
        timestamp: DateTime.now(),
        status: EmergencyStatus.accepted,
        assignedResponderName: 'Rescue Unit 07',
      ),
    ];

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Tap Start Response
    await tester.tap(find.text('Start Response (In Progress)'));
    await tester.pumpAndSettle();

    expect(mockService.incidents.first.status, equals(EmergencyStatus.inProgress));
    expect(find.text('Mark Incident Resolved'), findsOneWidget);

    // Tap Mark Resolved
    await tester.tap(find.text('Mark Incident Resolved'));
    await tester.pumpAndSettle();

    expect(mockService.incidents.first.status, equals(EmergencyStatus.resolved));
    expect(find.text('No Active Emergencies'), findsOneWidget);
    expect(find.text('Return to Citizen Home'), findsOneWidget);
  });
}
