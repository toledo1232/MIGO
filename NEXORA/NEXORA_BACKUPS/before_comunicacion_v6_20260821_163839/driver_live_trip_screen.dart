import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/app_session.dart';
import '../../shared/live_trip_support.dart';

class DriverLiveTripScreen extends StatefulWidget {
  const DriverLiveTripScreen({
    required this.session,
    required this.initialRide,
    super.key,
  });

  final AppSession session;
  final Map<String, dynamic> initialRide;

  @override
  State<DriverLiveTripScreen> createState() => _DriverLiveTripScreenState();
}

class _DriverLiveTripScreenState extends State<DriverLiveTripScreen> {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);
  static const _danger = Color(0xFFD92D20);

  late Map<String, dynamic> _ride;

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  Position? _position;
  LiveTripRoute? _route;

  bool _locationReady = false;
  bool _routeBusy = false;
  bool _actionBusy = false;
  bool _sendingLocation = false;
  String? _locationError;

  DateTime? _lastLocationSentAt;
  DateTime? _lastRouteAt;

  String get _requestId => _ride['id']?.toString() ?? '';
  String get _status => _ride['status']?.toString() ?? 'accepted';

  LatLng? get _pickup => LiveTripApi.pointFromRide(_ride, 'pickup');
  LatLng? get _destination => LiveTripApi.pointFromRide(_ride, 'destination');

  LatLng? get _driver {
    final position = _position;

    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }

    return LiveTripApi.pointFromRide(_ride, 'driver');
  }

  @override
  void initState() {
    super.initState();
    _ride = Map<String, dynamic>.from(widget.initialRide);

    // Durante un viaje el conductor no debe recibir solicitudes nuevas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.session.setDriverOnline(false);
      _connectRealtime();
      _startLocationTracking();
      _refreshRoute(force: true);
    });

    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollRide(),
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _positionSubscription?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    if (_requestId.isEmpty || _socket != null || !mounted) {
      return;
    }

    try {
      final socket = await WebSocket.connect(
        'ws://10.0.2.2:8000/api/v1/ride-requests/ws/request/$_requestId',
      ).timeout(const Duration(seconds: 6));

      if (!mounted) {
        await socket.close();
        return;
      }

      _socket = socket;
      _socketSubscription = socket.listen(
        _handleRealtime,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socketSubscription = null;
    _socket = null;

    if (!mounted || _status == 'completed') {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _connectRealtime);
  }

  void _handleRealtime(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (decoded['event']?.toString() != 'ride_updated') {
        return;
      }

      final ride = decoded['ride'];
      if (ride is Map<String, dynamic>) {
        _applyRide(ride, forceRoute: true);
      }
    } catch (_) {
      // Un mensaje inválido no rompe la navegación.
    }
  }

  Future<void> _pollRide() async {
    if (_requestId.isEmpty) {
      return;
    }

    try {
      final ride = await LiveTripApi.getRide(_requestId);
      _applyRide(ride);
    } catch (_) {
      // WebSocket sigue siendo el canal principal.
    }
  }

  void _applyRide(Map<String, dynamic> ride, {bool forceRoute = false}) {
    if (!mounted) {
      return;
    }

    final previousStatus = _status;

    setState(() {
      _ride = Map<String, dynamic>.from(ride);
    });

    if (_status == 'completed') {
      _positionSubscription?.cancel();
    }

    _refreshRoute(force: forceRoute || previousStatus != _status);
    _fitMap();
  }

  Future<void> _startLocationTracking() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();

    if (!servicesEnabled) {
      if (mounted) {
        setState(() {
          _locationError =
              'Activa la ubicación del emulador o dispositivo para continuar.';
        });
      }
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationError =
              'MIGO necesita permiso de ubicación para compartir tu posición con el pasajero.';
        });
      }
      return;
    }

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _position = first;
        _locationReady = true;
        _locationError = null;
      });

      await _sendLocation(first, force: true);
      await _refreshRoute(force: true);
      await _fitMap();

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 3,
            ),
          ).listen(
            (position) {
              if (!mounted) {
                return;
              }

              setState(() {
                _position = position;
                _locationReady = true;
                _locationError = null;
              });

              _sendLocation(position);
              _refreshRoute();
              _fitMap();
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _locationError = 'Se perdió temporalmente la señal GPS.';
                });
              }
            },
          );
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationError = 'No pudimos leer tu GPS: $error';
        });
      }
    }
  }

  Future<void> _sendLocation(Position position, {bool force = false}) async {
    if (_sendingLocation || _status == 'completed') {
      return;
    }

    final now = DateTime.now();

    if (!force &&
        _lastLocationSentAt != null &&
        now.difference(_lastLocationSentAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastLocationSentAt = now;
    _sendingLocation = true;

    try {
      final ride = await LiveTripApi.postRideAction(
        _requestId,
        'driver-location',
        body: {'latitude': position.latitude, 'longitude': position.longitude},
      );

      if (!mounted) {
        return;
      }

      _applyRide(ride);
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationError = 'No se pudo enviar la ubicación: $error';
        });
      }
    } finally {
      _sendingLocation = false;
    }
  }

  Future<void> _refreshRoute({bool force = false}) async {
    final driver = _driver;
    final pickup = _pickup;
    final destination = _destination;

    if (_routeBusy ||
        driver == null ||
        pickup == null ||
        destination == null ||
        _status == 'completed') {
      return;
    }

    final now = DateTime.now();

    if (!force &&
        _lastRouteAt != null &&
        now.difference(_lastRouteAt!) < const Duration(seconds: 8)) {
      return;
    }

    _lastRouteAt = now;

    final target = _status == 'in_progress' ? destination : pickup;

    _routeBusy = true;

    try {
      final route = await LiveTripApi.computeRoute(driver, target);

      if (!mounted) {
        return;
      }

      if (route != null) {
        setState(() {
          _route = route;
        });
      } else {
        final meters = Geolocator.distanceBetween(
          driver.latitude,
          driver.longitude,
          target.latitude,
          target.longitude,
        );

        setState(() {
          _route = LiveTripRoute(
            points: [driver, target],
            distanceKm: meters / 1000,
            durationMinutes: meters <= 50
                ? 1
                : ((meters / 1000) / 25 * 60).ceil(),
          );
        });
      }

      _fitMap();
    } finally {
      _routeBusy = false;
    }
  }

  Future<void> _fitMap() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    final points = <LatLng>[?_driver, ?_pickup, ?_destination];

    if (points.isEmpty) {
      return;
    }

    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
      } else {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(LiveTripApi.boundsFor(points), 76),
        );
      }
    } catch (_) {
      // El controlador puede estar ajustándose al crear el mapa.
    }
  }

  Future<void> _changeStatus(String action) async {
    if (_actionBusy || _requestId.isEmpty) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final ride = await LiveTripApi.postRideAction(_requestId, action);

      if (!mounted) {
        return;
      }

      _applyRide(ride, forceRoute: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el viaje: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};

    final driver = _driver;
    final pickup = _pickup;
    final destination = _destination;

    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 10,
        ),
      );
    }

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Recoger pasajero'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Destino'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _polylines() {
    final route = _route;

    if (route == null || route.points.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('live_route'),
        points: route.points,
        color: _blue,
        width: 6,
      ),
    };
  }

  String get _statusTitle {
    return switch (_status) {
      'accepted' => 'Preparando viaje',
      'driver_en_route' => 'En camino al pasajero',
      'driver_arrived' => 'Llegaste al punto de recogida',
      'in_progress' => 'Viaje en curso',
      'completed' => 'Viaje finalizado',
      _ => 'Viaje MIGO',
    };
  }

  String get _statusSubtitle {
    return switch (_status) {
      'accepted' => 'Activando GPS y compartiendo tu ubicación.',
      'driver_en_route' => 'Dirígete al punto de recogida.',
      'driver_arrived' => 'Confirma cuando el pasajero haya abordado.',
      'in_progress' =>
        'Conduce hacia ${_ride['destination_text'] ?? 'el destino'}.',
      'completed' => 'El viaje se completó correctamente.',
      _ => 'Sincronizando el estado del viaje.',
    };
  }

  String get _actionText {
    return switch (_status) {
      'accepted' || 'driver_en_route' => 'He llegado',
      'driver_arrived' => 'Iniciar viaje',
      'in_progress' => 'Finalizar viaje',
      'completed' => 'Volver al inicio',
      _ => 'Actualizar',
    };
  }

  Future<void> _primaryAction() async {
    switch (_status) {
      case 'accepted':
      case 'driver_en_route':
        await _changeStatus('arrived');
        break;
      case 'driver_arrived':
        await _changeStatus('start');
        break;
      case 'in_progress':
        await _changeStatus('complete');
        break;
      case 'completed':
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        break;
    }
  }

  Widget _passengerAvatar() {
    final name = _ride['passenger_name']?.toString() ?? 'Pasajero MIGO';
    final photo = _ride['passenger_photo_base64']?.toString();

    if (photo != null && photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 25,
          backgroundImage: MemoryImage(base64Decode(photo)),
          backgroundColor: const Color(0xFFEAF0FF),
        );
      } catch (_) {
        // Se usa inicial si la foto no puede decodificarse.
      }
    }

    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w900,
          fontSize: 19,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter =
        _driver ?? _pickup ?? _destination ?? const LatLng(-9.5278, -77.5278);

    return PopScope(
      canPop: _status == 'completed',
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FD),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFF7F9FD),
          foregroundColor: _navy,
          elevation: 0,
          title: Text(
            _statusTitle,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w900),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialCenter,
                  zoom: 14.5,
                ),
                myLocationEnabled: _locationReady,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                markers: _markers(),
                polylines: _polylines(),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitMap();
                },
              ),
            ),
            Positioned(top: 14, left: 14, right: 14, child: _statusCard()),
            Positioned(left: 14, right: 14, bottom: 18, child: _bottomCard()),
            if (_locationError != null)
              Positioned(
                top: 120,
                left: 14,
                right: 14,
                child: Material(
                  color: _danger,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_off_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationError!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final route = _route;

    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _turquoise.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _status == 'completed'
                    ? Icons.check_rounded
                    : Icons.navigation_rounded,
                color: _status == 'completed' ? _turquoise : _blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusTitle,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusSubtitle,
                    style: const TextStyle(
                      color: Color(0xFF748096),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (route != null && _status != 'completed')
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${route.durationMinutes} min',
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${route.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF748096),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomCard() {
    final passengerName =
        _ride['passenger_name']?.toString() ?? 'Pasajero MIGO';
    final passengerRating =
        (_ride['passenger_rating'] as num?)?.toDouble() ?? 5;
    final passengerTrips = (_ride['passenger_trips'] as num?)?.toInt() ?? 0;

    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _passengerAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '★ ${passengerRating.toStringAsFixed(1)} · $passengerTrips viajes',
                        style: const TextStyle(
                          color: Color(0xFF748096),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _status == 'in_progress'
                            ? (_ride['destination_text']?.toString() ??
                                  'Destino')
                            : (_ride['pickup_text']?.toString() ??
                                  'Punto de recogida'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF748096),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'S/ ${(((_ride['offer'] as num?)?.toDouble()) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            FilledButton(
              onPressed: _actionBusy ? null : _primaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: _status == 'in_progress' ? _danger : _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _actionBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _actionText,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
