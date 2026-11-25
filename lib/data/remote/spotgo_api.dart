import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/parking_rules.dart';

typedef Json = Map<String, dynamic>;

class SpotGoApi {
  SpotGoApi(this.baseUrl);

  final Uri baseUrl;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  String? _accessToken;
  String? _refreshToken;
  Future<void>? _refreshing;
  int _sessionVersion = 0;
  Json? tenant;

  void setSession(Json session) {
    _accessToken = session['accessToken'] as String;
    _refreshToken = session['refreshToken'] as String;
  }

  void clearSession() {
    _sessionVersion++;
    _refreshing = null;
    _accessToken = null;
    _refreshToken = null;
    tenant = null;
  }

  void dispose() => _http.close(force: true);

  Future<Json> object(
    String path, {
    String method = 'GET',
    Json? body,
    bool auth = true,
  }) async =>
      (await request(path, method: method, body: body, auth: auth)) as Json;

  Future<List<Json>> list(String path, [Map<String, String>? query]) async =>
      (await request(path, query: query) as List<dynamic>).cast<Json>();

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final token = auth ? _accessToken : null;
    final version = _sessionVersion;
    try {
      return await _send(path, method, body, query, token);
    } on ApiException catch (error) {
      if (error.status != 401 ||
          !auth ||
          token == null ||
          version != _sessionVersion) {
        rethrow;
      }
      if (token == _accessToken) {
        final pending = _refreshing ??= _refresh(version);
        try {
          await pending;
        } finally {
          if (identical(_refreshing, pending)) _refreshing = null;
        }
      }
      if (version != _sessionVersion) rethrow;
      return _send(path, method, body, query, _accessToken);
    }
  }

  Future<void> _refresh(int version) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw const ApiException(401, 'Session expired. Sign in again.');
    }
    final session = await object(
      '/authentication/refresh',
      method: 'POST',
      body: {'refreshToken': refreshToken},
      auth: false,
    );
    if (version == _sessionVersion) setSession(session);
  }

  Future<dynamic> _send(
    String path,
    String method,
    Json? body,
    Map<String, String>? query,
    String? token,
  ) async {
    final uri = baseUrl.replace(path: '/api/v1$path', queryParameters: query);
    final request = await _http
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        request.abort();
        throw TimeoutException('The SpotGo API did not respond.');
      },
    );
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 12));
    dynamic payload;
    if (text.isNotEmpty) {
      try {
        payload = jsonDecode(text);
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Json ? payload['message'] as String? : null;
      throw ApiException(
        response.statusCode,
        message ?? 'SpotGo API returned HTTP ${response.statusCode}.',
      );
    }
    return payload;
  }
}

class ApiException extends ParkingRuleException {
  const ApiException(this.status, super.message);
  final int status;
}
