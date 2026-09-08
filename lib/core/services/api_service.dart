import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/app_config.dart';
import '../utils/app_result.dart';

/// Contract interface for Pukaar backend API communications.
abstract class ApiService {
  void setAuthToken(String? token);

  Future<AppResult<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  });

  Future<AppResult<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  });

  Future<AppResult<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  });

  Future<AppResult<bool>> delete(
    String endpoint,
  );
}

/// Initial placeholder / mock implementation of [ApiService].
class MockApiService implements ApiService {
  String? _authToken;

  String? get authToken => _authToken;

  @override
  void setAuthToken(String? token) {
    _authToken = token;
  }


  @override
  Future<AppResult<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return AppResult.success({'status': 'ok', 'endpoint': endpoint});
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return AppResult.success({'status': 'created', 'endpoint': endpoint});
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return AppResult.success({'status': 'updated', 'endpoint': endpoint});
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    return AppResult.success(true);
  }
}

/// Production / Development HTTP implementation of [ApiService] using standard [HttpClient].
class HttpApiService implements ApiService {
  final String baseUrl;
  final Duration timeout;
  final HttpClient _client = HttpClient();
  String? _authToken;

  HttpApiService({
    String? baseUrl,
    Duration? timeout,
  })  : baseUrl = baseUrl ?? AppConfig.baseUrl,
        timeout = timeout ?? AppConfig.apiTimeout;

  @override
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$cleanBase$cleanEndpoint';
    final uri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map((key, value) => MapEntry(key, value.toString()));
      return uri.replace(queryParameters: stringParams);
    }

    return uri;
  }

  Future<AppResult<Map<String, dynamic>>> _sendJsonRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      final request = await _client.openUrl(method, uri).timeout(timeout);

      request.headers.contentType = ContentType.json;
      request.headers.set('Accept', 'application/json');

      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $_authToken');
      }

      if (body != null) {
        final jsonString = json.encode(body);
        request.write(jsonString);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) {
          return AppResult.success({'status': 'success'}, statusCode: response.statusCode);
        }
        final decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          return AppResult.success(decoded, statusCode: response.statusCode);
        }
        return AppResult.success({'data': decoded}, statusCode: response.statusCode);
      } else {
        String errorMsg = 'HTTP ${response.statusCode} error on $method $endpoint';
        if (responseBody.isNotEmpty) {
          try {
            final decoded = json.decode(responseBody);
            if (decoded is Map && decoded.containsKey('detail')) {
              errorMsg = decoded['detail'].toString();
            }
          } catch (_) {}
        }
        return AppResult.failure(errorMsg, statusCode: response.statusCode);
      }
    } on TimeoutException {
      return AppResult.failure('Network request timed out for $method $endpoint', statusCode: 408);
    } catch (e) {
      return AppResult.failure('Network connection error ($method $endpoint): $e');
    }
  }

  @override
  Future<AppResult<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _sendJsonRequest('GET', endpoint, queryParameters: queryParameters);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _sendJsonRequest('POST', endpoint, body: body);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _sendJsonRequest('PUT', endpoint, body: body);
  }

  @override
  Future<AppResult<bool>> delete(String endpoint) async {
    final result = await _sendJsonRequest('DELETE', endpoint);
    return AppResult.success(result.isSuccess);
  }
}

