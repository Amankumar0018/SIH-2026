import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/config/app_config.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/repositories/api_emergency_repository.dart';
import 'package:pukaar/core/repositories/mock_emergency_repository.dart';
import 'package:pukaar/core/services/api_emergency_service.dart';
import 'package:pukaar/core/services/api_service.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/utils/app_result.dart';

/// Test double implementation of [ApiService] for controlled backend API unit tests.
class StubApiService implements ApiService {
  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
  Map<String, dynamic>? putResponse;
  bool deleteResponse = true;

  bool shouldFailGet = false;
  bool shouldFailPost = false;
  bool shouldFailPut = false;

  String? lastEndpoint;
  Map<String, dynamic>? lastBody;
  String? authToken;

  @override
  void setAuthToken(String? token) {
    authToken = token;
  }


  @override
  Future<AppResult<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastEndpoint = endpoint;
    if (shouldFailGet) {
      return AppResult.failure('Network timeout on GET $endpoint');
    }
    return AppResult.success(getResponse ?? {'status': 'ok'});
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    lastEndpoint = endpoint;
    lastBody = body;
    if (shouldFailPost) {
      return AppResult.failure('500 Server Error on POST $endpoint');
    }
    return AppResult.success(postResponse ?? {'status': 'created'});
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    lastEndpoint = endpoint;
    lastBody = body;
    if (shouldFailPut) {
      return AppResult.failure('400 Bad Request on PUT $endpoint');
    }
    return AppResult.success(putResponse ?? {'status': 'updated'});
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    lastEndpoint = endpoint;
    return AppResult.success(deleteResponse);
  }
}

