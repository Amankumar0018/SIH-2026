import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../utils/app_result.dart';

/// Lightweight data model representing emergency GPS coordinates & telemetry.
class EmergencyLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final bool isMocked;

  const EmergencyLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
    this.isMocked = false,
  });

  EmergencyLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
    bool? isMocked,
  }) {
    return EmergencyLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      isMocked: isMocked ?? this.isMocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
      'isMocked': isMocked,
    };
  }

  factory EmergencyLocation.fromJson(Map<String, dynamic> json) {
    return EmergencyLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isMocked: json['isMocked'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'EmergencyLocation(lat: $latitude, lng: $longitude, acc: ${accuracy}m, time: $timestamp)';
  }
}

/// Unified cross-platform location permission status.
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unableToDetermine;

  bool get isGranted => this == LocationPermissionStatus.granted;
  bool get canRequestAgain => this == LocationPermissionStatus.denied;
}

/// Contract interface for GPS and Location management in Pukaar.
abstract class LocationService {
  /// Checks whether device GPS / Location hardware services are turned on.
  Future<bool> isLocationServiceEnabled();

  /// Checks the current location permission granted by the OS.
  Future<LocationPermissionStatus> checkPermission();

  /// Requests the user to grant location permissions.
  Future<LocationPermissionStatus> requestPermission();

  /// Obtains the current precise GPS position of the user.
  Future<AppResult<EmergencyLocation>> getCurrentLocation({
    Duration? timeout,
    bool highAccuracy = true,
  });

  /// Retrieves the last known cached position from the OS.
  Future<AppResult<EmergencyLocation>> getLastKnownLocation();

  /// Prompts OS to open the application system settings page.
  Future<bool> openAppSettings();

  /// Prompts OS to open the device location settings page.
  Future<bool> openLocationSettings();
}

/// Production implementation of [LocationService] powered by the Geolocator plugin.
class GeolocatorLocationService implements LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      return _mapGeolocatorPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.unableToDetermine;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.requestPermission();
      return _mapGeolocatorPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.unableToDetermine;
    }
  }

  @override
  Future<AppResult<EmergencyLocation>> getCurrentLocation({
    Duration? timeout,
    bool highAccuracy = true,
  }) async {
    try {
      // 1. Check if location hardware is enabled
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        // Attempt fallback to last known location if possible
        final lastKnown = await getLastKnownLocation();
        if (lastKnown.isSuccess) {
          return lastKnown;
        }
        return AppResult.failure(
          'Location services (GPS) are disabled on your device. Please enable GPS in device settings.',
        );
      }

      // 2. Check and request permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return AppResult.failure('Location permission was denied by the user.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return AppResult.failure(
          'Location permissions are permanently denied. Please enable them in app settings.',
        );
      }

      // 3. Request current GPS coordinates
      final locationSettings = LocationSettings(
        accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: timeout ?? const Duration(seconds: 8),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      return AppResult.success(_mapPositionToLocation(position));
    } on TimeoutException {
      // Graceful fallback to last known location on timeout
      final lastKnown = await getLastKnownLocation();
      if (lastKnown.isSuccess) {
        return lastKnown;
      }
      return AppResult.failure('GPS location request timed out. Please verify device GPS signal.');
    } catch (e) {
      // Attempt last known location on unexpected failure
      final lastKnown = await getLastKnownLocation();
      if (lastKnown.isSuccess) {
        return lastKnown;
      }
      return AppResult.failure('Unable to retrieve GPS coordinates: $e');
    }
  }

  @override
  Future<AppResult<EmergencyLocation>> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return AppResult.success(_mapPositionToLocation(position));
      }
      return AppResult.failure('No last known location cached on device.');
    } catch (e) {
      return AppResult.failure('Failed to get last known location: $e');
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  LocationPermissionStatus _mapGeolocatorPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unableToDetermine;
    }
  }

  EmergencyLocation _mapPositionToLocation(Position position) {
    return EmergencyLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
      isMocked: position.isMocked,
    );
  }
}

/// In-memory mock implementation of [LocationService] for testing, simulator fallback, and preview modes.
class MockLocationService implements LocationService {
  bool isEnabled;
  LocationPermissionStatus permissionStatus;
  EmergencyLocation? mockLocation;
  bool simulateError;

  MockLocationService({
    this.isEnabled = true,
    this.permissionStatus = LocationPermissionStatus.granted,
    this.mockLocation,
    this.simulateError = false,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => isEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    if (!isEnabled) return LocationPermissionStatus.serviceDisabled;
    return permissionStatus;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    if (!isEnabled) return LocationPermissionStatus.serviceDisabled;
    if (permissionStatus == LocationPermissionStatus.denied) {
      permissionStatus = LocationPermissionStatus.granted;
    }
    return permissionStatus;
  }

  @override
  Future<AppResult<EmergencyLocation>> getCurrentLocation({
    Duration? timeout,
    bool highAccuracy = true,
  }) async {
    if (simulateError) {
      return AppResult.failure('Simulated location error for test suite.');
    }

    if (!isEnabled) {
      return AppResult.failure('Location services are disabled on this device.');
    }

    if (permissionStatus == LocationPermissionStatus.denied) {
      return AppResult.failure('Location permission was denied.');
    }

    if (permissionStatus == LocationPermissionStatus.permanentlyDenied) {
      return AppResult.failure('Location permission is permanently denied.');
    }

    final location = mockLocation ??
        EmergencyLocation(
          latitude: 28.6139, // Default coordinates (e.g. New Delhi)
          longitude: 77.2090,
          accuracy: 5.0,
          altitude: 216.0,
          speed: 0.0,
          heading: 0.0,
          timestamp: DateTime.now(),
          isMocked: true,
        );

    return AppResult.success(location);
  }

  @override
  Future<AppResult<EmergencyLocation>> getLastKnownLocation() async {
    if (simulateError || !isEnabled) {
      return AppResult.failure('No last known location.');
    }
    return getCurrentLocation();
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
