import 'package:flutter/foundation.dart';

enum AppMode { passenger, driver }

class AppSession extends ChangeNotifier {
  AppMode _mode = AppMode.passenger;

  // Temporal para poder probar ambos modos.
  // MÃ¡s adelante este permiso vendrÃ¡ desde el servidor NEXORA.
  final bool _driverApproved = true;

  AppMode get mode => _mode;

  bool get driverApproved => _driverApproved;

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

    _mode = AppMode.passenger;
    notifyListeners();
  }
}
