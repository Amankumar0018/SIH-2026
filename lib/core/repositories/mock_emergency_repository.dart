import 'dart:async';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import '../utils/app_result.dart';
import 'emergency_repository.dart';

/// In-memory mock implementation of [EmergencyRepository] for offline testing,
/// previews, and repository-level mock persistence.
class MockEmergencyRepository implements EmergencyRepository {
  final Map<String, EmergencyIncident> _store = {};
  final StreamController<EmergencyIncident> _streamController =
      StreamController<EmergencyIncident>.broadcast();

  @override
  Stream<EmergencyIncident> get incidentStream => _streamController.stream;

  @override
  Future<AppResult<EmergencyIncident>> createIncident(EmergencyIncident incident) async {
    _store[incident.id] = incident;
    _streamController.add(incident);
    return AppResult.success(incident);
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncident(String incidentId) async {
    final incident = _store[incidentId];
    if (incident != null) {
      return AppResult.success(incident);
    }
    return AppResult.failure('Incident "$incidentId" not found in mock repository.');
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async {
    final active = _store.values.where((i) => i.status.isActive).toList();
    return AppResult.success(active);
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async {
    return AppResult.success(_store.values.toList());
  }

  @override
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(
    String incidentId,
    EmergencyStatus status,
  ) async {
    final existing = _store[incidentId];
    if (existing == null) {
      return AppResult.failure('Incident "$incidentId" not found.');
    }

    final updated = existing.copyWith(status: status);
    _store[incidentId] = updated;
    _streamController.add(updated);
    return AppResult.success(updated);
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(
    String incidentId, {
    String? reason,
  }) async {
    final existing = _store[incidentId];
    if (existing == null) {
      return AppResult.failure('Incident "$incidentId" not found.');
    }

    final updated = existing.copyWith(
      status: EmergencyStatus.cancelled,
      notes: reason != null ? '${existing.notes ?? ""}\nReason: $reason'.trim() : existing.notes,
    );
    _store[incidentId] = updated;
    _streamController.add(updated);
    return AppResult.success(updated);
  }

  @override
  Future<AppResult<EmergencyIncident>> assignResponder(
    String incidentId, {
    required String responderId,
    required String responderName,
    String? responderPhone,
    String? responderType,
    double? responderLat,
    double? responderLng,
    int? etaMinutes,
  }) async {
    final existing = _store[incidentId];
    if (existing == null) {
      return AppResult.failure('Incident "$incidentId" not found.');
    }

    final updated = existing.copyWith(
      assignedResponderId: responderId,
      assignedResponderName: responderName,
      assignedResponderPhone: responderPhone ?? existing.assignedResponderPhone,
      assignedResponderType: responderType ?? existing.assignedResponderType,
      responderLatitude: responderLat ?? existing.responderLatitude,
      responderLongitude: responderLng ?? existing.responderLongitude,
      estimatedArrivalMinutes: etaMinutes ?? existing.estimatedArrivalMinutes,
    );
    _store[incidentId] = updated;
    _streamController.add(updated);
    return AppResult.success(updated);
  }

  @override
  void dispose() {
    _streamController.close();
  }
}
