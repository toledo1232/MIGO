import 'package:flutter/foundation.dart';

enum AppMode { passenger, driver }

class AppSession extends ChangeNotifier {
  AppSession() {
    current = this;
  }

  // Una sola sesión pública por instancia de la app.
  // Se usa temporalmente para compartir el perfil entre pantallas.
  static AppSession? current;

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
  bool get hasDriverPhoto =>
      driverPhotoBase64 != null && driverPhotoBase64!.isNotEmpty;

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

  void setPassengerPhoto(String? base64Photo) {
    passengerPhotoBase64 = base64Photo;
    notifyListeners();
  }

  void setDriverPhoto(String? base64Photo) {
    driverPhotoBase64 = base64Photo;

    if (base64Photo == null || base64Photo.isEmpty) {
      _driverOnline = false;
    }

    notifyListeners();
  }
}