void main() {
  group('AppConfig Tests', () {
    test('AppConfig provides valid default URLs and endpoint paths', () {
      expect(AppConfig.baseUrl, isNotEmpty);
      expect(AppConfig.incidentsEndpoint, equals('/incidents'));
      expect(AppConfig.activeIncidentsEndpoint, equals('/incidents/active'));
      expect(AppConfig.incidentDetailEndpoint('INC123'), equals('/incidents/INC123'));
      expect(AppConfig.cancelIncidentEndpoint('INC123'), equals('/incidents/INC123/cancel'));
      expect(AppConfig.updateStatusEndpoint('INC123'), equals('/incidents/INC123/status'));
      expect(AppConfig.assignResponderEndpoint('INC123'), equals('/incidents/INC123/assign-responder'));
      expect(AppConfig.useBackendApi, isFalse);
    });
  });

  group('MockEmergencyRepository Tests', () {
    late MockEmergencyRepository repository;

    setUp(() {
      repository = MockEmergencyRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('createIncident stores incident and broadcasts via stream', () async {
      final incident = EmergencyIncident(
        id: 'INC_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        timestamp: DateTime.now(),
      );

      final streamExpectation = expectLater(
        repository.incidentStream,
        emits(predicate<EmergencyIncident>((i) => i.id == 'INC_001')),
      );

      final result = await repository.createIncident(incident);
      expect(result.isSuccess, isTrue);
      expect(result.data?.id, equals('INC_001'));

      await streamExpectation;

      final getResult = await repository.getIncident('INC_001');
      expect(getResult.isSuccess, isTrue);
      expect(getResult.data?.intent, equals('Ambulance'));
    });

    test('updateIncidentStatus updates status and broadcasts update', () async {
      final incident = EmergencyIncident(
        id: 'INC_002',
        userId: 'user_1',
        category: EmergencyCategory.womenSafety,
        intent: 'Harassment',
        timestamp: DateTime.now(),
      );

      await repository.createIncident(incident);
      final updateResult = await repository.updateIncidentStatus('INC_002', EmergencyStatus.searching);

      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.data?.status, equals(EmergencyStatus.searching));
    });

    test('cancelIncident sets status to cancelled', () async {
      final incident = EmergencyIncident(
        id: 'INC_003',
        userId: 'user_1',
        category: EmergencyCategory.disaster,
        intent: 'Fire',
        timestamp: DateTime.now(),
      );

      await repository.createIncident(incident);
      final cancelResult = await repository.cancelIncident('INC_003', reason: 'False Alarm');

      expect(cancelResult.isSuccess, isTrue);
      expect(cancelResult.data?.status, equals(EmergencyStatus.cancelled));
      expect(cancelResult.data?.notes, contains('False Alarm'));
    });

    test('assignResponder updates responder details', () async {
      final incident = EmergencyIncident(
        id: 'INC_004',
        userId: 'user_1',
        category: EmergencyCategory.campus,
        intent: 'Security',
        timestamp: DateTime.now(),
      );

      await repository.createIncident(incident);
      final assignResult = await repository.assignResponder(
        'INC_004',
        responderId: 'RESP_99',
        responderName: 'Campus Officer Bob',
        responderPhone: '112',
        etaMinutes: 3,
      );

      expect(assignResult.isSuccess, isTrue);
      expect(assignResult.data?.assignedResponderName, equals('Campus Officer Bob'));
      expect(assignResult.data?.estimatedArrivalMinutes, equals(3));
    });
  });

  group('ApiEmergencyRepository Tests', () {
    late StubApiService stubApi;
    late ApiEmergencyRepository repository;

    setUp(() {
      stubApi = StubApiService();
      repository = ApiEmergencyRepository(stubApi);
    });

    tearDown(() {
      repository.dispose();
    });

    test('createIncident posts to API endpoint and parses returned model', () async {
      final incident = EmergencyIncident(
        id: 'INC_API_100',
        userId: 'user_api',
        category: EmergencyCategory.medical,
        intent: 'Injury',
        timestamp: DateTime.now(),
      );

      stubApi.postResponse = {
        'status': 'success',
        'incident': incident.toJson(),
      };

      final result = await repository.createIncident(incident);

      expect(result.isSuccess, isTrue);
      expect(stubApi.lastEndpoint, equals(AppConfig.incidentsEndpoint));
      expect(result.data?.id, equals('INC_API_100'));
      expect(result.data?.intent, equals('Injury'));
    });

    test('createIncident handles network failure gracefully without crashing', () async {
      final incident = EmergencyIncident(
        id: 'INC_FAIL',
        userId: 'user_api',
        category: EmergencyCategory.medical,
        intent: 'Injury',
        timestamp: DateTime.now(),
      );

      stubApi.shouldFailPost = true;

      final result = await repository.createIncident(incident);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('500 Server Error'));
    });

    test('getIncident fetches from endpoint and parses payload', () async {
      final incident = EmergencyIncident(
        id: 'INC_DETAIL_1',
        userId: 'user_1',
        category: EmergencyCategory.womenSafety,
        intent: 'Escort',
        timestamp: DateTime.now(),
      );

      stubApi.getResponse = {'data': incident.toJson()};

      final result = await repository.getIncident('INC_DETAIL_1');

      expect(result.isSuccess, isTrue);
      expect(stubApi.lastEndpoint, equals(AppConfig.incidentDetailEndpoint('INC_DETAIL_1')));
      expect(result.data?.intent, equals('Escort'));
    });

    test('getActiveIncidents parses list response', () async {
      final i1 = EmergencyIncident(
        id: 'INC_ACT_1',
        userId: 'u1',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        timestamp: DateTime.now(),
      );
      final i2 = EmergencyIncident(
        id: 'INC_ACT_2',
        userId: 'u2',
        category: EmergencyCategory.campus,
        intent: 'Fire',
        timestamp: DateTime.now(),
      );

      stubApi.getResponse = {
        'incidents': [i1.toJson(), i2.toJson()],
      };

      final result = await repository.getActiveIncidents();

      expect(result.isSuccess, isTrue);
      expect(result.data?.length, equals(2));
      expect(result.data?.first.id, equals('INC_ACT_1'));
    });

    test('updateIncidentStatus sends PUT request to status endpoint', () async {
      final updated = EmergencyIncident(
        id: 'INC_UPD_1',
        userId: 'u1',
        category: EmergencyCategory.disaster,
        intent: 'Flood',
        status: EmergencyStatus.dispatched,
        timestamp: DateTime.now(),
      );

      stubApi.putResponse = {'incident': updated.toJson()};

      final result = await repository.updateIncidentStatus('INC_UPD_1', EmergencyStatus.dispatched);

      expect(result.isSuccess, isTrue);
      expect(stubApi.lastEndpoint, equals(AppConfig.updateStatusEndpoint('INC_UPD_1')));
      expect(result.data?.status, equals(EmergencyStatus.dispatched));
    });

    test('cancelIncident sends POST request to cancel endpoint', () async {
      final cancelled = EmergencyIncident(
        id: 'INC_CNC_1',
        userId: 'u1',
        category: EmergencyCategory.disaster,
        intent: 'Flood',
        status: EmergencyStatus.cancelled,
        timestamp: DateTime.now(),
      );

      stubApi.postResponse = {'incident': cancelled.toJson()};

      final result = await repository.cancelIncident('INC_CNC_1', reason: 'User resolved');

      expect(result.isSuccess, isTrue);
      expect(stubApi.lastEndpoint, equals(AppConfig.cancelIncidentEndpoint('INC_CNC_1')));
      expect(result.data?.status, equals(EmergencyStatus.cancelled));
    });

    test('assignResponder sends POST request with responder parameters', () async {
      final assigned = EmergencyIncident(
        id: 'INC_RSP_1',
        userId: 'u1',
        category: EmergencyCategory.medical,
        intent: 'Trauma',
        assignedResponderId: 'R101',
        assignedResponderName: 'Trauma Team Alpha',
        timestamp: DateTime.now(),
      );

      stubApi.postResponse = {'incident': assigned.toJson()};

      final result = await repository.assignResponder(
        'INC_RSP_1',
        responderId: 'R101',
        responderName: 'Trauma Team Alpha',
        responderPhone: '102',
        etaMinutes: 5,
      );

      expect(result.isSuccess, isTrue);
      expect(stubApi.lastEndpoint, equals(AppConfig.assignResponderEndpoint('INC_RSP_1')));
      expect(stubApi.lastBody?['responderId'], equals('R101'));
      expect(stubApi.lastBody?['responderName'], equals('Trauma Team Alpha'));
    });
  });

  group('ApiEmergencyService Integration Tests', () {
    late MockEmergencyRepository mockRepository;
    late MockLocationService mockLocation;
    late ApiEmergencyService service;

    setUp(() {
      mockRepository = MockEmergencyRepository();
      mockLocation = MockLocationService();
      service = ApiEmergencyService(
        repository: mockRepository,
        locationService: mockLocation,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('createIncident resolves GPS coordinates and delegates to repository', () async {
      final result = await service.createIncident(
        category: EmergencyCategory.medical,
        intent: 'Cardiac Arrest',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.latitude, equals(28.6139));
      expect(result.data?.longitude, equals(77.2090));
      expect(result.data?.intent, equals('Cardiac Arrest'));

      final getResult = await service.getIncidentById(result.data!.id);
      expect(getResult.isSuccess, isTrue);
      expect(getResult.data?.intent, equals('Cardiac Arrest'));
    });

    test('cancelIncident delegates cancellation to repository', () async {
      final createResult = await service.createIncident(
        category: EmergencyCategory.campus,
        intent: 'Distress',
      );

      final incidentId = createResult.data!.id;

      final cancelResult = await service.cancelIncident(incidentId, reason: 'Safe now');
      expect(cancelResult.isSuccess, isTrue);
      expect(cancelResult.data?.status, equals(EmergencyStatus.cancelled));
    });
  });

  group('ServiceLocator DI Toggle Tests', () {
    test('ServiceLocator defaults to MockEmergencyService when initialized without flags', () {
      ServiceLocator.instance.init();
      expect(ServiceLocator.instance.emergencyService, isA<MockEmergencyService>());
      expect(ServiceLocator.instance.emergencyRepository, isA<MockEmergencyRepository>());
    });

    test('ServiceLocator initializes ApiEmergencyService when useBackendApi is true', () {
      ServiceLocator.instance.init(useBackendApi: true);
      expect(ServiceLocator.instance.emergencyService, isA<ApiEmergencyService>());
      expect(ServiceLocator.instance.emergencyRepository, isA<ApiEmergencyRepository>());
    });
  });
}
