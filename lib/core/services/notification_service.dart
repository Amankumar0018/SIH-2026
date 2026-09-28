import 'dart:async';
import 'package:flutter/material.dart';
import '../models/emergency_enums.dart';
import '../models/emergency_incident.dart';
import 'auth_service.dart';
import 'realtime_service.dart';

/// Notification presentation type.
enum NotificationType {
  info,
  success,
  warning,
  alert,
  ai,
}

/// In-app notification payload model.
class InAppNotification {
  final String title;
  final String message;
  final NotificationType type;
  final String? incidentId;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;

  InAppNotification({
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.incidentId,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'InAppNotification(title: $title, message: $message, type: $type, incidentId: $incidentId)';
}

/// Contract interface for Pukaar in-app alerts and notifications.
abstract class NotificationService {
  Future<bool> initialize();
  Future<bool> requestPermission();

  Future<void> showEmergencyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  });

  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? incidentId,
    Map<String, dynamic>? payload,
  });

  void dismissNotification();

  void attach({
    required RealtimeService realtimeService,
    required AuthService authService,
  });

  Future<void> handleIncident(EmergencyIncident incident);

  void dispose();
}

/// Production in-app implementation using Flutter's native [ScaffoldMessenger].
///
/// Listens to the existing [RealtimeService.incidentStream], resolves roles via
/// [AuthService], suppresses duplicates, and shows non-blocking floating alerts.
class InAppNotificationService implements NotificationService {
  /// Global key used by [MaterialApp] to display floating SnackBars from any screen.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  RealtimeService? _realtimeService;
  AuthService? _authService;
  StreamSubscription<EmergencyIncident>? _incidentSubscription;

  /// Cache of seen event keys to prevent duplicate notifications: incidentId:eventType:state
  final Set<String> _seenNotificationKeys = <String>{};

  /// Tracks last known status per incident to detect meaningful transitions
  final Map<String, EmergencyStatus> _lastKnownIncidentStatus = <String, EmergencyStatus>{};

  /// Tracks last known AI intelligence signature per incident
  final Map<String, String> _lastKnownAiSignature = <String, String>{};

  /// Optional listener/history for test observation and verification
  final List<InAppNotification> notificationHistory = <InAppNotification>[];
  void Function(InAppNotification)? onNotificationShown;

  InAppNotificationService({
    RealtimeService? realtimeService,
    AuthService? authService,
    this.onNotificationShown,
  }) {
    if (realtimeService != null && authService != null) {
      attach(realtimeService: realtimeService, authService: authService);
    }
  }

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void attach({
    required RealtimeService realtimeService,
    required AuthService authService,
  }) {
    _incidentSubscription?.cancel();
    _realtimeService = realtimeService;
    _authService = authService;

    _incidentSubscription = _realtimeService!.incidentStream.listen(
      (incident) {
        handleIncident(incident);
      },
      onError: (error) {
        debugPrint('InAppNotificationService: stream error (non-fatal): $error');
      },
      cancelOnError: false,
    );
  }

