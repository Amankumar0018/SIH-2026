import '../config/app_config.dart';
import '../repositories/api_emergency_repository.dart';
import '../repositories/emergency_repository.dart';
import '../repositories/mock_emergency_repository.dart';
import 'api_emergency_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'emergency_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Lightweight dependency container for Pukaar foundation services and repositories.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late ApiService apiService;
  late StorageService storageService;
  late LocationService locationService;
  late NotificationService notificationService;
  late AuthService authService;
  late EmergencyRepository emergencyRepository;
  late EmergencyService emergencyService;

  /// Initializes default service instances.
  /// Set [useBackendApi] to true to switch from MockEmergencyService to ApiEmergencyService.
  void init({
    ApiService? customApiService,
    StorageService? customStorageService,
    LocationService? customLocationService,
    NotificationService? customNotificationService,
    AuthService? customAuthService,
    EmergencyRepository? customEmergencyRepository,
    EmergencyService? customEmergencyService,
    bool? useBackendApi,
  }) {
    final bool backendFlag = useBackendApi ?? AppConfig.useBackendApi;

    apiService = customApiService ?? (backendFlag ? HttpApiService() : MockApiService());
    storageService = customStorageService ?? InMemoryStorageService();
    locationService = customLocationService ?? GeolocatorLocationService();

    notificationService = customNotificationService ?? MockNotificationService();
    authService = customAuthService ?? MockAuthService(storageService);

    if (customEmergencyRepository != null) {
      emergencyRepository = customEmergencyRepository;
    } else if (backendFlag) {
      emergencyRepository = ApiEmergencyRepository(apiService);
    } else {
      emergencyRepository = MockEmergencyRepository();
    }

    if (customEmergencyService != null) {
      emergencyService = customEmergencyService;
    } else if (backendFlag) {
      emergencyService = ApiEmergencyService(
        repository: emergencyRepository,
        locationService: locationService,
        authService: authService,
      );
    } else {
      emergencyService = MockEmergencyService(
        locationService: locationService,
        authService: authService,
      );
    }
  }
}
