import 'dart:async';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import '../utils/app_result.dart';

/// Contract interface for Emergency Incident Data Persistence & Remote Backend API.
///
/// Handles database/API CRUD operations, responder assignments, status updates,
/// and live streaming of incident changes.
abstract class EmergencyRepository {
  /// Live stream broadcasting real-time incident updates from the backend/repository.
  Stream<EmergencyIncident> get incidentStream;

  /// Persists a new emergency incident.
  Future<AppResult<EmergencyIncident>> createIncident(EmergencyIncident incident);

  /// Retrieves an incident by its unique ID.
  Future<AppResult<EmergencyIncident>> getIncident(String incidentId);

  /// Retrieves all active emergency incidents.
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents();

  /// Retrieves full history of emergency incidents.
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents();

  /// Updates the status of an existing emergency incident.
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(
    String incidentId,
    EmergencyStatus status,
  );

  /// Cancels an active emergency incident with an optional cancellation reason.
  Future<AppResult<EmergencyIncident>> cancelIncident(
    String incidentId, {
    String? reason,
  });

  /// Assigns responder telemetry and contact details to an incident.
  Future<AppResult<EmergencyIncident>> assignResponder(
    String incidentId, {
    required String responderId,
    required String responderName,
    String? responderPhone,
    String? responderType,
    double? responderLat,
    double? responderLng,
    int? etaMinutes,
  });

  /// Releases resources and closes internal stream controllers.
  void dispose();
}
