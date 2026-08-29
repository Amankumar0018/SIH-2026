import 'dart:async';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import '../utils/app_result.dart';
import 'auth_service.dart';
import 'location_service.dart';

/// Contract interface for Emergency Incident Management & Dispatching.
///
/// This service acts as the central domain coordinator for Pukaar's emergency lifecycle,
/// including creation, status tracking, responder dispatch, and incident resolution.
abstract class EmergencyService {
  /// Stream broadcasting live incident updates for real-time tracking screens.
  Stream<EmergencyIncident> get incidentStream;

  /// Returns the current active incident for the user session, if any.
  EmergencyIncident? get activeIncident;

  /// Creates and registers a new emergency incident.
  Future<AppResult<EmergencyIncident>> createIncident({
    required EmergencyCategory category,
    required String intent,
    EmergencyPriority priority = EmergencyPriority.high,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? userId,
    String? notes,
  });

  /// Retrieves an incident by its unique ID.
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId);

  /// Retrieves all incidents with active status (not resolved/cancelled).
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents();

  /// Retrieves all stored incidents history.
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents();

  /// Updates the status and optional responder assignment of an existing incident.
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
  });

  /// Cancels an incident.
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason});

  /// Disposes internal stream controllers and listeners.
  void dispose();
}

/// In-memory mock implementation of [EmergencyService] providing simulated emergency dispatch.
///
/// =========================================================================
/// FUTURE ARCHITECTURE EXTENSION POINTS:
/// 1. GPS / Live Location Stream:
///    Inject a reactive GPS location stream provider to continuously update
///    `EmergencyIncident.latitude` and `longitude` while `status.isActive == true`.
///
/// 2. Backend REST / GraphQL / WebSocket API:
///    Replace in-memory map operations with HTTP/gRPC calls to backend
///    emergency dispatch servers (`POST /v1/incidents`, `PATCH /v1/incidents/{id}/status`).
///
/// 3. GIS / Spatial Responder Matching Engine:
///    Integrate spatial proximity queries (PostGIS / Haversine nearest responder)
///    to locate and assign the optimal nearby emergency units.
///
/// 4. Push Notification / FCM Broadcaster:
///    Trigger critical alerts to assigned responders and the user's emergency contacts.
///
/// 5. Real-Time Tracking & Telemetry:
///    Stream live responder GPS updates via WebSockets or MQTT directly to client.
/// =========================================================================
class MockEmergencyService implements EmergencyService {
  final LocationService? locationService;
  final AuthService? authService;

  final Map<String, EmergencyIncident> _incidents = {};
  final StreamController<EmergencyIncident> _incidentStreamController =
      StreamController<EmergencyIncident>.broadcast();

  String? _activeIncidentId;

  MockEmergencyService({
    this.locationService,
    this.authService,
  });

  @override
  Stream<EmergencyIncident> get incidentStream => _incidentStreamController.stream;

