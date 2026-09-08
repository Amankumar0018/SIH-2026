import 'dart:async';
import '../config/app_config.dart';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../utils/app_result.dart';
import 'emergency_repository.dart';

/// Backend-ready production implementation of [EmergencyRepository] communicating
/// through the application's [ApiService] abstraction and receiving real-time push events
/// through [RealtimeService].
class ApiEmergencyRepository implements EmergencyRepository {
  final ApiService _apiService;
  final RealtimeService? _realtimeService;
  final StreamController<EmergencyIncident> _streamController =
      StreamController<EmergencyIncident>.broadcast();
  StreamSubscription<EmergencyIncident>? _realtimeSubscription;

  ApiEmergencyRepository(this._apiService, [this._realtimeService]) {
    if (_realtimeService != null) {
      _realtimeSubscription = _realtimeService.incidentStream.listen((incident) {
        _streamController.add(incident);
      });
    }
  }

  @override
  Stream<EmergencyIncident> get incidentStream => _streamController.stream;

  @override
  Future<AppResult<EmergencyIncident>> createIncident(EmergencyIncident incident) async {
    try {
      final response = await _apiService.post(
        AppConfig.incidentsEndpoint,
        body: incident.toJson(),
      );

      if (!response.isSuccess) {
        return AppResult.failure(response.errorMessage ?? 'API request failed while creating incident.');
      }

      final data = response.data;
      if (data == null) {
        return AppResult.failure('API returned null data response for incident creation.');
      }

      // Extract payload (support top-level object or wrapped 'data'/'incident' key)
      final payload = (data['incident'] ?? data['data'] ?? data) as Map<String, dynamic>;
      final createdIncident = EmergencyIncident.fromJson(payload);

      _streamController.add(createdIncident);
      return AppResult.success(createdIncident);
    } catch (e) {
      return AppResult.failure('Backend incident creation error: $e');
    }
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncident(String incidentId) async {
    try {
      final endpoint = AppConfig.incidentDetailEndpoint(incidentId);
      final response = await _apiService.get(endpoint);

      if (!response.isSuccess) {
        return AppResult.failure(response.errorMessage ?? 'Failed to retrieve incident $incidentId.');
      }

      final data = response.data;
      if (data == null) {
        return AppResult.failure('Incident "$incidentId" not found on backend server.');
      }

      final payload = (data['incident'] ?? data['data'] ?? data) as Map<String, dynamic>;
      final incident = EmergencyIncident.fromJson(payload);
      return AppResult.success(incident);
    } catch (e) {
      return AppResult.failure('Backend incident retrieval error: $e');
    }
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async {
    try {
      final response = await _apiService.get(AppConfig.activeIncidentsEndpoint);
      return _parseIncidentListResponse(response, 'Failed to fetch active incidents');
    } catch (e) {
      return AppResult.failure('Backend active incidents error: $e');
    }
  }

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async {
    try {
      final response = await _apiService.get(AppConfig.incidentsEndpoint);
      return _parseIncidentListResponse(response, 'Failed to fetch all incidents');
    } catch (e) {
      return AppResult.failure('Backend incident history error: $e');
    }
  }

  @override
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(
    String incidentId,
    EmergencyStatus status,
  ) async {
    try {
      final endpoint = AppConfig.updateStatusEndpoint(incidentId);
      final response = await _apiService.put(
        endpoint,
        body: {'status': status.name},
      );

      if (!response.isSuccess) {
        return AppResult.failure(response.errorMessage ?? 'Failed to update status for incident $incidentId.');
      }

      final data = response.data;
      if (data == null) {
        return AppResult.failure('Server returned empty payload on status update.');
      }

      final payload = (data['incident'] ?? data['data'] ?? data) as Map<String, dynamic>;
      final updatedIncident = EmergencyIncident.fromJson(payload);

      _streamController.add(updatedIncident);
      return AppResult.success(updatedIncident);
    } catch (e) {
      return AppResult.failure('Backend status update error: $e');
    }
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(
    String incidentId, {
    String? reason,
  }) async {
    try {
      final endpoint = AppConfig.cancelIncidentEndpoint(incidentId);
      final response = await _apiService.post(
        endpoint,
        body: {'reason': reason ?? 'User requested cancellation'},
      );

      if (!response.isSuccess) {
        return AppResult.failure(response.errorMessage ?? 'Failed to cancel incident $incidentId.');
      }

      final data = response.data;
      if (data == null) {
        return AppResult.failure('Server returned empty payload on incident cancellation.');
      }

      final payload = (data['incident'] ?? data['data'] ?? data) as Map<String, dynamic>;
      final cancelledIncident = EmergencyIncident.fromJson(payload);

      _streamController.add(cancelledIncident);
      return AppResult.success(cancelledIncident);
    } catch (e) {
      return AppResult.failure('Backend incident cancellation error: $e');
    }
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
    try {
      final endpoint = AppConfig.assignResponderEndpoint(incidentId);
      final body = {
        'responderId': responderId,
        'responderName': responderName,
        'responderPhone': responderPhone,
        'responderType': responderType,
        'responderLatitude': responderLat,
        'responderLongitude': responderLng,
        'estimatedArrivalMinutes': etaMinutes,
      };

      final response = await _apiService.post(endpoint, body: body);

      if (!response.isSuccess) {
        return AppResult.failure(response.errorMessage ?? 'Failed to assign responder to $incidentId.');
      }

      final data = response.data;
      if (data == null) {
        return AppResult.failure('Server returned empty response on responder assignment.');
      }

      final payload = (data['incident'] ?? data['data'] ?? data) as Map<String, dynamic>;
      final updatedIncident = EmergencyIncident.fromJson(payload);

      _streamController.add(updatedIncident);
      return AppResult.success(updatedIncident);
    } catch (e) {
      return AppResult.failure('Backend responder assignment error: $e');
    }
  }

  AppResult<List<EmergencyIncident>> _parseIncidentListResponse(
    AppResult<Map<String, dynamic>> response,
    String fallbackErrorMessage,
  ) {
    if (!response.isSuccess) {
      return AppResult.failure(response.errorMessage ?? fallbackErrorMessage);
    }

    final data = response.data;
    if (data == null) {
      return AppResult.success([]);
    }

    final rawList = data['incidents'] ?? data['data'] ?? data['items'];
    if (rawList is List) {
      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => EmergencyIncident.fromJson(json))
          .toList();
      return AppResult.success(list);
    }

    return AppResult.success([]);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _streamController.close();
  }
}
