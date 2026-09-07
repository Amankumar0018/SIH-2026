import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/user_profile.dart';
import 'package:pukaar/core/services/api_service.dart';
import 'package:pukaar/core/services/auth_service.dart';
import 'package:pukaar/core/services/storage_service.dart';
import 'package:pukaar/core/utils/app_result.dart';

class MockTestApiService implements ApiService {
  String? token;
  Map<String, dynamic>? lastBody;

  @override
  void setAuthToken(String? token) {
    this.token = token;
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(String endpoint, {Map<String, dynamic>? body}) async {
    lastBody = body;
    if (endpoint == '/auth/login') {
      if (body?['password'] == 'wrong') {
        return AppResult.failure('Invalid mobile number or password.');
      }
      final mobile = body?['mobileNumber'];
      final role = (mobile == '9000000000')
          ? 'responder'
          : (mobile == '9999999999')
              ? 'dual'
              : 'citizen';
      return AppResult.success({
        'accessToken': 'api_token_12345',
        'tokenType': 'bearer',
        'role': role,
        'mobileNumber': mobile,
        'name': role == 'responder'
            ? 'Responder One'
            : role == 'dual'
                ? 'Dual One'
                : 'Citizen One',
      });
    } else if (endpoint == '/auth/register') {
      if (body?['mobileNumber'] == '0000000000') {
        return AppResult.failure('An account with this mobile number already exists.');
      }
      return AppResult.success({
        'accessToken': 'api_token_67890',
        'tokenType': 'bearer',
        'role': body?['role'] ?? 'citizen',
        'mobileNumber': body?['mobileNumber'],
        'name': body?['name'],
      });
    }
    return AppResult.failure('Unknown endpoint');
  }

  @override
  Future<AppResult<Map<String, dynamic>>> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (endpoint == '/auth/me') {
      if (token == null) return AppResult.failure('Missing authentication credentials.');
      return AppResult.success({
        'status': 'success',
        'user': {
          'id': 'USR_1',
          'name': 'Authenticated User',
          'mobileNumber': '9876543210',
          'role': 'citizen',
        }
      });
    }
    return AppResult.failure('Not found');
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(String endpoint, {Map<String, dynamic>? body}) async {
    return AppResult.success({});
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    return AppResult.success(true);
  }
}

void main() {
  late InMemoryStorageService storageService;
  late MockTestApiService apiService;
  late ApiAuthService apiAuthService;
  late MockAuthService mockAuthService;

  setUp(() {
    storageService = InMemoryStorageService();
    apiService = MockTestApiService();
    apiAuthService = ApiAuthService(apiService, storageService);
    mockAuthService = MockAuthService(storageService);
  });

  group('MockAuthService Tests', () {
    test('MockAuthService default role and token', () async {
      expect(mockAuthService.getRole(), equals('citizen'));
      expect(mockAuthService.getAuthToken(), equals('mock_bearer_token_123'));
    });

    test('MockAuthService loginWithPassword for citizen, responder, and dual', () async {
      final citizenRes = await mockAuthService.loginWithPassword('9876543210', 'password123');
      expect(citizenRes.isSuccess, isTrue);
      expect(citizenRes.data!.role, equals('citizen'));
      expect(citizenRes.data!.isResponder, isFalse);
      expect(citizenRes.data!.isCitizen, isTrue);

      final responderRes = await mockAuthService.loginWithPassword('9000000000', 'responder123');
      expect(responderRes.isSuccess, isTrue);
      expect(responderRes.data!.role, equals('responder'));
      expect(responderRes.data!.isResponder, isTrue);

      final dualRes = await mockAuthService.loginWithPassword('9999999999', 'dual123');
      expect(dualRes.isSuccess, isTrue);
      expect(dualRes.data!.role, equals('dual'));
      expect(dualRes.data!.isResponder, isTrue);
      expect(dualRes.data!.isDual, isTrue);
      expect(dualRes.data!.isCitizen, isTrue);
    });

    test('MockAuthService verifyOtp returns profile', () async {
      final res = await mockAuthService.verifyOtp('9876543210', '123456');
      expect(res.isSuccess, isTrue);
      expect(res.data!.mobileNumber, equals('9876543210'));

      final invalidRes = await mockAuthService.verifyOtp('9876543210', '999999');
      expect(invalidRes.isFailure, isTrue);
    });

    test('MockAuthService logout clears session profile completely', () async {
      await mockAuthService.loginWithPassword('9876543210', 'password123');
      expect(await mockAuthService.isLoggedIn(), isTrue);

      await mockAuthService.logout();
      expect(await mockAuthService.isLoggedIn(), isFalse);
      expect(await mockAuthService.getCurrentUser(), isNull);
    });
  });

  group('ApiAuthService Backend Integration Tests', () {
    test('ApiAuthService loginWithPassword citizen success', () async {
      final res = await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(res.isSuccess, isTrue);
      expect(res.data!.token, equals('api_token_12345'));
      expect(res.data!.role, equals('citizen'));
      expect(apiService.token, equals('api_token_12345'));
      expect(apiAuthService.getAuthToken(), equals('api_token_12345'));
      expect(apiAuthService.getRole(), equals('citizen'));
    });

    test('ApiAuthService loginWithPassword responder success', () async {
      final res = await apiAuthService.loginWithPassword('9000000000', 'responder123');
      expect(res.isSuccess, isTrue);
      expect(res.data!.role, equals('responder'));
      expect(res.data!.isResponder, isTrue);
      expect(apiAuthService.getRole(), equals('responder'));
    });

    test('ApiAuthService loginWithPassword dual role success', () async {
      final res = await apiAuthService.loginWithPassword('9999999999', 'dual123');
      expect(res.isSuccess, isTrue);
      expect(res.data!.role, equals('dual'));
      expect(res.data!.isResponder, isTrue);
      expect(res.data!.isDual, isTrue);
      expect(res.data!.isCitizen, isTrue);
    });

    test('ApiAuthService loginWithPassword invalid credentials', () async {
      final res = await apiAuthService.loginWithPassword('9876543210', 'wrong');
      expect(res.isFailure, isTrue);
      expect(res.errorMessage, contains('Invalid'));
    });

    test('ApiAuthService registerUser success', () async {
      final profile = const UserProfile(
        name: 'Jane Dual',
        mobileNumber: '9123456789',
        role: 'dual',
        emergencyContactName: 'HQ',
        emergencyContactPhone: '112',
      );

      final res = await apiAuthService.registerUser(profile, password: 'securepassword');
      expect(res.isSuccess, isTrue);
      expect(res.data!.token, equals('api_token_67890'));
      expect(res.data!.role, equals('dual'));
      expect(res.data!.isResponder, isTrue);
      expect(apiService.token, equals('api_token_67890'));
    });

    test('ApiAuthService registerUser invalid existing mobile', () async {
      final profile = const UserProfile(
        name: 'Existing User',
        mobileNumber: '0000000000',
        role: 'citizen',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '100',
      );

      final res = await apiAuthService.registerUser(profile, password: 'password123');
      expect(res.isFailure, isTrue);
      expect(res.errorMessage, contains('already exists'));
    });

    test('ApiAuthService logout clears session and token', () async {
      await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(apiAuthService.getAuthToken(), isNotNull);

      await apiAuthService.logout();
      expect(apiAuthService.getAuthToken(), isNull);
      expect(apiService.token, isNull);
      final loggedIn = await apiAuthService.isLoggedIn();
      expect(loggedIn, isFalse);
      expect(await apiAuthService.getCurrentUser(), isNull);
    });
  });
}
