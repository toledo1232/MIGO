import '../../../core/storage/auth_secure_storage.dart';
import '../models/auth_session.dart';
import '../models/migo_user.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository({AuthApi? api, AuthSecureStorage? storage})
    : _api = api ?? AuthApi(),
      _storage = storage ?? AuthSecureStorage();

  final AuthApi _api;
  final AuthSecureStorage _storage;

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final session = await _api.register(
      fullName: fullName,
      phone: phone,
      email: email,
      password: password,
    );

    await _storage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );

    return session;
  }

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final session = await _api.login(phone: phone, password: password);

    await _storage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );

    return session;
  }

  Future<MigoUser?> restoreSession() async {
    final accessToken = await _storage.readAccessToken();

    final refreshToken = await _storage.readRefreshToken();

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    try {
      return await _api.me(accessToken: accessToken);
    } on AuthApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
    }

    try {
      final refreshed = await _api.refresh(refreshToken: refreshToken);

      await _storage.saveTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
      );

      return refreshed.user;
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();

    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken: refreshToken);
      } catch (_) {
        // Aunque falle la red, eliminamos
        // las credenciales locales.
      }
    }

    await _storage.clear();
  }

  void dispose() {
    _api.close();
  }
}
