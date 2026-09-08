import 'dart:convert';
import '../models/user_profile.dart';
import '../utils/app_result.dart';
import 'api_service.dart';
import 'realtime_service.dart';
import 'secure_storage_service.dart';
import 'storage_service.dart';

/// Contract interface for Pukaar user authentication and session management.
abstract class AuthService {
  Future<bool> isOnboardingCompleted();
  Future<void> setOnboardingCompleted(bool completed);

  Future<bool> isLoggedIn();
  Future<AppResult<void>> sendOtp(String mobileNumber);
  Future<AppResult<UserProfile>> verifyOtp(String mobileNumber, String otp);
  Future<AppResult<UserProfile>> loginWithPassword(String mobileNumber, String password);
  Future<AppResult<UserProfile>> registerUser(UserProfile profile, {String? password});
  Future<UserProfile?> getCurrentUser();
  Future<void> updateCurrentUser(UserProfile profile);
  Future<AppResult<bool>> validateSession();
  Future<void> logout();

  String? getAuthToken();
  String getRole();
}

/// Mock implementation of [AuthService] for development/testing phase.
/// Persists session and profile state using the provided [StorageService].
class MockAuthService implements AuthService {
  final StorageService _storageService;
  final SecureStorageService _secureStorageService;
  final RealtimeService? _realtimeService;
  UserProfile? _cachedProfile;

  static const String _kOnboardingCompleted = 'pukaar_onboarding_completed';
  static const String _kIsLoggedIn = 'pukaar_is_logged_in';
  static const String _kUserProfile = 'pukaar_user_profile';
  static const String _kAuthToken = 'pukaar_auth_token';

  MockAuthService(this._storageService, this._secureStorageService, [this._realtimeService]);

  @override
  String? getAuthToken() => _cachedProfile?.token;

  @override
  String getRole() => _cachedProfile?.role ?? 'citizen';

  @override
  Future<bool> isOnboardingCompleted() async {
    final val = await _storageService.getBool(_kOnboardingCompleted);
    return val ?? false;
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _storageService.setBool(_kOnboardingCompleted, completed);
  }

  @override
  Future<bool> isLoggedIn() async {
    final val = await _storageService.getBool(_kIsLoggedIn);
    return val ?? false;
  }

  @override
  Future<AppResult<void>> sendOtp(String mobileNumber) async {
    if (mobileNumber.length < 10) {
      return AppResult.failure('Please enter a valid 10-digit mobile number.');
    }
    await Future.delayed(const Duration(milliseconds: 100));
    return AppResult.success(null);
  }

