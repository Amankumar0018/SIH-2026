import 'dart:convert';
import '../models/user_profile.dart';
import '../utils/app_result.dart';
import 'api_service.dart';
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
  Future<void> logout();

  String? getAuthToken();
  String getRole();
}

/// Mock implementation of [AuthService] for development/testing phase.
/// Persists session and profile state using the provided [StorageService].
class MockAuthService implements AuthService {
  final StorageService _storageService;
  UserProfile? _cachedProfile;

  static const String _kOnboardingCompleted = 'pukaar_onboarding_completed';
  static const String _kIsLoggedIn = 'pukaar_is_logged_in';
  static const String _kUserProfile = 'pukaar_user_profile';

  MockAuthService(this._storageService);

  @override
  String? getAuthToken() => _cachedProfile?.token ?? 'mock_bearer_token_123';

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
        _cachedProfile = profile;
        await _storageService.setBool(_kIsLoggedIn, true);
        return AppResult.success(profile);
      } catch (_) {}
    }

    // Default mock profile assignment based on mobile number
    String role = 'citizen';
    if (mobileNumber == '9000000000') {
      role = 'responder';
    } else if (mobileNumber == '9999999999') {
      role = 'dual';
    }

    final partialProfile = UserProfile(
      name: role == 'responder' ? 'Demo Responder' : role == 'dual' ? 'Demo Dual User' : '',
      mobileNumber: mobileNumber,
      role: role,
      token: 'mock_token_$mobileNumber',
      emergencyContactName: 'Emergency Contact',
      emergencyContactPhone: '102',
    );
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
          _cachedProfile = stored;
          await _storageService.setBool(_kIsLoggedIn, true);
          return AppResult.success(stored);
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
    final jsonStrProfile = json.encode(profile.toJson());
    await _storageService.setString(_kUserProfile, jsonStrProfile);
    await _storageService.setBool(_kIsLoggedIn, true);

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
    final jsonStr = json.encode(profileWithToken.toJson());
    await _storageService.setString(_kUserProfile, jsonStr);
    await _storageService.setBool(_kIsLoggedIn, true);

    return AppResult.success(profileWithToken);
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    if (_cachedProfile != null) return _cachedProfile;

    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        _cachedProfile = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
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
    final jsonStr = json.encode(profile.toJson());
    await _storageService.setString(_kUserProfile, jsonStr);
  }

  @override
  Future<void> logout() async {
    _cachedProfile = null;
    await _storageService.setBool(_kIsLoggedIn, false);
    await _storageService.remove(_kUserProfile);
  }
}

/// Backend REST implementation of [AuthService] connecting Flutter to FastAPI /auth.
class ApiAuthService implements AuthService {
  final ApiService _apiService;
  final StorageService _storageService;
  UserProfile? _cachedProfile;

  static const String _kOnboardingCompleted = 'pukaar_onboarding_completed';
  static const String _kIsLoggedIn = 'pukaar_is_logged_in';
  static const String _kUserProfile = 'pukaar_user_profile';

  ApiAuthService(this._apiService, this._storageService);

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
    await _storageService.setString(_kUserProfile, json.encode(profile.toJson()));
    await _storageService.setBool(_kIsLoggedIn, true);

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
    await _storageService.setString(_kUserProfile, json.encode(updatedProfile.toJson()));
    await _storageService.setBool(_kIsLoggedIn, true);

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
        _cachedProfile = profile;
        if (profile.token != null) {
          _apiService.setAuthToken(profile.token);
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
    await _storageService.setString(_kUserProfile, json.encode(profile.toJson()));
  }

  @override
  Future<void> logout() async {
    _cachedProfile = null;
    _apiService.setAuthToken(null);
    await _storageService.setBool(_kIsLoggedIn, false);
    await _storageService.remove(_kUserProfile);
  }
}
