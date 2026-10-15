import 'migo_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final MigoUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];

    final refresh = json['refresh_token'];

    final expires = json['expires_in'];

    final rawUser = json['user'];

    if (access is! String) {
      throw const FormatException('La API no devolvio access_token.');
    }

    if (refresh is! String) {
      throw const FormatException('La API no devolvio refresh_token.');
    }

    if (expires is! int) {
      throw const FormatException('La API no devolvio expires_in.');
    }

    if (rawUser is! Map<String, dynamic>) {
      throw const FormatException('La API no devolvio user.');
    }

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: expires,
      user: MigoUser.fromJson(rawUser),
    );
  }
}
