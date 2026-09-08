import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/services/api_service.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/secure_storage_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/services/storage_service.dart';
import 'package:pukaar/core/utils/app_result.dart';
import 'package:pukaar/main.dart';

class MockWidgetTestApiService implements ApiService {
  String? token;
  bool return401 = false;
  bool returnNetworkError = false;

  @override
  void setAuthToken(String? token) {
    this.token = token;
  }

  @override
  Future<AppResult<Map<String, dynamic>>> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (endpoint == '/auth/me') {
      if (returnNetworkError) {
        return AppResult.failure('Network connection failure', statusCode: null);
      }
      if (return401 || token == null || token!.isEmpty) {
        return AppResult.failure('Unauthorized', statusCode: 401);
      }
      return AppResult.success({
        'status': 'success',
        'user': {
          'id': '1',
          'name': 'Pukaar Citizen User',
          'mobileNumber': '9876543210',
          'role': 'citizen',
        }
      }, statusCode: 200);
    }
    return AppResult.failure('Not found', statusCode: 404);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(String endpoint, {Map<String, dynamic>? body}) async {
    return AppResult.success({'status': 'ok'}, statusCode: 200);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(String endpoint, {Map<String, dynamic>? body}) async {
    return AppResult.success({'status': 'ok'}, statusCode: 200);
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    return AppResult.success(true, statusCode: 200);
  }
}

void main() {
  testWidgets('Pukaar App first launch goes to Onboarding', (WidgetTester tester) async {
    ServiceLocator.instance.init(
      customLocationService: MockLocationService(),
    );

    await tester.pumpWidget(const PukaarApp());
    expect(find.text('PUKAAR'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Welcome to Pukaar'), findsOneWidget);
    expect(find.text('One platform for emergency help.'), findsOneWidget);
  });

  testWidgets('Pukaar App onboarding complete but logged out goes to Login', (WidgetTester tester) async {
    final storage = InMemoryStorageService();
    final secureStorage = InMemorySecureStorageService();
    await storage.setBool('pukaar_onboarding_completed', true);

    ServiceLocator.instance.init(
      customStorageService: storage,
      customSecureStorageService: secureStorage,
      customLocationService: MockLocationService(),
    );

    await tester.pumpWidget(const PukaarApp());
    expect(find.text('PUKAAR'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('Pukaar App already logged in with valid token goes to Home directly', (WidgetTester tester) async {
    final storage = InMemoryStorageService();
    final secureStorage = InMemorySecureStorageService();
    final apiService = MockWidgetTestApiService();

    await storage.setBool('pukaar_onboarding_completed', true);
    await storage.setBool('pukaar_is_logged_in', true);
    await storage.setString('pukaar_user_profile', '{"name":"Citizen","mobileNumber":"9876543210","role":"citizen"}');
    await secureStorage.write('pukaar_auth_token', 'valid_token_123');

    ServiceLocator.instance.init(
      customApiService: apiService,
      customStorageService: storage,
      customSecureStorageService: secureStorage,
      customLocationService: MockLocationService(),
      useBackendApi: true,
    );

    await tester.pumpWidget(const PukaarApp());
    expect(find.text('PUKAAR'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Pukaar'), findsOneWidget);
  });

  testWidgets('Pukaar App startup with invalid token (401) logs out and goes to Login', (WidgetTester tester) async {
    final storage = InMemoryStorageService();
    final secureStorage = InMemorySecureStorageService();
    final apiService = MockWidgetTestApiService()..return401 = true;

    await storage.setBool('pukaar_onboarding_completed', true);
    await storage.setBool('pukaar_is_logged_in', true);
    await storage.setString('pukaar_user_profile', '{"name":"Citizen","mobileNumber":"9876543210","role":"citizen"}');
    await secureStorage.write('pukaar_auth_token', 'expired_token_123');

    ServiceLocator.instance.init(
      customApiService: apiService,
      customStorageService: storage,
      customSecureStorageService: secureStorage,
      customLocationService: MockLocationService(),
      useBackendApi: true,
    );

    await tester.pumpWidget(const PukaarApp());
    expect(find.text('PUKAAR'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(await secureStorage.read('pukaar_auth_token'), isNull);
  });

  testWidgets('Pukaar App startup with network failure preserves session and routes to Home', (WidgetTester tester) async {
    final storage = InMemoryStorageService();
    final secureStorage = InMemorySecureStorageService();
    final apiService = MockWidgetTestApiService()..returnNetworkError = true;

    await storage.setBool('pukaar_onboarding_completed', true);
    await storage.setBool('pukaar_is_logged_in', true);
    await storage.setString('pukaar_user_profile', '{"name":"Citizen","mobileNumber":"9876543210","role":"citizen"}');
    await secureStorage.write('pukaar_auth_token', 'offline_saved_token');

    ServiceLocator.instance.init(
      customApiService: apiService,
      customStorageService: storage,
      customSecureStorageService: secureStorage,
      customLocationService: MockLocationService(),
      useBackendApi: true,
    );

    await tester.pumpWidget(const PukaarApp());
    expect(find.text('PUKAAR'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Session preserved, went to Home
    expect(find.text('Pukaar'), findsOneWidget);
    expect(await secureStorage.read('pukaar_auth_token'), equals('offline_saved_token'));
  });
}
