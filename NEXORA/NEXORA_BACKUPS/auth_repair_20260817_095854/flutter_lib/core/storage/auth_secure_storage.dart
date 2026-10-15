import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSecureStorage {
  static const _accessTokenKey = 'migo_access_token';

  static const _refreshTokenKey = 'migo_refresh_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);

    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);

    await _storage.delete(key: _refreshTokenKey);
  }
}