  @override
  Future<AppResult<UserProfile>> verifyOtp(String mobileNumber, String otp) async {
    if (otp != '123456') {
      return AppResult.failure('Invalid OTP. Please enter 123456.');
    }

    await Future.delayed(const Duration(milliseconds: 100));

    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        final profile = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        final token = await _secureStorageService.read(_kAuthToken);
        _cachedProfile = profile.copyWith(token: token);
        await _storageService.setBool(_kIsLoggedIn, true);
        return AppResult.success(_cachedProfile!);
      } catch (_) {}
    }

    // Default mock profile assignment based on mobile number
    String role = 'citizen';
    if (mobileNumber == '9000000000') {
      role = 'responder';
    } else if (mobileNumber == '9999999999') {
      role = 'dual';
    }

    final token = 'mock_token_$mobileNumber';
    final partialProfile = UserProfile(
      name: role == 'responder' ? 'Demo Responder' : role == 'dual' ? 'Demo Dual User' : '',
      mobileNumber: mobileNumber,
      role: role,
      token: token,
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '102',
    );
    _cachedProfile = partialProfile;
    await _secureStorageService.write(_kAuthToken, token);
    final profileWithoutToken = partialProfile.withoutToken();
    await _storageService.setString(_kUserProfile, json.encode(profileWithoutToken.toJson()));
    await _storageService.setBool(_kIsLoggedIn, true);

    return AppResult.success(partialProfile);
  }

  @override
  Future<AppResult<UserProfile>> loginWithPassword(String mobileNumber, String password) async {
    if (mobileNumber.length < 10) {
      return AppResult.failure('Please enter a valid mobile number.');
    }
    if (password.trim().isEmpty) {
      return AppResult.failure('Password cannot be empty.');
    }

    await Future.delayed(const Duration(milliseconds: 100));

    // Check if user profile was saved during registration
    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        final stored = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        if (stored.mobileNumber == mobileNumber) {
          final token = await _secureStorageService.read(_kAuthToken);
          _cachedProfile = stored.copyWith(token: token);
          await _storageService.setBool(_kIsLoggedIn, true);
          return AppResult.success(_cachedProfile!);
        }
      } catch (_) {}
    }

    String role = 'citizen';
    String name = 'Demo Citizen';
    if (mobileNumber == '9000000000') {
      role = 'responder';
      name = 'Demo Responder';
    } else if (mobileNumber == '9999999999') {
      role = 'dual';
      name = 'Demo Dual User';
    }

    final profile = UserProfile(
      name: name,
      mobileNumber: mobileNumber,
      role: role,
      token: 'mock_token_$mobileNumber',
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '102',
    );

    _cachedProfile = profile;
    await _secureStorageService.write(_kAuthToken, profile.token!);
    final profileWithoutToken = profile.withoutToken();
    final jsonStrProfile = json.encode(profileWithoutToken.toJson());
    await _storageService.setString(_kUserProfile, jsonStrProfile);
    await _storageService.setBool(_kIsLoggedIn, true);

    _realtimeService?.connect(profile.token!);

    return AppResult.success(profile);
  }

  @override
  Future<AppResult<UserProfile>> registerUser(UserProfile profile, {String? password}) async {
    if (profile.name.trim().isEmpty) {
      return AppResult.failure('Full Name is required.');
    }
    if (profile.emergencyContactName.trim().isEmpty || profile.emergencyContactPhone.trim().isEmpty) {
      return AppResult.failure('Emergency Contact details are required.');
    }

    await Future.delayed(const Duration(milliseconds: 100));

    final profileWithToken = profile.copyWith(
      token: profile.token ?? 'mock_token_${profile.mobileNumber}',
    );

    _cachedProfile = profileWithToken;
    await _secureStorageService.write(_kAuthToken, profileWithToken.token!);
    final profileWithoutToken = profileWithToken.withoutToken();
    final jsonStr = json.encode(profileWithoutToken.toJson());
    await _storageService.setString(_kUserProfile, jsonStr);
    await _storageService.setBool(_kIsLoggedIn, true);

    _realtimeService?.connect(profileWithToken.token!);

    return AppResult.success(profileWithToken);
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    if (_cachedProfile != null) {
      return _cachedProfile;
    }

    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        final profile = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        final token = await _secureStorageService.read(_kAuthToken);
        _cachedProfile = profile.copyWith(token: token);
        return _cachedProfile;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> updateCurrentUser(UserProfile profile) async {
    _cachedProfile = profile;
    final profileWithoutToken = profile.withoutToken();
    final jsonStr = json.encode(profileWithoutToken.toJson());
    await _storageService.setString(_kUserProfile, jsonStr);
  }

  @override
  Future<AppResult<bool>> validateSession() async {
    final token = await _secureStorageService.read(_kAuthToken);
    final isLoggedIn = await this.isLoggedIn();
    if (!isLoggedIn || token == null || token.isEmpty) {
      await logout();
      return AppResult.failure('Not logged in', statusCode: 401);
    }
    _realtimeService?.connect(token);
    return AppResult.success(true, statusCode: 200);
  }

  @override
  Future<void> logout() async {
    _realtimeService?.disconnect();
    _cachedProfile = null;
    await _storageService.setBool(_kIsLoggedIn, false);
    await _storageService.remove(_kUserProfile);
    await _secureStorageService.delete(_kAuthToken);
  }
}

/// Backend REST implementation of [AuthService] connecting Flutter to FastAPI /auth.
class ApiAuthService implements AuthService {
  final ApiService _apiService;
  final StorageService _storageService;
  final SecureStorageService _secureStorageService;
  final RealtimeService? _realtimeService;
  UserProfile? _cachedProfile;

  static const String _kOnboardingCompleted = 'pukaar_onboarding_completed';
  static const String _kIsLoggedIn = 'pukaar_is_logged_in';
  static const String _kUserProfile = 'pukaar_user_profile';
  static const String _kAuthToken = 'pukaar_auth_token';

  ApiAuthService(
    this._apiService,
    this._storageService,
    this._secureStorageService, [
    this._realtimeService,
  ]);

  @override
  String? getAuthToken() => _cachedProfile?.token;

  @override
  String getRole() => _cachedProfile?.role ?? 'citizen';

