import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/emergency_incident.dart';

/// Contract interface for real-time network push notifications and incident events.
abstract class RealtimeService {
  /// Live stream of incident events received over the real-time network channel.
  Stream<EmergencyIncident> get incidentStream;

  /// Establishes authenticated connection with the real-time server.
  Future<void> connect(String token);

  /// Disconnects from the real-time server.
  Future<void> disconnect();

  /// Whether the real-time connection is currently active.
  bool get isConnected;

  /// Releases resources and closes internal stream controllers.
  void dispose();
}

/// Production WebSocket implementation of [RealtimeService] using standard [WebSocket].
class WebSocketRealtimeService implements RealtimeService {
  final String? baseUrl;
  final StreamController<EmergencyIncident> _incidentStreamController =
      StreamController<EmergencyIncident>.broadcast();

  WebSocket? _webSocket;
  StreamSubscription? _socketSubscription;
  Timer? _reconnectTimer;

  String? _currentToken;
  bool _shouldBeConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  WebSocketRealtimeService({this.baseUrl});

  @override
  Stream<EmergencyIncident> get incidentStream => _incidentStreamController.stream;

  @override
  bool get isConnected => _webSocket != null && _webSocket!.readyState == WebSocket.open;

  /// Helper to convert HTTP/HTTPS base URL to WS/WSS URL with token query param.
  static String formatWebSocketUrl(String httpBaseUrl, String token) {
    String wsBase = httpBaseUrl.trim();
    if (wsBase.startsWith('https://')) {
      wsBase = 'wss://${wsBase.substring(8)}';
    } else if (wsBase.startsWith('http://')) {
      wsBase = 'ws://${wsBase.substring(7)}';
    } else if (!wsBase.startsWith('ws://') && !wsBase.startsWith('wss://')) {
      wsBase = 'ws://$wsBase';
    }

    if (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }

    final encodedToken = Uri.encodeComponent(token);
    return '$wsBase/ws?token=$encodedToken';
  }

  @override
  Future<void> connect(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    // Prevent duplicate connection attempts with the same token
    if (isConnected && _currentToken == cleanToken) return;
    if (_isConnecting && _currentToken == cleanToken) return;

    // Disconnect existing socket if connecting with a different token
    if (_webSocket != null || isConnected) {
      await disconnect();
    }

    _currentToken = cleanToken;
    _shouldBeConnected = true;
    _reconnectTimer?.cancel();
    _isConnecting = true;

    try {
      final activeBaseUrl = baseUrl ?? AppConfig.baseUrl;
      final wsUrl = formatWebSocketUrl(activeBaseUrl, cleanToken);

      final socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));

      _webSocket = socket;
      _reconnectAttempts = 0;
      _isConnecting = false;

      _socketSubscription?.cancel();
      _socketSubscription = socket.listen(
        _handleMessage,
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final decoded = json.decode(message);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type'] as String?;
          final rawIncident = decoded['incident'];

          if ((type == 'incident.created' || type == 'incident.updated') &&
              rawIncident is Map<String, dynamic>) {
            final incident = EmergencyIncident.fromJson(rawIncident);
            _incidentStreamController.add(incident);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
    }
  }

  void _handleDisconnect() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _webSocket = null;
    _isConnecting = false;

    if (_shouldBeConnected && _currentToken != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_shouldBeConnected || _currentToken == null) return;

    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(1, 10);
    debugPrint('Scheduling WebSocket reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldBeConnected && _currentToken != null) {
        connect(_currentToken!);
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _shouldBeConnected = false;
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_webSocket != null) {
      try {
        await _webSocket!.close();
      } catch (_) {}
      _webSocket = null;
    }
    _currentToken = null;
    _isConnecting = false;
    _reconnectAttempts = 0;
  }

  @override
  void dispose() {
    disconnect();
    _incidentStreamController.close();
  }
}

/// In-memory Mock implementation of [RealtimeService] for testing.
class MockRealtimeService implements RealtimeService {
  final StreamController<EmergencyIncident> _incidentStreamController =
      StreamController<EmergencyIncident>.broadcast();
  bool _connected = false;

  @override
  Stream<EmergencyIncident> get incidentStream => _incidentStreamController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(String token) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// Helper for tests to simulate incoming server push event.
  void emitIncidentEvent(EmergencyIncident incident) {
    if (!_incidentStreamController.isClosed) {
      _incidentStreamController.add(incident);
    }
  }

  @override
  void dispose() {
    _incidentStreamController.close();
  }
}
