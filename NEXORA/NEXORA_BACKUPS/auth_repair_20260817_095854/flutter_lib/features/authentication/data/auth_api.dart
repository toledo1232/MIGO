import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../models/auth_session.dart';
import '../models/migo_user.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) {
    return Uri.parse('${ApiConfig.apiV1}$path');
  }

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
        'device_name': 'Pixel 8',
        'platform': 'android',
      }),
    );

    return _parseAuthResponse(response);
  }

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'device_name': 'Pixel 8',
        'platform': 'android',
      }),
    );

    return _parseAuthResponse(response);
  }

  Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await _client.post(
      _uri('/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    return _parseAuthResponse(response);
  }

  Future<MigoUser> me({required String accessToken}) async {
    final response = await _client.get(
      _uri('/auth/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return MigoUser.fromJson(json);
  }

  Future<void> logout({required String refreshToken}) async {
    await _client.post(
      _uri('/auth/logout'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  }

  AuthSession _parseAuthResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return AuthSession.fromJson(json);
  }

  AuthApiException _errorFromResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body);

      if (json is Map<String, dynamic>) {
        final detail = json['detail'];

        if (detail is String) {
          return AuthApiException(detail, statusCode: response.statusCode);
        }
      }
    } catch (_) {
      // Se utiliza mensaje generico.
    }

    return AuthApiException(
      'No se pudo completar la solicitud.',
      statusCode: response.statusCode,
    );
  }

  void close() {
    _client.close();
  }
}
