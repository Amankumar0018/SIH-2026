/// Contract interface for Pukaar push and local alerts/notifications.
/// Prepared for FCM / flutter_local_notifications integration.
abstract class NotificationService {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<void> showEmergencyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  });
}

/// Placeholder implementation of [NotificationService].
class MockNotificationService implements NotificationService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showEmergencyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  }) async {
    // Placeholder for local system notification dispatch
  }
}
