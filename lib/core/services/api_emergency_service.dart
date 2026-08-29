import 'dart:async';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import '../repositories/emergency_repository.dart';
import '../utils/app_result.dart';
import 'auth_service.dart';
import 'emergency_service.dart';
import 'location_service.dart';

/// Production backend implementation of [EmergencyService] delegating persistence
/// and remote API communications to [EmergencyRepository].
class ApiEmergencyService implements EmergencyService {
  final EmergencyRepository repository;
  final LocationService? locationService;
  final AuthService? authService;

  String? _activeIncidentId;
  StreamSubscription<EmergencyIncident>? _repositorySubscription;

  ApiEmergencyService({
    required this.repository,
    this.locationService,
    this.authService,
  }) {
    // Listen to repository stream to keep track of active incident state
    _repositorySubscription = repository.incidentStream.listen((incident) {
      if (incident.status.isActive) {
        _activeIncidentId = incident.id;
      } else if (_activeIncidentId == incident.id) {
        _activeIncidentId = null;
      }
    });
  }

  @override
  Stream<EmergencyIncident> get incidentStream => repository.incidentStream;

  @override
  EmergencyIncident? get activeIncident => null; // Active incident cached via repository or query

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
      // 1. Resolve GPS location if missing
      double? lat = latitude;
      double? lng = longitude;
      double? acc = accuracy;
      String? gpsNote;

      if ((lat == null || lng == null) && locationService != null) {
        final locResult = await locationService!.getCurrentLocation();
        if (locResult.isSuccess && locResult.data != null) {
          lat = locResult.data!.latitude;
          lng = locResult.data!.longitude;
          acc = locResult.data!.accuracy;
        } else if (!locResult.isSuccess) {
          gpsNote = 'GPS status: ${locResult.errorMessage}';
        }
      }

      // 2. Resolve user session ID if missing
      String resolvedUserId = userId ?? 'guest_user';
      if (userId == null && authService != null) {
        final profile = await authService!.getCurrentUser();
        if (profile != null && profile.mobileNumber.isNotEmpty) {
          resolvedUserId = profile.mobileNumber;
        }
      }

      // 3. Generate incident ID and build model
      final String incidentId =
          'INC_${DateTime.now().millisecondsSinceEpoch}_${category.name.toUpperCase()}';

      final resolvedNotes = notes != null
          ? (gpsNote != null ? '$notes | $gpsNote' : notes)
          : gpsNote;

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

      // 4. Delegate creation to EmergencyRepository
      final result = await repository.createIncident(incident);
      if (result.isSuccess && result.data != null) {
        _activeIncidentId = result.data!.id;
      }
      return result;
    } catch (e) {
      return AppResult.failure('ApiEmergencyService creation failed: $e');
    }
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) async {
    return repository.getIncident(incidentId);
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async {
    return repository.getActiveIncidents();
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async {
    return repository.getAllIncidents();
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
    if (responderId != null && responderName != null) {
      final assignResult = await repository.assignResponder(
        incidentId,
        responderId: responderId,
        responderName: responderName,
        responderPhone: responderPhone,
        responderType: responderType,
        responderLat: responderLat,
        responderLng: responderLng,
        etaMinutes: etaMinutes,
      );

      if (!assignResult.isSuccess) {
        return assignResult;
      }
    }

    return repository.updateIncidentStatus(incidentId, newStatus);
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async {
    final result = await repository.cancelIncident(incidentId, reason: reason);
    if (result.isSuccess && _activeIncidentId == incidentId) {
      _activeIncidentId = null;
    }
    return result;
  }

  @override
  void dispose() {
    _repositorySubscription?.cancel();
    repository.dispose();
  }
}
