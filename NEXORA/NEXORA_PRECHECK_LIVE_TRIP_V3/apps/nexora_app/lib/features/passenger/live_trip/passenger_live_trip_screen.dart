import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../shared/live_trip_support.dart';

class PassengerLiveTripScreen extends StatefulWidget {
  const PassengerLiveTripScreen({required this.initialRide, super.key});

  final Map<String, dynamic> initialRide;

  @override
  State<PassengerLiveTripScreen> createState() =>
      _PassengerLiveTripScreenState();
}

class _PassengerLiveTripScreenState extends State<PassengerLiveTripScreen> {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);
  static const _danger = Color(0xFFD92D20);

  late Map<String, dynamic> _ride;

  GoogleMapController? _mapController;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  LiveTripRoute? _route;
  bool _routeBusy = false;
  String? _error;
  DateTime? _lastRouteAt;

  String get _requestId => _ride['id']?.toString() ?? '';
  String get _status => _ride['status']?.toString() ?? 'accepted';

  LatLng? get _pickup => LiveTripApi.pointFromRide(_ride, 'pickup');
  LatLng? get _destination => LiveTripApi.pointFromRide(_ride, 'destination');
  LatLng? get _driver => LiveTripApi.pointFromRide(_ride, 'driver');

  @override
  void initState() {
    super.initState();
    _ride = Map<String, dynamic>.from(widget.initialRide);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectRealtime();
      _refreshRoute(force: true);
      _fitMap();
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

      final event = decoded['event']?.toString();

      if (event == 'ride_updated') {
        final ride = decoded['ride'];
        if (ride is Map<String, dynamic>) {
          _applyRide(ride, forceRoute: true);
        }
        return;
      }

      if (event == 'driver_location') {
        final lat = (decoded['latitude'] as num?)?.toDouble();
        final lng = (decoded['longitude'] as num?)?.toDouble();

        if (lat == null || lng == null || !mounted) {
          return;
        }

        setState(() {
          _ride['driver_lat'] = lat;
          _ride['driver_lng'] = lng;
          _ride['driver_location_updated_at'] = decoded['updated_at'];

          final status = decoded['status']?.toString();
          if (status != null && status.isNotEmpty) {
            _ride['status'] = status;
          }
        });

        _refreshRoute();
        _fitMap();
      }
    } catch (_) {
      // Un mensaje inválido no rompe la pantalla.
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
      // WebSocket sigue siendo la vía principal.
    }
  }

  void _applyRide(Map<String, dynamic> ride, {bool forceRoute = false}) {
    if (!mounted) {
      return;
    }

    final previousStatus = _status;

    setState(() {
      _ride = Map<String, dynamic>.from(ride);
      _error = null;
    });

    _refreshRoute(force: forceRoute || previousStatus != _status);
    _fitMap();
  }

  Future<void> _refreshRoute({bool force = false}) async {
    final driver = _driver;
    final pickup = _pickup;
    final destination = _destination;

    if (_routeBusy || pickup == null || destination == null) {
      return;
    }

    final now = DateTime.now();

    if (!force &&
        _lastRouteAt != null &&
        now.difference(_lastRouteAt!) < const Duration(seconds: 8)) {
      return;
    }

    _lastRouteAt = now;

    LatLng origin;
    LatLng target;

    if (_status == 'in_progress') {
      origin = driver ?? pickup;
      target = destination;
    } else if (_status == 'completed') {
      setState(() {
        _route = null;
      });
      return;
    } else {
      origin = driver ?? pickup;
      target = pickup;
    }

    if (origin.latitude == target.latitude &&
        origin.longitude == target.longitude) {
      setState(() {
        _route = LiveTripRoute(
          points: [origin, target],
          distanceKm: 0,
          durationMinutes: 0,
        );
      });
      return;
    }

    _routeBusy = true;

    try {
      final route = await LiveTripApi.computeRoute(origin, target);

      if (!mounted) {
        return;
      }

      if (route != null) {
        setState(() {
          _route = route;
        });
      } else {
        final meters = Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          target.latitude,
          target.longitude,
        );

        setState(() {
          _route = LiveTripRoute(
            points: [origin, target],
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
      // El mapa puede estar ajustándose durante su creación.
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};

    final pickup = _pickup;
    final destination = _destination;
    final driver = _driver;

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Tu punto de recogida'),
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

    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          infoWindow: const InfoWindow(title: 'Tu conductor'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 10,
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
      'accepted' => 'Conductor confirmado',
      'driver_en_route' => 'Tu conductor está en camino',
      'driver_arrived' => 'Tu conductor llegó',
      'in_progress' => 'Viaje en curso',
      'completed' => 'Viaje completado',
      _ => 'Actualizando viaje',
    };
  }

  String get _statusSubtitle {
    return switch (_status) {
      'accepted' =>
        _driver == null
            ? 'Esperando la primera ubicación GPS del conductor.'
            : 'Preparando la ruta hacia tu punto de recogida.',
      'driver_en_route' => 'Sigue el vehículo en el mapa en tiempo real.',
      'driver_arrived' => 'Tu conductor está en el punto de recogida.',
      'in_progress' => 'Rumbo a ${_ride['destination_text'] ?? 'tu destino'}.',
      'completed' => 'El viaje terminó correctamente.',
      _ => 'Sincronizando información del viaje.',
    };
  }

  Widget _driverAvatar() {
    final name = _ride['driver_name']?.toString() ?? 'Conductor MIGO';
    final photo = _ride['driver_photo_base64']?.toString();

    if (photo != null && photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 27,
          backgroundImage: MemoryImage(base64Decode(photo)),
          backgroundColor: const Color(0xFFEAF0FF),
        );
      } catch (_) {
        // Avatar de inicial como respaldo.
      }
    }

    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickup;
    final destination = _destination;
    final initialCenter =
        _driver ?? pickup ?? destination ?? const LatLng(-9.5278, -77.5278);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FD),
        foregroundColor: _navy,
        elevation: 0,
        automaticallyImplyLeading: false,
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
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
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
          if (_error != null)
            Positioned(
              left: 14,
              right: 14,
              top: 120,
              child: Material(
                color: _danger,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                    : Icons.local_taxi_rounded,
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
    final name = _ride['driver_name']?.toString() ?? 'Conductor MIGO';
    final rating = (_ride['driver_rating'] as num?)?.toDouble() ?? 5;
    final trips = (_ride['driver_trips'] as num?)?.toInt() ?? 0;
    final vehicle = _ride['vehicle_model']?.toString() ?? 'Vehículo';
    final color = _ride['vehicle_color']?.toString() ?? '';
    final plate = _ride['vehicle_plate']?.toString() ?? '';

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
                _driverAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '★ ${rating.toStringAsFixed(1)} · $trips viajes',
                        style: const TextStyle(
                          color: Color(0xFF748096),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          vehicle,
                          color,
                          plate,
                        ].where((value) => value.trim().isNotEmpty).join(' · '),
                        maxLines: 1,
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
            if (_status == 'completed') ...[
              const SizedBox(height: 15),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  'Volver al inicio',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