  @override
  Future<bool> isOnboardingCompleted() async {
    final val = await _storageService.getBool(_kOnboardingCompleted);
    return val ?? false;
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _storageService.setBool(_kOnboardingCompleted, completed);
  }

  @override
  Future<bool> isLoggedIn() async {
    final val = await _storageService.getBool(_kIsLoggedIn);
    if (val == true && _cachedProfile == null) {
      await getCurrentUser();
    }
    return val ?? false;
  }

  @override
  Future<AppResult<void>> sendOtp(String mobileNumber) async {
    if (mobileNumber.length < 10) {
      return AppResult.failure('Please enter a valid 10-digit mobile number.');
    }
    return AppResult.success(null);
  }

  @override
  Future<AppResult<UserProfile>> verifyOtp(String mobileNumber, String otp) async {
    if (otp != '123456') {
      return AppResult.failure('Invalid OTP. Please enter 123456.');
    }

    // Default password for demo OTP verification
    String password = 'password123';
    if (mobileNumber == '9000000000') {
      password = 'responder123';
    } else if (mobileNumber == '9999999999') {
      password = 'dual123';
    }

    final loginResult = await loginWithPassword(mobileNumber, password);

    if (loginResult.isSuccess) {
      return loginResult;
    }

    // If account doesn't exist yet, return partial profile for registration
    String role = 'citizen';
    if (mobileNumber == '9000000000') {
      role = 'responder';
    } else if (mobileNumber == '9999999999') {
      role = 'dual';
    }

    final partialProfile = UserProfile(
      name: '',
      mobileNumber: mobileNumber,
      role: role,
      emergencyContactName: '',
      emergencyContactPhone: '',
    );
    return AppResult.success(partialProfile);
  }

  @override
  Future<AppResult<UserProfile>> loginWithPassword(String mobileNumber, String password) async {
    final response = await _apiService.post('/auth/login', body: {
      'mobileNumber': mobileNumber,
      'password': password,
    });

    if (response.isFailure) {
      return AppResult.failure(response.errorMessage!);
    }

    final data = response.data!;
    final token = data['accessToken'] as String;
    final role = data['role'] as String? ?? 'citizen';
    final name = data['name'] as String? ?? '';

    _apiService.setAuthToken(token);

    final profile = UserProfile(
      name: name,
      mobileNumber: mobileNumber,
      role: role,
      token: token,
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '102',
    );

    _cachedProfile = profile;
    await _secureStorageService.write(_kAuthToken, token);
    final profileWithoutToken = profile.withoutToken();
    await _storageService.setString(_kUserProfile, json.encode(profileWithoutToken.toJson()));
    await _storageService.setBool(_kIsLoggedIn, true);

    _realtimeService?.connect(token);

    return AppResult.success(profile);
  }

