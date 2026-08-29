/// Application configuration settings for Pukaar Emergency Platform.
/// Centralizes environment settings, backend API base URLs, and feature flags.
enum AppEnvironment {
  development,
  staging,
  production,
}

class AppConfig {
  AppConfig._();

  /// Current active application environment.
  static AppEnvironment environment = AppEnvironment.development;

  /// Default local development base URLs.
  /// - `10.0.2.2:8000` is the standard Android emulator loopback host address.
  /// - `localhost:8000` is for web, desktop, and local machine tests.
  static const String localAndroidBaseUrl = 'http://10.0.2.2:8000';
  static const String localHostBaseUrl = 'http://localhost:8000';

  /// Active Base URL for Pukaar backend API services.
  static String baseUrl = localAndroidBaseUrl;

  /// Timeout duration for API network requests.
  static Duration apiTimeout = const Duration(seconds: 10);

  /// Global feature flag: toggles between Mock services and Backend API services.
  /// Defaults to false so emulator/demo flows run seamlessly with MockEmergencyService.
  static bool useBackendApi = false;

  // --- API Endpoint Definitions ---
  static const String incidentsEndpoint = '/incidents';
  static const String activeIncidentsEndpoint = '/incidents/active';

  static String incidentDetailEndpoint(String id) => '/incidents/$id';
  static String cancelIncidentEndpoint(String id) => '/incidents/$id/cancel';
  static String updateStatusEndpoint(String id) => '/incidents/$id/status';
  static String assignResponderEndpoint(String id) => '/incidents/$id/assign-responder';
}
