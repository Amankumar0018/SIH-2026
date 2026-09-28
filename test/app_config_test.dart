import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/config/app_config.dart';
import 'package:pukaar/core/services/realtime_service.dart';

void main() {
  group('AppConfig & Network Configuration', () {
    test('default baseUrl falls back to localAndroidBaseUrl when not defined', () {
      expect(AppConfig.baseUrl, equals(AppConfig.localAndroidBaseUrl));
      expect(AppConfig.baseUrl, equals('http://10.0.2.2:8000'));
    });

    test('realtime service properly converts default AppConfig baseUrl to ws URL', () {
      final wsUrl = WebSocketRealtimeService.formatWebSocketUrl(AppConfig.baseUrl, 'test_token');
      expect(wsUrl, equals('ws://10.0.2.2:8000/ws?token=test_token'));
    });

    test('realtime service properly converts custom LAN IP to ws URL', () {
      const customLanHttpUrl = 'http://192.168.1.50:8000';
      final wsUrl = WebSocketRealtimeService.formatWebSocketUrl(customLanHttpUrl, 'demo_token_abc');
      expect(wsUrl, equals('ws://192.168.1.50:8000/ws?token=demo_token_abc'));
    });

    test('endpoint paths are properly formatted with leading slash', () {
      expect(AppConfig.incidentsEndpoint, startsWith('/'));
      expect(AppConfig.activeIncidentsEndpoint, startsWith('/'));
      expect(AppConfig.incidentDetailEndpoint('123'), equals('/incidents/123'));
      expect(AppConfig.cancelIncidentEndpoint('123'), equals('/incidents/123/cancel'));
      expect(AppConfig.updateStatusEndpoint('123'), equals('/incidents/123/status'));
      expect(AppConfig.assignResponderEndpoint('123'), equals('/incidents/123/assign-responder'));
    });
  });
}
