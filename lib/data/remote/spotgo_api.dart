import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/api/role_guard.dart';
import '../../domain/parking_rules.dart';

typedef Json = Map<String, dynamic>;

class SpotGoApi {
  SpotGoApi(this.baseUrl);

  final Uri baseUrl;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  String? _accessToken;
  String? _refreshToken;
  String? authenticatedTenantId;
  Future<void>? _refreshing;
  int _sessionVersion = 0;
  Json? tenant;

  void setSession(Json session) {
    _accessToken = session['accessToken'] as String;
    _refreshToken = session['refreshToken'] as String;
    authenticatedTenantId = session['tenantId'] as String?;
  }

  void clearSession() {
    _sessionVersion++;
    _refreshing = null;
    _accessToken = null;
    _refreshToken = null;
    authenticatedTenantId = null;
    tenant = null;
  }

  void dispose() => _http.close(force: true);

  Future<Json> object(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    bool auth = true,
  }) async => (await request(
    path,
    method: method,
    body: body,
    query: query,
    auth: auth,
  )) as Json;

  Future<List<Json>> list(String path, [Map<String, String>? query]) async =>
      (await request(path, query: query) as List<dynamic>).cast<Json>();

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    bool auth = true,
  }) => _authorized(
    path,
    method,
    auth,
    (token) => _send(path, method, body, query, token),
  );

  Future<List<int>> bytes(String path) => _authorized(
    path,
    'GET',
    true,
    (token) => _sendRaw(path, 'GET', null, token, accept: 'image/*'),
  );

  Future<void> uploadImage(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    final boundary = 'spotgo-${DateTime.now().microsecondsSinceEpoch}';
    final prefix = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="image"; filename="evidence.${contentType == 'image/png' ? 'png' : 'jpg'}"\r\n'
      'Content-Type: $contentType\r\n\r\n',
    );
    final suffix = utf8.encode('\r\n--$boundary--\r\n');
    final body = <int>[...prefix, ...bytes, ...suffix];
    await _authorized(
      path,
      'PUT',
      true,
      (token) => _sendRaw(
        path,
        'PUT',
        null,
        token,
        body: body,
        contentType: 'multipart/form-data; boundary=$boundary',
      ),
    );
  }

  Future<T> _authorized<T>(
    String path,
    String method,
    bool auth,
    Future<T> Function(String? token) send,
  ) async {
    // Contract choke point: DRIVER-only endpoints never leave this app.
    RoleGuard.ensureCanCall(method, path);
    final token = auth ? _accessToken : null;
    final version = _sessionVersion;
    try {
      return await send(token);
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
      return send(_accessToken);
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
      throw _apiException(payload, response.statusCode);
    }
    return payload;
  }

  Future<List<int>> _sendRaw(
    String path,
    String method,
    Map<String, String>? query,
    String? token, {
    List<int>? body,
    String? contentType,
    String accept = 'application/json',
  }) async {
    final uri = baseUrl.replace(path: '/api/v1$path', queryParameters: query);
    final request = await _http
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, accept);
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, '******');
    }
    if (contentType != null) {
      request.headers.contentType = ContentType.parse(contentType);
    }
    if (body != null) request.add(body);
    final response = await request.close().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        request.abort();
        throw TimeoutException('The SpotGo API did not respond.');
      },
    );
    final result = await response.fold<List<int>>(
      <int>[],
      (collected, chunk) => collected..addAll(chunk),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic payload;
      if (result.isNotEmpty) {
        try {
          payload = jsonDecode(utf8.decode(result));
        } on FormatException {
          payload = null;
        }
      }
      throw _apiException(payload, response.statusCode);
    }
    return result;
  }

  /// Tolerant error parser (contract §0.4): `message` → `details` → `error`,
  /// falling back to the HTTP status. Billing answers `{"message": "…"}`
  /// without a `code`, while the IAM/Global handlers add `code`/`details`.
  static String errorMessage(dynamic payload, int status) {
    if (payload is Json) {
      for (final key in const ['message', 'details', 'error']) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return 'SpotGo API returned HTTP $status.';
  }

  static ApiException _apiException(dynamic payload, int status) =>
      ApiException(
        status,
        errorMessage(payload, status),
        code: payload is Json && payload['code'] is String
            ? payload['code'] as String
            : null,
      );
}

class ApiException extends ParkingRuleException {
  const ApiException(int status, super.message, {this.code})
    : super(status: status);

  @override
  int get status => super.status!;

  final String? code;
}
