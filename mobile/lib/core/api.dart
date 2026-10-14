import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class Api {
  String? token;
  final http.Client client = http.Client();
  // Browser calls are same-origin. Native builds must provide a reachable HTTPS API host.
  static const configuredBase = String.fromEnvironment('API_BASE_URL');
  String get base {
    if (configuredBase.isNotEmpty) {
      return configuredBase.replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) return Uri.base.origin;
    throw ApiException('Configure API_BASE_URL for your mobile build.', 0);
  }

  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = kIsWeb
        ? prefs.getString('relay_session')
        : await const FlutterSecureStorage().read(key: 'relay_session');
    return prefs.getBool('relay_signed_out') ?? false;
  }

  Future<void> saveSession(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.setString('relay_session', value);
    } else {
      await const FlutterSecureStorage()
          .write(key: 'relay_session', value: value);
    }
    await prefs.setBool('relay_signed_out', false);
  }

  Future<void> clearSession() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('relay_session');
    if (!kIsWeb) {
      await const FlutterSecureStorage().delete(key: 'relay_session');
    }
    await prefs.setBool('relay_signed_out', true);
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };
  Uri url(String path, [Map<String, String>? query]) =>
      Uri.parse('$base/api$path').replace(queryParameters: query);

  dynamic parse(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {'detail': 'The server returned an unexpected response.'};
    }
    if (response.statusCode >= 400) {
      final detail = data['detail'];
      String message =
          detail is String ? detail : 'Please check the fields and try again.';
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        message = '${(first['loc'] as List).last}: ${first['msg']}';
      }
      throw ApiException(message, response.statusCode);
    }
    return data;
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    try {
      return parse(await client
          .get(url(path, query), headers: headers)
          .timeout(const Duration(seconds: 35)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your connection and try again.', 0);
    }
  }

  Future<dynamic> post(String path, [Object? body]) async {
    try {
      return parse(await client
          .post(url(path), headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 40)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your connection and try again.', 0);
    }
  }

  Future<dynamic> put(String path, Object body) async {
    try {
      return parse(await client
          .put(url(path), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 35)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your connection and try again.', 0);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      return parse(await client
          .delete(url(path), headers: headers)
          .timeout(const Duration(seconds: 35)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your connection and try again.', 0);
    }
  }

  Future<dynamic> uploadCsv(String filename, Uint8List bytes) async {
    final request =
        http.MultipartRequest('POST', url('/contacts/import-preview'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      return parse(await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 40))));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('The upload failed. Please try again.', 0);
    }
  }

  Future<Uint8List> download(String path, [Map<String, String>? query]) async {
    try {
      final response = await client
          .get(url(path, query), headers: headers)
          .timeout(const Duration(seconds: 40));
      if (response.statusCode >= 400) parse(response);
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('The export failed. Please try again.', 0);
    }
  }
}
