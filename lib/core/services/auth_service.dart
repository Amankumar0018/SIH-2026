import 'dart:convert';
import '../models/user_profile.dart';
import '../utils/app_result.dart';
import 'storage_service.dart';

/// Contract interface for Pukaar user authentication and session management.
abstract class AuthService {
  Future<bool> isOnboardingCompleted();
  Future<void> setOnboardingCompleted(bool completed);

  Future<bool> isLoggedIn();
  Future<AppResult<void>> sendOtp(String mobileNumber);
  Future<AppResult<UserProfile>> verifyOtp(String mobileNumber, String otp);
  Future<AppResult<UserProfile>> registerUser(UserProfile profile);
  Future<UserProfile?> getCurrentUser();
  Future<void> updateCurrentUser(UserProfile profile);
  Future<void> logout();
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
    // Basic verification: accept any 10-digit mobile number
    if (mobileNumber.length < 10) {
      return AppResult.failure('Please enter a valid 10-digit mobile number.');
    }
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    return AppResult.success(null);
  }

  @override
  Future<AppResult<UserProfile>> verifyOtp(String mobileNumber, String otp) async {
    // For mock mode: allow '123456' as valid OTP
    if (otp != '123456') {
      return AppResult.failure('Invalid OTP. Please enter 123456.');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Try loading existing profile from storage
    final jsonStr = await _storageService.getString(_kUserProfile);
    if (jsonStr != null) {
      try {
        final profile = UserProfile.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        _cachedProfile = profile;
        await _storageService.setBool(_kIsLoggedIn, true);
        return AppResult.success(profile);
      } catch (_) {
        // Fallback if decode fails
      }
    }

    // Return empty/partial profile representing new registration required
    final partialProfile = UserProfile(
      name: '',
      mobileNumber: mobileNumber,
      emergencyContactName: '',
      emergencyContactPhone: '',
    );
    return AppResult.success(partialProfile);
  }

  @override
  Future<AppResult<UserProfile>> registerUser(UserProfile profile) async {
    if (profile.name.trim().isEmpty) {
      return AppResult.failure('Full Name is required.');
    }
    if (profile.emergencyContactName.trim().isEmpty || profile.emergencyContactPhone.trim().isEmpty) {
      return AppResult.failure('Emergency Contact details are required.');
    }

    await Future.delayed(const Duration(milliseconds: 600));

    _cachedProfile = profile;
    final jsonStr = json.encode(profile.toJson());
    await _storageService.setString(_kUserProfile, jsonStr);
    await _storageService.setBool(_kIsLoggedIn, true);

    return AppResult.success(profile);
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
    // Note: we don't clear the profile itself so a returning user on the same device can mock log back in
  }
}
