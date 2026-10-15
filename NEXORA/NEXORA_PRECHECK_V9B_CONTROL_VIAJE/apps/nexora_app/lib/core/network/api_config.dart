abstract final class ApiConfig {
  // Desarrollo local:
  // ADB reverse enlaza este localhost
  // con localhost:8000 de Windows.
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const String apiV1 = '$baseUrl/api/v1';
}