  @override
  EmergencyIncident? get activeIncident {
    if (_activeIncidentId != null && _incidents.containsKey(_activeIncidentId)) {
      final incident = _incidents[_activeIncidentId]!;
      if (incident.status.isActive) {
        return incident;
      }
    }
    return null;
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
    try {
      // 1. Resolve coordinates (fallback to LocationService if not provided)
      double? lat = latitude;
      double? lng = longitude;
      double? acc = accuracy;
      String? gpsStatusNote;

      if ((lat == null || lng == null) && locationService != null) {
        final locResult = await locationService!.getCurrentLocation();
        if (locResult.isSuccess && locResult.data != null) {
          lat = locResult.data!.latitude;
          lng = locResult.data!.longitude;
          acc = locResult.data!.accuracy;
        } else if (!locResult.isSuccess) {
          gpsStatusNote = 'GPS info: ${locResult.errorMessage}';
        }
      }

      // 2. Resolve user identifier (fallback to AuthService current user profile)
      String resolvedUserId = userId ?? 'guest_user';
      if (userId == null && authService != null) {
        final profile = await authService!.getCurrentUser();
        if (profile != null && profile.mobileNumber.isNotEmpty) {
          resolvedUserId = profile.mobileNumber;
        }
      }

      // 3. Generate unique incident identifier
      final String incidentId = 'INC_${DateTime.now().millisecondsSinceEpoch}_${category.name.toUpperCase()}';

      // 4. Create incident instance
      final resolvedNotes = notes != null
          ? (gpsStatusNote != null ? '$notes | $gpsStatusNote' : notes)
          : gpsStatusNote;

      final incident = EmergencyIncident(
        id: incidentId,
        userId: resolvedUserId,
        category: category,
        intent: intent,
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        timestamp: DateTime.now(),
        priority: priority,
        status: EmergencyStatus.created,
        notes: resolvedNotes,
      );


      _incidents[incidentId] = incident;
      _activeIncidentId = incidentId;
      _incidentStreamController.add(incident);

      // 5. Simulate mock dispatcher triage & responder allocation
      _simulateMockDispatch(incidentId, category);

      return AppResult.success(incident);
    } catch (e) {
      return AppResult.failure('Failed to create emergency incident: $e');
    }
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) async {
    final incident = _incidents[incidentId];
    if (incident != null) {
      return AppResult.success(incident);
    }
    return AppResult.failure('Incident with ID "$incidentId" not found.');
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async {
    final activeList = _incidents.values.where((i) => i.status.isActive).toList();
    return AppResult.success(activeList);
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async {
    return AppResult.success(_incidents.values.toList());
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
    final existing = _incidents[incidentId];
    if (existing == null) {
      return AppResult.failure('Incident with ID "$incidentId" not found.');
    }

    final updated = existing.copyWith(
      status: newStatus,
      assignedResponderId: responderId ?? existing.assignedResponderId,
      assignedResponderName: responderName ?? existing.assignedResponderName,
      assignedResponderPhone: responderPhone ?? existing.assignedResponderPhone,
      assignedResponderType: responderType ?? existing.assignedResponderType,
      responderLatitude: responderLat ?? existing.responderLatitude,
      responderLongitude: responderLng ?? existing.responderLongitude,
      estimatedArrivalMinutes: etaMinutes ?? existing.estimatedArrivalMinutes,
    );

    _incidents[incidentId] = updated;
    if (!newStatus.isActive && _activeIncidentId == incidentId) {
      _activeIncidentId = null;
    }

    _incidentStreamController.add(updated);
    return AppResult.success(updated);
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async {
    final existing = _incidents[incidentId];
    if (existing == null) {
      return AppResult.failure('Incident with ID "$incidentId" not found.');
    }

    final updated = existing.copyWith(
      status: EmergencyStatus.cancelled,
      notes: reason != null ? '${existing.notes ?? ""}\nCancellation Reason: $reason'.trim() : existing.notes,
    );

    _incidents[incidentId] = updated;
    if (_activeIncidentId == incidentId) {
      _activeIncidentId = null;
    }

    _incidentStreamController.add(updated);
    return AppResult.success(updated);
  }

  /// Internal mock simulator for realistic incident lifecycle progression in demo mode.
  void _simulateMockDispatch(String incidentId, EmergencyCategory category) {
    // Stage 1: Move to Searching Responders
    Future.delayed(const Duration(milliseconds: 600), () {
      final current = _incidents[incidentId]?.status;
      if (_incidents.containsKey(incidentId) && current == EmergencyStatus.created) {
        updateIncidentStatus(incidentId, EmergencyStatus.searching);
      }
    });

    // Stage 2: Mock Responder Dispatched
    Future.delayed(const Duration(milliseconds: 1800), () {
      final current = _incidents[incidentId]?.status;
      if (_incidents.containsKey(incidentId) && current == EmergencyStatus.searching) {
        String responderName;
        String responderPhone;
        String responderType;

        switch (category) {
          case EmergencyCategory.medical:
            responderName = 'City Trauma Care Unit #4';
            responderPhone = '102';
            responderType = 'Advanced Life Support Ambulance';
            break;
          case EmergencyCategory.womenSafety:
            responderName = 'Rapid Response Patrol Alpha';
            responderPhone = '1091';
            responderType = 'Special Safety Escort Unit';
            break;
          case EmergencyCategory.disaster:
            responderName = 'NDRF Quick Rescue Unit 07';
            responderPhone = '1070';
            responderType = 'Disaster Management Team';
            break;
          case EmergencyCategory.campus:
            responderName = 'Campus Security Patrol #2';
            responderPhone = '112';
            responderType = 'University Emergency Officer';
            break;
        }

        updateIncidentStatus(
          incidentId,
          EmergencyStatus.dispatched,
          responderId: 'RESP_${category.name.toUpperCase()}_01',
          responderName: responderName,
          responderPhone: responderPhone,
          responderType: responderType,
          etaMinutes: 6,
        );
      }
    });

    // Stage 3: Responder Accepted
    Future.delayed(const Duration(seconds: 5), () {
      final current = _incidents[incidentId]?.status;
      if (_incidents.containsKey(incidentId) && current == EmergencyStatus.dispatched) {
        updateIncidentStatus(incidentId, EmergencyStatus.accepted, etaMinutes: 4);
      }
    });

    // Stage 4: Rescue In Progress
    Future.delayed(const Duration(seconds: 9), () {
      final current = _incidents[incidentId]?.status;
      if (_incidents.containsKey(incidentId) && current == EmergencyStatus.accepted) {
        updateIncidentStatus(incidentId, EmergencyStatus.inProgress, etaMinutes: 0);
      }
    });

    // Stage 5: Resolved
    Future.delayed(const Duration(seconds: 15), () {
      final current = _incidents[incidentId]?.status;
      if (_incidents.containsKey(incidentId) && current == EmergencyStatus.inProgress) {
        updateIncidentStatus(incidentId, EmergencyStatus.resolved);
      }
    });
  }

  @override
  void dispose() {
    _incidentStreamController.close();
  }
}
