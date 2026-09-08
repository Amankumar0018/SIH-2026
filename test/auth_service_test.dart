import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/user_profile.dart';
import 'package:pukaar/core/services/api_service.dart';
import 'package:pukaar/core/services/auth_service.dart';
import 'package:pukaar/core/services/realtime_service.dart';
import 'package:pukaar/core/services/secure_storage_service.dart';
import 'package:pukaar/core/services/storage_service.dart';
import 'package:pukaar/core/utils/app_result.dart';

class MockTestApiService implements ApiService {
  String? token;
  Map<String, dynamic>? lastBody;
  bool return401OnAuthMe = false;
  bool returnNetworkErrorOnAuthMe = false;
  bool logoutCalled = false;
  String? tokenSeenDuringAuthMe;

  @override
  void setAuthToken(String? token) {
    this.token = token;
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(String endpoint, {Map<String, dynamic>? body}) async {
    lastBody = body;
    if (endpoint == '/auth/login') {
      if (body?['password'] == 'wrong') {
        return AppResult.failure('Invalid mobile number or password.', statusCode: 401);
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
      }, statusCode: 200);
    } else if (endpoint == '/auth/register') {
      if (body?['mobileNumber'] == '0000000000') {
        return AppResult.failure('An account with this mobile number already exists.', statusCode: 400);
      }
      return AppResult.success({
        'accessToken': 'api_token_67890',
        'tokenType': 'bearer',
        'role': body?['role'] ?? 'citizen',
        'mobileNumber': body?['mobileNumber'],
        'name': body?['name'],
      }, statusCode: 201);
    } else if (endpoint == '/auth/logout') {
      logoutCalled = true;
      return AppResult.success({'status': 'success'}, statusCode: 200);
    }
    return AppResult.failure('Unknown endpoint', statusCode: 404);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (endpoint == '/auth/me') {
      tokenSeenDuringAuthMe = token;
      if (returnNetworkErrorOnAuthMe) {
        return AppResult.failure('Network connection error: connection refused', statusCode: null);
      }
      if (return401OnAuthMe || token == null || token!.isEmpty) {
        return AppResult.failure('Unauthorized: invalid or missing credentials', statusCode: 401);
      }
      return AppResult.success({
        'status': 'success',
        'user': {
          'id': 'USR_1',
          'name': 'Authenticated User',
          'mobileNumber': '9876543210',
          'role': 'citizen',
        }
      }, statusCode: 200);
    }
    return AppResult.failure('Not found', statusCode: 404);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(String endpoint, {Map<String, dynamic>? body}) async {
    return AppResult.success({}, statusCode: 200);
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    return AppResult.success(true, statusCode: 200);
  }
}

void main() {
  late InMemoryStorageService storageService;
  late InMemorySecureStorageService secureStorageService;
  late MockTestApiService apiService;
  late ApiAuthService apiAuthService;
  late MockAuthService mockAuthService;

  setUp(() {
    storageService = InMemoryStorageService();
    secureStorageService = InMemorySecureStorageService();
    apiService = MockTestApiService();
    apiAuthService = ApiAuthService(apiService, storageService, secureStorageService);
    mockAuthService = MockAuthService(storageService, secureStorageService);
  });

  group('MockAuthService Tests', () {
    test('MockAuthService default role and token (unauthenticated returns null token)', () async {
      expect(mockAuthService.getRole(), equals('citizen'));
      expect(mockAuthService.getAuthToken(), isNull);
    });

    test('MockAuthService loginWithPassword for citizen, responder, and dual', () async {
      final citizenRes = await mockAuthService.loginWithPassword('9876543210', 'password123');
      expect(citizenRes.isSuccess, isTrue);
      expect(citizenRes.data!.role, equals('citizen'));
      expect(citizenRes.data!.isResponder, isFalse);
      expect(citizenRes.data!.isCitizen, isTrue);
      expect(mockAuthService.getAuthToken(), equals('mock_token_9876543210'));

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
      expect(mockAuthService.getAuthToken(), equals('mock_token_9876543210'));

      final invalidRes = await mockAuthService.verifyOtp('9876543210', '999999');
      expect(invalidRes.isFailure, isTrue);
    });

    test('MockAuthService logout clears session profile and token completely', () async {
      await mockAuthService.loginWithPassword('9876543210', 'password123');
      expect(await mockAuthService.isLoggedIn(), isTrue);
      expect(mockAuthService.getAuthToken(), isNotNull);

      await mockAuthService.logout();
      expect(await mockAuthService.isLoggedIn(), isFalse);
      expect(mockAuthService.getAuthToken(), isNull);
      expect(await mockAuthService.getCurrentUser(), isNull);
    });

    test('MockAuthService validateSession', () async {
      final failRes = await mockAuthService.validateSession();
      expect(failRes.isFailure, isTrue);

      await mockAuthService.loginWithPassword('9876543210', 'password123');
      final passRes = await mockAuthService.validateSession();
      expect(passRes.isSuccess, isTrue);
    });
  });

  group('ApiAuthService Lifecycle and Storage Security Tests', () {
    test('1. Fresh install: no session -> validateSession fails without calling /auth/me', () async {
      expect(await apiAuthService.isLoggedIn(), isFalse);
      expect(apiAuthService.getAuthToken(), isNull);
      
      final res = await apiAuthService.validateSession();
      expect(res.isFailure, isTrue);
      expect(res.statusCode, equals(401));
      expect(apiService.tokenSeenDuringAuthMe, isNull);
    });

    test('2. Login: token saved securely and profile saved without token in normal storage', () async {
      final res = await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(res.isSuccess, isTrue);
      expect(res.data!.token, equals('api_token_12345'));
      expect(apiService.token, equals('api_token_12345'));

      // Check SecureStorageService contains the token
      final secureToken = await secureStorageService.read('pukaar_auth_token');
      expect(secureToken, equals('api_token_12345'));

      // Check standard StorageService contains profile WITHOUT the token
      final rawProfileJson = await storageService.getString('pukaar_user_profile');
      expect(rawProfileJson, isNotNull);
      final decodedMap = json.decode(rawProfileJson!) as Map<String, dynamic>;
      expect(decodedMap.containsKey('token'), isFalse);
    });

    test('3. Session restoration: token restored into ApiService before /auth/me call', () async {
      // Simulate persisted state from prior run
      await storageService.setBool('pukaar_is_logged_in', true);
      const profile = UserProfile(
        name: 'Restored User',
        mobileNumber: '9876543210',
        role: 'citizen',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '100',
      );
      await storageService.setString('pukaar_user_profile', json.encode(profile.toJson()));
      await secureStorageService.write('pukaar_auth_token', 'restored_token_999');

      // Create a fresh ApiAuthService instance representing app restart
      final freshApiService = MockTestApiService();
      final freshAuthService = ApiAuthService(freshApiService, storageService, secureStorageService);

      expect(freshApiService.token, isNull);

      final valResult = await freshAuthService.validateSession();
      expect(valResult.isSuccess, isTrue);

      // Verify token was attached to ApiService before /auth/me was requested
      expect(freshApiService.tokenSeenDuringAuthMe, equals('restored_token_999'));
      expect(freshApiService.token, equals('restored_token_999'));
      expect(await freshAuthService.isLoggedIn(), isTrue);
    });

    test('4. Valid token: /auth/me 200 keeps session active and updates profile', () async {
      await apiAuthService.loginWithPassword('9876543210', 'password123');
      
      final res = await apiAuthService.validateSession();
      expect(res.isSuccess, isTrue);
      expect(await apiAuthService.isLoggedIn(), isTrue);
      expect(apiAuthService.getAuthToken(), equals('api_token_12345'));
    });

    test('5. Invalid token: /auth/me 401 deletes token, clears profile, logs out user', () async {
      await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(await apiAuthService.isLoggedIn(), isTrue);

      apiService.return401OnAuthMe = true;

      final res = await apiAuthService.validateSession();
      expect(res.isFailure, isTrue);
      expect(res.statusCode, equals(401));

      // Local session must be completely cleared
      expect(await apiAuthService.isLoggedIn(), isFalse);
      expect(apiAuthService.getAuthToken(), isNull);
      expect(apiService.token, isNull);
      expect(await secureStorageService.read('pukaar_auth_token'), isNull);
      expect(await storageService.getString('pukaar_user_profile'), isNull);
    });

    test('6. Network failure: validateSession failure does NOT delete persisted token or log out', () async {
      await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(await apiAuthService.isLoggedIn(), isTrue);

      apiService.returnNetworkErrorOnAuthMe = true;

      final res = await apiAuthService.validateSession();
      expect(res.isFailure, isTrue);

      // Token and session MUST be preserved despite network error
      expect(await apiAuthService.isLoggedIn(), isTrue);
      expect(apiAuthService.getAuthToken(), equals('api_token_12345'));
      expect(await secureStorageService.read('pukaar_auth_token'), equals('api_token_12345'));
      expect(await storageService.getString('pukaar_user_profile'), isNotNull);
    });

    test('7. Logout: attempts backend revocation and clears local token, profile, and ApiService token', () async {
      await apiAuthService.loginWithPassword('9876543210', 'password123');
      expect(await apiAuthService.isLoggedIn(), isTrue);

      await apiAuthService.logout();

      expect(apiService.logoutCalled, isTrue);
      expect(apiAuthService.getAuthToken(), isNull);
      expect(apiService.token, isNull);
      expect(await apiAuthService.isLoggedIn(), isFalse);
      expect(await secureStorageService.read('pukaar_auth_token'), isNull);
      expect(await storageService.getString('pukaar_user_profile'), isNull);
    });

    test('ApiAuthService registerUser saves token securely without token in storage', () async {
      const profile = UserProfile(
        name: 'Jane Dual',
        mobileNumber: '9123456789',
        role: 'dual',
        emergencyContactName: 'HQ',
        emergencyContactPhone: '112',
      );

      final res = await apiAuthService.registerUser(profile, password: 'securepassword');
      expect(res.isSuccess, isTrue);
      expect(res.data!.token, equals('api_token_67890'));
      expect(apiService.token, equals('api_token_67890'));

      final secureToken = await secureStorageService.read('pukaar_auth_token');
      expect(secureToken, equals('api_token_67890'));

      final rawProfileJson = await storageService.getString('pukaar_user_profile');
      final decodedMap = json.decode(rawProfileJson!) as Map<String, dynamic>;
      expect(decodedMap.containsKey('token'), isFalse);
    });
  });

  group('WebSocket & Realtime Lifecycle Integration Tests', () {
    late InMemoryStorageService testStorage;
    late InMemorySecureStorageService testSecureStorage;
    late MockTestApiService testApi;
    late MockRealtimeService testRealtime;
    late ApiAuthService authServiceWithRealtime;

    setUp(() {
      testStorage = InMemoryStorageService();
      testSecureStorage = InMemorySecureStorageService();
      testApi = MockTestApiService();
      testRealtime = MockRealtimeService();
      authServiceWithRealtime = ApiAuthService(
        testApi,
        testStorage,
        testSecureStorage,
        testRealtime,
      );
    });

    test('WebSocket does NOT connect before restored session validation completes', () async {
      // Setup persisted session
      await testStorage.setBool('pukaar_is_logged_in', true);
      const profile = UserProfile(
        name: 'Saved User',
        mobileNumber: '9876543210',
        role: 'citizen',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '100',
      );
      await testStorage.setString('pukaar_user_profile', json.encode(profile.toJson()));
      await testSecureStorage.write('pukaar_auth_token', 'saved_token_123');

      // Create a new instance representing app cold start
      final coldStartAuth = ApiAuthService(testApi, testStorage, testSecureStorage, testRealtime);

      // 1. Reading current user or loggedIn status MUST NOT trigger realtime connect
      final currentUser = await coldStartAuth.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(testRealtime.isConnected, isFalse);

      final loggedIn = await coldStartAuth.isLoggedIn();
      expect(loggedIn, isTrue);
      expect(testRealtime.isConnected, isFalse);

      // 2. ONLY after validateSession() succeeds should realtime connect
      final valRes = await coldStartAuth.validateSession();
      expect(valRes.isSuccess, isTrue);
      expect(testRealtime.isConnected, isTrue);
    });

    test('Invalid restored session (401/403) does not connect or reconnect realtime service', () async {
      await testStorage.setBool('pukaar_is_logged_in', true);
      const profile = UserProfile(
        name: 'Stale User',
        mobileNumber: '9876543210',
        role: 'citizen',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '100',
      );
      await testStorage.setString('pukaar_user_profile', json.encode(profile.toJson()));
      await testSecureStorage.write('pukaar_auth_token', 'stale_token_after_restart');

      testApi.return401OnAuthMe = true;

      final coldStartAuth = ApiAuthService(testApi, testStorage, testSecureStorage, testRealtime);
      final valRes = await coldStartAuth.validateSession();

      expect(valRes.isFailure, isTrue);
      expect(valRes.statusCode, equals(401));
      expect(testRealtime.isConnected, isFalse);
      expect(await testSecureStorage.read('pukaar_auth_token'), isNull);
      expect(await coldStartAuth.isLoggedIn(), isFalse);
    });

    test('Temporary network failure preserves session but does not mark realtime connected', () async {
      await testStorage.setBool('pukaar_is_logged_in', true);
      const profile = UserProfile(
        name: 'Offline User',
        mobileNumber: '9876543210',
        role: 'citizen',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '100',
      );
      await testStorage.setString('pukaar_user_profile', json.encode(profile.toJson()));
      await testSecureStorage.write('pukaar_auth_token', 'persisted_offline_token');

      testApi.returnNetworkErrorOnAuthMe = true;

      final coldStartAuth = ApiAuthService(testApi, testStorage, testSecureStorage, testRealtime);
      final valRes = await coldStartAuth.validateSession();

      expect(valRes.isFailure, isTrue);
      // Preserves session
      expect(await coldStartAuth.isLoggedIn(), isTrue);
      expect(await testSecureStorage.read('pukaar_auth_token'), equals('persisted_offline_token'));
      // Does not connect realtime while unverified
      expect(testRealtime.isConnected, isFalse);
    });

    test('Successful login connects realtime and logout disconnects realtime', () async {
      final loginRes = await authServiceWithRealtime.loginWithPassword('9876543210', 'password123');
      expect(loginRes.isSuccess, isTrue);
      expect(testRealtime.isConnected, isTrue);

      await authServiceWithRealtime.logout();
      expect(testRealtime.isConnected, isFalse);
    });
  });
}