  @override
  Future<AppResult<UserProfile>> registerUser(UserProfile profile, {String? password}) async {
    final reqPassword = password ?? 'password123';
    final response = await _apiService.post('/auth/register', body: {
      'mobileNumber': profile.mobileNumber,
      'password': reqPassword,
      'name': profile.name,
      'role': profile.role,
      'email': profile.email,
      'emergencyContactName': profile.emergencyContactName,
      'emergencyContactPhone': profile.emergencyContactPhone,
      'bloodGroup': profile.bloodGroup,
      'allergies': profile.allergies,
      'medications': profile.medications,
    });

    if (response.isFailure) {
      return AppResult.failure(response.errorMessage!);
    }

    final data = response.data!;
    final token = data['accessToken'] as String;
    final role = data['role'] as String? ?? profile.role;
    final name = data['name'] as String? ?? profile.name;

    _apiService.setAuthToken(token);

    final updatedProfile = profile.copyWith(
      name: name,
      role: role,
      token: token,
    );

    _cachedProfile = updatedProfile;
    await _secureStorageService.write(_kAuthToken, token);
    final profileWithoutToken = updatedProfile.withoutToken();
    await _storageService.setString(_kUserProfile, json.encode(profileWithoutToken.toJson()));
    await _storageService.setBool(_kIsLoggedIn, true);

    _realtimeService?.connect(token);

    return AppResult.success(updatedProfile);
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    if (_cachedProfile != null) {
      if (_cachedProfile!.token != null) {
        _apiService.setAuthToken(_cachedProfile!.token);
      }
      return _cachedProfile;
    }

    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        final profile = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        final token = await _secureStorageService.read(_kAuthToken);
        _cachedProfile = profile.copyWith(token: token);
        if (token != null) {
          _apiService.setAuthToken(token);
        }
        return _cachedProfile;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> updateCurrentUser(UserProfile profile) async {
    _cachedProfile = profile;
    final profileWithoutToken = profile.withoutToken();
    await _storageService.setString(_kUserProfile, json.encode(profileWithoutToken.toJson()));
  }

  @override
  Future<AppResult<bool>> validateSession() async {
    // 1. Explicitly ensure token and profile are restored before calling /auth/me
    if (_cachedProfile == null || _cachedProfile?.token == null) {
      await getCurrentUser();
    }

    String? token = _cachedProfile?.token;
    if (token == null || token.isEmpty) {
      token = await _secureStorageService.read(_kAuthToken);
      if (token != null && token.isNotEmpty && _cachedProfile != null) {
        _cachedProfile = _cachedProfile!.copyWith(token: token);
      }
    }

    // If no persisted token exists, do NOT make an unauthenticated /auth/me call
    if (token == null || token.isEmpty) {
      await logout();
      return AppResult.failure('No active authentication token found', statusCode: 401);
    }

    // Attach restored token to ApiService before making the request
    _apiService.setAuthToken(token);

    // 2. Validate session with backend
    final response = await _apiService.get('/auth/me');

    if (response.isSuccess) {
      // Connect to Realtime WebSocket upon validated session
      _realtimeService?.connect(token);

      // Synchronize cached profile with latest backend user information if returned
      if (response.data != null && response.data!['user'] is Map<String, dynamic>) {
        final userMap = response.data!['user'] as Map<String, dynamic>;
        final current = _cachedProfile ??
            const UserProfile(
              name: '',
              mobileNumber: '',
              emergencyContactName: '',
              emergencyContactPhone: '',
            );
        final updatedProfile = current.copyWith(
          name: userMap['name'] as String? ?? current.name,
          role: userMap['role'] as String? ?? current.role,
          email: userMap['email'] as String? ?? current.email,
          emergencyContactName: userMap['emergencyContactName'] as String? ?? current.emergencyContactName,
          emergencyContactPhone: userMap['emergencyContactPhone'] as String? ?? current.emergencyContactPhone,
          bloodGroup: userMap['bloodGroup'] as String? ?? current.bloodGroup,
          allergies: userMap['allergies'] as String? ?? current.allergies,
          medications: userMap['medications'] as String? ?? current.medications,
          token: token,
        );
        _cachedProfile = updatedProfile;
        final profileWithoutToken = updatedProfile.withoutToken();
        await _storageService.setString(_kUserProfile, json.encode(profileWithoutToken.toJson()));
        await _storageService.setBool(_kIsLoggedIn, true);
      }
      return AppResult.success(true, statusCode: response.statusCode ?? 200);
    }

    // 3. Handle failure: distinguish between HTTP 401/403 / Auth failure vs Network error
    final statusCode = response.statusCode;
    final isAuthError = statusCode == 401 ||
        statusCode == 403 ||
        (response.errorMessage != null &&
            (response.errorMessage!.contains('401') ||
                response.errorMessage!.contains('403') ||
                response.errorMessage!.toLowerCase().contains('unauthorized') ||
                response.errorMessage!.toLowerCase().contains('forbidden') ||
                response.errorMessage!.toLowerCase().contains('invalid') ||
                response.errorMessage!.toLowerCase().contains('credentials') ||
                response.errorMessage!.toLowerCase().contains('expired')));

    if (isAuthError) {
      // Token is invalid/expired. Clear local session deterministically.
      await logout();
      return AppResult.failure(response.errorMessage ?? 'Unauthorized session', statusCode: statusCode ?? 401);
    }

    // Network failure / timeout: DO NOT delete the persisted token
    return AppResult.failure(response.errorMessage ?? 'Session validation network failure', statusCode: statusCode);
  }

  @override
  Future<void> logout() async {
    final token = _cachedProfile?.token;
    if (token != null && token.isNotEmpty) {
      try {
        await _apiService
            .post('/auth/logout')
            .timeout(const Duration(seconds: 2))
            .catchError((_) => AppResult.success(<String, dynamic>{}));
      } catch (_) {
        // Graceful handling if backend unavailable
      }
    }
    _realtimeService?.disconnect();
    _cachedProfile = null;
    _apiService.setAuthToken(null);
    await _storageService.setBool(_kIsLoggedIn, false);
    await _storageService.remove(_kUserProfile);
    await _secureStorageService.delete(_kAuthToken);
  }
}
