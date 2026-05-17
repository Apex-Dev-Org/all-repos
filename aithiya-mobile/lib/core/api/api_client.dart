import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/env.dart';

class ApiUploadFile {
  const ApiUploadFile({
    required this.fieldName,
    required this.filePath,
    required this.filename,
    required this.mimeType,
  });

  final String fieldName;
  final String filePath;
  final String filename;
  final String mimeType;
}

/// HTTP helper for the FastAPI backend. Injects the Supabase JWT when available
/// via [getAccessToken].
class ApiClient {
  ApiClient({
    String? baseUrl,
    String? apiPrefix,
    Future<String?> Function()? getAccessToken,
    http.Client? httpClient,
  }) : _baseUrl = _normalizeBaseUrl(
         baseUrl ?? Env.apiBaseUrl,
         apiPrefix ?? Env.apiV1Prefix,
       ),
       _getAccessToken = getAccessToken,
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final Future<String?> Function()? _getAccessToken;
  final http.Client _http;

  Future<http.Response> get(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) => _request('GET', path, queryParameters: queryParameters);

  Future<http.Response> postJson(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, jsonBody: body);

  Future<http.Response> patchJson(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, jsonBody: body);

  Future<http.Response> delete(String path) => _request('DELETE', path);

  Future<http.Response> multipart(
    String path, {
    Map<String, String> fields = const {},
    List<ApiUploadFile> files = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _headers());
    request.fields.addAll(fields);

    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath(
          file.fieldName,
          file.filePath,
          filename: file.filename,
          contentType: MediaType.parse(file.mimeType),
        ),
      );
    }

    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String?> queryParameters = const {},
  }) async {
    final uri = _uri(path, queryParameters: queryParameters);
    final headers = await _headers(
      contentType: jsonBody != null ? 'application/json' : null,
    );

    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(
          uri,
          headers: headers,
          body: jsonBody != null ? jsonEncode(jsonBody) : null,
        );
      case 'PATCH':
        return _http.patch(
          uri,
          headers: headers,
          body: jsonBody != null ? jsonEncode(jsonBody) : null,
        );
      case 'DELETE':
        return _http.delete(uri, headers: headers);
      default:
        throw UnsupportedError(method);
    }
  }

  Uri _uri(String path, {Map<String, String?> queryParameters = const {}}) {
    final uri = Uri.parse('$_baseUrl${path.startsWith('/') ? '' : '/'}$path');
    final qp = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) qp[key] = value;
    });
    return qp.isEmpty ? uri : uri.replace(queryParameters: qp);
  }

  Future<Map<String, String>> _headers({String? contentType}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    final token = await _getAccessToken?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static String _normalizeBaseUrl(String baseUrl, String apiPrefix) {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final prefix = apiPrefix.trim();
    if (prefix.isEmpty || prefix == '/') return root;
    final normalizedPrefix = prefix.startsWith('/') ? prefix : '/$prefix';
    if (root.endsWith(normalizedPrefix)) return root;
    return '$root$normalizedPrefix';
  }

  static Object? decodeJson(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static String errorMessage(http.Response response) {
    try {
      final decoded = decodeJson(response);
      if (decoded case {'error': {'message': final String message}}) {
        return message;
      }
      if (decoded case {'detail': final String detail}) {
        return detail;
      }
      if (decoded case {'message': final String message}) {
        return message;
      }
    } catch (_) {
      // Fall through to the status-based message.
    }
    return 'Request failed with HTTP ${response.statusCode}.';
  }

  void close() => _http.close();
}