  @override
  Future<void> showEmergencyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  }) async {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.alert,
      payload: payload,
    );
  }

  @override
  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? incidentId,
    Map<String, dynamic>? payload,
  }) {
    final notification = InAppNotification(
      title: title,
      message: message,
      type: type,
      incidentId: incidentId,
      payload: payload,
    );

    notificationHistory.add(notification);
    onNotificationShown?.call(notification);

    try {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;

      final Color bgColor;
      final IconData icon;

      switch (type) {
        case NotificationType.alert:
          bgColor = const Color(0xFFC62828); // Rich emergency red
          icon = Icons.warning_amber_rounded;
          break;
        case NotificationType.ai:
          bgColor = const Color(0xFF3F51B5); // Indigo
          icon = Icons.auto_awesome;
          break;
        case NotificationType.warning:
          bgColor = const Color(0xFFE65100); // Amber/Orange
          icon = Icons.info_outline;
          break;
        case NotificationType.success:
          bgColor = const Color(0xFF2E7D32); // Forest green
          icon = Icons.check_circle_outline;
          break;
        case NotificationType.info:
          bgColor = const Color(0xFF37474F); // Dark slate
          icon = Icons.notifications_active_outlined;
          break;
      }

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 6.0,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              messenger.hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('InAppNotificationService: Error displaying SnackBar (non-fatal): $e');
    }
  }

  @override
  void dismissNotification() {
    try {
      scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    } catch (_) {}
  }

  @override
  Future<void> handleIncident(EmergencyIncident incident) async {
    try {
      // 1. Authenticated user and role resolution
      final user = await _authService?.getCurrentUser();
      final role = _authService?.getRole() ?? user?.role ?? 'citizen';
      final isResponder = user?.isResponder ?? (role == 'responder' || role == 'dual');
      final currentUserId = user?.mobileNumber;

      final incidentId = incident.id.isNotEmpty ? incident.id : 'incident';
      final previousStatus = _lastKnownIncidentStatus[incident.id];
      _lastKnownIncidentStatus[incident.id] = incident.status;

      // 2. Authorization & Privacy Isolation
      // Backend isolates WebSocket broadcasts; Flutter layer also enforces strictly:
      if (!isResponder) {
        // Citizens must ONLY see notifications for their own incidents
        if (currentUserId == null || (incident.userId.isNotEmpty && incident.userId != currentUserId)) {
          return;
        }
      }

      // 3. Responder Notification Rules
      if (isResponder) {
        // A: Incident Created Event
        if (incident.status == EmergencyStatus.created && previousStatus == null) {
          final eventKey = '$incidentId:created';
          if (_recordEventKey(eventKey)) {
            final categoryName = incident.category.displayName;
            final intentName = incident.intent.isNotEmpty ? incident.intent : 'Emergency';
            showNotification(
              title: 'New Emergency',
              message: '$categoryName reported ($intentName)',
              type: NotificationType.alert,
              incidentId: incident.id,
            );
          }
        }
        // B: Status Transitions
        else if (previousStatus != null && previousStatus != incident.status) {
          final eventKey = '$incidentId:status:${incident.status.name}';
          if (_recordEventKey(eventKey)) {
            _dispatchResponderStatusNotification(incident);
          }
        }

        // C: AI Intelligence Update
        _checkAiIntelligenceUpdate(incident, isResponder: true);
      }
      // 4. Citizen Notification Rules (their own incident only)
      else {
        // Citizens receive notifications for meaningful responder/status changes
        if (previousStatus != null && previousStatus != incident.status) {
          final eventKey = '$incidentId:status:${incident.status.name}';
          if (_recordEventKey(eventKey)) {
            _dispatchCitizenStatusNotification(incident);
          }
        }
      }
    } catch (e) {
      // Non-blocking: Notification failures must never crash or disrupt incident processing
      debugPrint('InAppNotificationService: Error handling incident event (non-fatal): $e');
    }
  }

  void _dispatchResponderStatusNotification(EmergencyIncident incident) {
    switch (incident.status) {
      case EmergencyStatus.accepted:
        showNotification(
          title: 'Incident Accepted',
          message: 'Incident #${incident.id} accepted by responder',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.dispatched:
        showNotification(
          title: 'Responder Dispatched',
          message: 'Responder dispatched for incident #${incident.id}',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.inProgress:
        showNotification(
          title: 'Incident In Progress',
          message: 'Response in progress for incident #${incident.id}',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.resolved:
        showNotification(
          title: 'Incident Resolved',
          message: 'Incident #${incident.id} has been resolved',
          type: NotificationType.success,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.cancelled:
        showNotification(
          title: 'Incident Cancelled',
          message: 'Incident #${incident.id} has been cancelled',
          type: NotificationType.warning,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.searching:
        showNotification(
          title: 'Searching Responders',
          message: 'Searching nearest responders for incident #${incident.id}',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.created:
        // Already handled on creation
        break;
    }
  }

  void _dispatchCitizenStatusNotification(EmergencyIncident incident) {
    switch (incident.status) {
      case EmergencyStatus.accepted:
        showNotification(
          title: 'Incident Accepted',
          message: 'Responder has accepted your emergency',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.dispatched:
        showNotification(
          title: 'Responder Dispatched',
          message: 'A responder has been dispatched',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.inProgress:
        showNotification(
          title: 'Incident In Progress',
          message: 'Help is on the way',
          type: NotificationType.info,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.resolved:
        showNotification(
          title: 'Incident Resolved',
          message: 'Your emergency has been resolved',
          type: NotificationType.success,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.cancelled:
        showNotification(
          title: 'Incident Cancelled',
          message: 'Your emergency has been cancelled',
          type: NotificationType.warning,
          incidentId: incident.id,
        );
        break;
      case EmergencyStatus.searching:
      case EmergencyStatus.created:
        break;
    }
  }

  void _checkAiIntelligenceUpdate(EmergencyIncident incident, {required bool isResponder}) {
    if (incident.aiIntelligence == null || !isResponder) return;

    final ai = incident.aiIntelligence!;
    // Signature includes confidence, urgency, and hazard/action count to detect LLM enrichment
    final currentSig = '${ai.confidence}_${ai.urgencyScore}_${ai.hazards.length}_${ai.recommendedActions.length}';
    final previousSig = _lastKnownAiSignature[incident.id];
    _lastKnownAiSignature[incident.id] = currentSig;

    // Only notify when AI intelligence is updated after initial state
    if (previousSig != null && previousSig != currentSig) {
      final eventKey = '${incident.id}:ai:$currentSig';
      if (_recordEventKey(eventKey)) {
        showNotification(
          title: 'AI Incident Intelligence Updated',
          message: 'New AI triage assessment available',
          type: NotificationType.ai,
          incidentId: incident.id,
        );
      }
    }
  }

  /// Records an event key. Returns true if key was NEW (not seen before), false if duplicate.
  bool _recordEventKey(String key) {
    if (_seenNotificationKeys.contains(key)) {
      return false;
    }
    // Prevent unbounded memory growth by clearing half if limit reached
    if (_seenNotificationKeys.length >= 250) {
      _seenNotificationKeys.clear();
    }
    _seenNotificationKeys.add(key);
    return true;
  }

  @override
  void dispose() {
    _incidentSubscription?.cancel();
    _incidentSubscription = null;
    _seenNotificationKeys.clear();
    _lastKnownIncidentStatus.clear();
    _lastKnownAiSignature.clear();
  }
}

/// In-memory Mock implementation of [NotificationService] for unit testing.
class MockNotificationService implements NotificationService {
  final List<InAppNotification> notificationHistory = <InAppNotification>[];

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void attach({
    required RealtimeService realtimeService,
    required AuthService authService,
  }) {}

  @override
  Future<void> showEmergencyAlert({
    required String title,
    required String message,
    Map<String, dynamic>? payload,
  }) async {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.alert,
      payload: payload,
    );
  }

  @override
  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? incidentId,
    Map<String, dynamic>? payload,
  }) {
    notificationHistory.add(InAppNotification(
      title: title,
      message: message,
      type: type,
      incidentId: incidentId,
      payload: payload,
    ));
  }

  @override
  void dismissNotification() {}

  @override
  Future<void> handleIncident(EmergencyIncident incident) async {}

  @override
  void dispose() {
    notificationHistory.clear();
  }
}