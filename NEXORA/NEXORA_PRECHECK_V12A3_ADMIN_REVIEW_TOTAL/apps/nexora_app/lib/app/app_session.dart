import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppMode { passenger, driver }

class AppSession extends ChangeNotifier {
  AppSession() {
    current = this;
    _restoreFuture = _restorePersistentProfile();
  }

  // Una sola sesión pública por instancia de la app.
  static AppSession? current;

  static const FlutterSecureStorage _profileStorage = FlutterSecureStorage();

  static const String _passengerPhotoKey = 'migo_profile_passenger_photo_v1';
  static const String _driverPhotoKey = 'migo_profile_driver_photo_v1';

  Future<void>? _restoreFuture;
  bool _profileRestored = false;

  AppMode _mode = AppMode.passenger;
  bool _driverOnline = false;

  // Temporal para poder probar ambos modos.
  // Más adelante este permiso vendrá desde el servidor MIGO.
  final bool _driverApproved = true;

  // Perfil pasajero: la foto es opcional.
  String passengerName = 'Pasajero MIGO';
  String? passengerPhotoBase64;
  double passengerRating = 5.0;
  int passengerTrips = 0;

  // Perfil conductor: para ponerse DISPONIBLE sí exigimos foto.
  String driverName = 'Conductor MIGO';
  String? driverPhotoBase64;
  double driverRating = 5.0;
  int driverTrips = 0;
  String driverVehicle = 'Vehículo por configurar';
  String driverPlate = 'Por registrar';
  String driverColor = 'Por registrar';

  AppMode get mode => _mode;
  bool get driverApproved => _driverApproved;
  bool get driverOnline => _driverOnline;
  bool get profileRestored => _profileRestored;

  Future<void> get profileReady => _restoreFuture ?? Future<void>.value();

  bool get hasDriverPhoto =>
      driverPhotoBase64 != null && driverPhotoBase64!.isNotEmpty;

  static String? _normalizePhoto(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<void> _restorePersistentProfile() async {
    try {
      final values = await Future.wait<String?>([
        _profileStorage.read(key: _passengerPhotoKey),
        _profileStorage.read(key: _driverPhotoKey),
      ]);

      passengerPhotoBase64 = _normalizePhoto(values[0]);
      driverPhotoBase64 = _normalizePhoto(values[1]);
    } catch (error) {
      // En tests o si Android todavía no tiene disponible el plugin,
      // la app debe continuar funcionando con el perfil en memoria.
      debugPrint('MIGO: no se pudo restaurar el perfil persistente: $error');
    } finally {
      _profileRestored = true;
      notifyListeners();
    }
  }

  Future<void> _writePersistentPhoto({
    required String key,
    required String? value,
  }) async {
    if (value == null) {
      await _profileStorage.delete(key: key);
      return;
    }

    await _profileStorage.write(key: key, value: value);
  }

  bool switchToDriver() {
    if (!_driverApproved) {
      return false;
    }

    if (_mode == AppMode.driver) {
      return true;
    }

    _mode = AppMode.driver;
    notifyListeners();

    return true;
  }

  void switchToPassenger() {
    if (_mode == AppMode.passenger) {
      return;
    }

    // Seguridad: al cambiar a pasajero el conductor deja
    // de estar disponible, pero su foto NO se borra.
    _driverOnline = false;
    _mode = AppMode.passenger;
    notifyListeners();
  }

  void setDriverOnline(bool value) {
    if (_driverOnline == value) {
      return;
    }

    _driverOnline = value;
    notifyListeners();
  }

  Future<void> setPassengerPhoto(String? base64Photo) async {
    final previous = passengerPhotoBase64;
    final normalized = _normalizePhoto(base64Photo);

    passengerPhotoBase64 = normalized;
    notifyListeners();

    try {
      await _writePersistentPhoto(key: _passengerPhotoKey, value: normalized);
    } catch (error) {
      passengerPhotoBase64 = previous;
      notifyListeners();

      debugPrint('MIGO: no se pudo guardar la foto del pasajero: $error');
      rethrow;
    }
  }

  Future<void> setDriverPhoto(String? base64Photo) async {
    final previousPhoto = driverPhotoBase64;
    final previousOnline = _driverOnline;
    final normalized = _normalizePhoto(base64Photo);

    driverPhotoBase64 = normalized;

    if (normalized == null) {
      _driverOnline = false;
    }

    notifyListeners();

    try {
      await _writePersistentPhoto(key: _driverPhotoKey, value: normalized);
    } catch (error) {
      driverPhotoBase64 = previousPhoto;
      _driverOnline = previousOnline;
      notifyListeners();

      debugPrint('MIGO: no se pudo guardar la foto del conductor: $error');
      rethrow;
    }
  }
}
