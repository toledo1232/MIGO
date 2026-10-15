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

  Uri _uri(String path) => Uri.parse('${ApiConfig.apiV1}$path');

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          _uri('/auth/register'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'full_name': fullName,
            'phone': phone,
            'email': email,
            'password': password,
            'device_name': 'Pixel 8',
            'platform': 'android',
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _authResponse(response);
  }

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client
        .post(
          _uri('/auth/login'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'phone': phone,
            'password': password,
            'device_name': 'Pixel 8',
            'platform': 'android',
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _authResponse(response);
  }

  Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await _client
        .post(
          _uri('/auth/refresh'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 10));

    return _authResponse(response);
  }

  Future<MigoUser> me({required String accessToken}) async {
    final response = await _client
        .get(
          _uri('/auth/me'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw _httpError(response);
    }

    final raw = jsonDecode(response.body);

    if (raw is! Map<String, dynamic>) {
      throw const AuthApiException('Respuesta invalida de /me.');
    }

    return MigoUser.fromJson(raw);
  }

  Future<void> logout({required String refreshToken}) async {
    await _client
        .post(
          _uri('/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 10));
  }

  AuthSession _authResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }

    try {
      final raw = jsonDecode(response.body);

      if (raw is! Map<String, dynamic>) {
        throw const FormatException('JSON no es un objeto.');
      }

      return AuthSession.fromJson(raw);
    } on AuthApiException {
      rethrow;
    } catch (error) {
      throw AuthApiException(
        'Respuesta API incompatible: '
        '$error',
        statusCode: response.statusCode,
      );
    }
  }

  AuthApiException _httpError(http.Response response) {
    try {
      final raw = jsonDecode(response.body);

      if (raw is Map<String, dynamic>) {
        final detail = raw['detail'];

        if (detail is String) {
          return AuthApiException(detail, statusCode: response.statusCode);
        }

        if (detail is List) {
          return AuthApiException(
            'Datos no validos: '
            '${detail.toString()}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {}

    return AuthApiException(
      'HTTP ${response.statusCode}: '
      '${response.body}',
      statusCode: response.statusCode,
    );
  }

  void close() {
    _client.close();
  }
}
