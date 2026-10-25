import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

class ApiClient {
  const ApiClient();

  Future<Map<String, dynamic>> get(String path, {bool authenticated = false}) async {
    return _request('GET', path, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    return _request('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    return _request('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    return _request('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = false,
  }) async {
    return _request('DELETE', path, authenticated: authenticated);
  }

  Future<Uint8List> getBytes(String path, {bool authenticated = false}) async {
    final headers = <String, String>{'Accept': '*/*'};
    if (authenticated) {
      final token = await SessionStore.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('You are not logged in. Please sign in first.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await http
          .get(_buildUri(path), headers: headers)
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Unable to load evidence.', statusCode: response.statusCode);
      }
      return response.bodyBytes;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Unable to load evidence.');
    }
  }

  Future<Map<String, String>> requestHeaders({
    bool authenticated = false,
  }) async {
    final headers = <String, String>{};
    if (!authenticated) return headers;
    final token = await SessionStore.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('You are not logged in. Please sign in first.');
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Uri buildUri(String path) => _buildUri(path);
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Map<String, String> filePaths,
    Map<String, List<String>> fileLists = const <String, List<String>>{},
    bool authenticated = false,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path));
    request.headers['Accept'] = 'application/json';

    if (authenticated) {
      final token = await SessionStore.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('You are not logged in. Please sign in first.');
      }
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);
    try {
      for (final entry in filePaths.entries) {
        request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
      }
      for (final entry in fileLists.entries) {
        for (final path in entry.value) {
          request.files.add(await http.MultipartFile.fromPath(entry.key, path));
        }
      }
    } catch (_) {
      throw ApiException('The selected image could not be read. Please capture or choose it again.');
    }

    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(AppConfig.requestTimeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Unable to connect to server. Check API_BASE_URL and network.');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString() ?? 'Request failed (${response.statusCode}).';
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (decoded['success'] == false) {
      final message = decoded['message']?.toString() ?? 'Request failed.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    final uri = _buildUri(path);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await SessionStore.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('You are not logged in. Please sign in first.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(AppConfig.requestTimeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
              .timeout(AppConfig.requestTimeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(AppConfig.requestTimeout);
          break;
        default:
          throw ApiException('Unsupported method: $method');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Unable to connect to server. Check API_BASE_URL and network.');
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString() ?? 'Request failed (${response.statusCode}).';
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (decoded['success'] == false) {
      final message = decoded['message']?.toString() ?? 'Request failed.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }

  Uri _buildUri(String path) {
    final base = AppConfig.apiBaseUrl.trim();
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    var normalizedPath = path.startsWith('/') ? path : '/$path';

    // Prevent duplicated api prefix when user includes /api or /api/v1 in API_BASE_URL.
    final baseLower = normalizedBase.toLowerCase();
    final pathLower = normalizedPath.toLowerCase();

    if (baseLower.endsWith('/api/v1') && pathLower.startsWith('/api/v1/')) {
      normalizedPath = normalizedPath.substring('/api/v1'.length);
    } else if (baseLower.endsWith('/api') && pathLower.startsWith('/api/')) {
      normalizedPath = normalizedPath.substring('/api'.length);
    }

    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return <String, dynamic>{'data': decoded};
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
