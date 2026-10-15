import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class ImmediateRideRequestScreen extends StatefulWidget {
  const ImmediateRideRequestScreen({super.key});

  @override
  State<ImmediateRideRequestScreen> createState() =>
      _ImmediateRideRequestScreenState();
}

enum _PinMode { pickup, destination }

class _ImmediateRideRequestScreenState
    extends State<ImmediateRideRequestScreen> {
  static const Color _blue = Color(0xFF1E4BFF);
  static const Color _green = Color(0xFF35D19A);
  static const Color _navy = Color(0xFF08254A);
  static const Color _bg = Color(0xFFF7F9FC);
  static const LatLng _huaraz = LatLng(-9.52779, -77.52778);
  static const String _apiV1 = 'http://10.0.2.2:8000/api/v1';

  GoogleMapController? _map;
  StreamSubscription<Position>? _positionSubscription;

  LatLng? _pickup;
  LatLng? _destination;
  LatLng? _lastRouteOrigin;

  String _pickupText = 'Obteniendo ubicación precisa...';
  String _destinationText = '¿A dónde quieres ir?';

  _PinMode _pinMode = _PinMode.destination;

  int _step = 0;
  double _offer = 10;
  String _payment = 'Efectivo';

  bool _locationBusy = false;
  bool _myLocationEnabled = false;
  bool _routeBusy = false;
  bool _isMocked = false;

  double? _gpsAccuracyMeters;
  double? _routeDistanceKm;
  int? _routeDurationMinutes;
  String? _routeError;

  List<LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_startPreciseLocation());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        title: Text(
          _step == 0
              ? 'Fijar recogida y destino'
              : _step == 1
                  ? 'Viaje inmediato'
                  : 'Método de pago',
          style: const TextStyle(
            color: _navy,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _step,
          children: [
            _locationStep(),
            _fareStep(),
            _paymentStep(),
          ],
        ),
      ),
    );
  }

  Widget _locationStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              _LocationCard(
                title: 'Punto A · Recogida',
                value: _pickupText,
                icon: Icons.my_location_rounded,
                color: _green,
                trailing: _locationBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'Actualizar GPS',
                        onPressed: () => _startPreciseLocation(forceOnce: true),
                        icon: const Icon(Icons.gps_fixed_rounded),
                      ),
                onTap: () => _openSearch(isPickup: true),
              ),
              const SizedBox(height: 10),
              _LocationCard(
                title: 'Punto B · Destino',
                value: _destinationText,
                icon: Icons.location_on_rounded,
                color: _blue,
                trailing: const Icon(Icons.search_rounded),
                onTap: () => _openSearch(isPickup: false),
              ),
              const SizedBox(height: 8),
              _statusStrip(),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _huaraz,
                  zoom: 14.2,
                ),
                onMapCreated: (controller) {
                  _map = controller;
                  if (_pickup != null && _destination == null) {
                    unawaited(
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_pickup!, 17),
                      ),
                    );
                  }
                },
                myLocationEnabled: _myLocationEnabled,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                markers: _markers,
                polylines: _polylines,
                onLongPress: _setPointFromMap,
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: SegmentedButton<_PinMode>(
                      segments: const [
                        ButtonSegment(
                          value: _PinMode.pickup,
                          icon: Icon(Icons.trip_origin_rounded),
                          label: Text('Fijar recogida'),
                        ),
                        ButtonSegment(
                          value: _PinMode.destination,
                          icon: Icon(Icons.location_on_rounded),
                          label: Text('Fijar destino'),
                        ),
                      ],
                      selected: {_pinMode},
                      onSelectionChanged: (selection) {
                        setState(() => _pinMode = selection.first);
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 100,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fit-route-migo',
                      backgroundColor: Colors.white,
                      foregroundColor: _navy,
                      onPressed: _pickup != null && _destination != null
                          ? _fitRoute
                          : null,
                      child: const Icon(Icons.zoom_out_map_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'gps-migo',
                      backgroundColor: Colors.white,
                      foregroundColor: _blue,
                      onPressed: () => _startPreciseLocation(forceOnce: true),
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: FilledButton(
                  onPressed: _pickup != null &&
                          _destination != null &&
                          !_routeBusy
                      ? _nextFare
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _routeBusy
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Calculando ruta real...'),
                          ],
                        )
                      : Text(
                          _routeDistanceKm != null
                              ? 'Continuar · ${_routeDistanceKm!.toStringAsFixed(1)} km · ${_routeDurationMinutes ?? 0} min'
                              : 'Continuar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusStrip() {
    final accuracyText = _gpsAccuracyMeters == null
        ? 'GPS buscando precisión...'
        : 'GPS ±${_gpsAccuracyMeters!.round()} m';

    final routeText = _routeBusy
        ? 'Calculando ruta...'
        : _routeDistanceKm != null
            ? '${_routeDistanceKm!.toStringAsFixed(1)} km · ${_routeDurationMinutes ?? 0} min'
            : 'Selecciona A y B';

    return Row(
      children: [
        Expanded(
          child: _MiniStatus(
            icon: _isMocked ? Icons.developer_mode_rounded : Icons.gps_fixed,
            text: _isMocked ? '$accuracyText · SIMULADO' : accuracyText,
            color: _isMocked ? Colors.orange : _green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatus(
            icon: Icons.route_rounded,
            text: routeText,
            color: _blue,
          ),
        ),
      ],
    );
  }

  Widget _fareStep() {
    final recommended = _recommendedFare;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        const Text(
          'Viaje inmediato',
          style: TextStyle(
            color: _navy,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La tarifa sugerida usa la distancia real de la ruta cuando está disponible.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        _RouteCard(
          pickup: _pickupText,
          destination: _destinationText,
        ),
        const SizedBox(height: 12),
        if (_routeDistanceKm != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: _blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_routeDistanceKm!.toStringAsFixed(1)} km por calles · '
                    '${_routeDurationMinutes ?? 0} min estimados',
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE8FF)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.local_taxi_rounded, color: _blue),
                  SizedBox(width: 10),
                  Text(
                    'Tu oferta',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Sugerido: S/ ${recommended.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _offer = (_offer - 0.50).clamp(3.0, 500.0);
                      });
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'S/ ${_offer.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'El conductor podrá aceptar o proponer otra tarifa',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _offer = (_offer + 0.50).clamp(3.0, 500.0);
                      });
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => setState(() => _step = 2),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Elegir cómo pagar',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Editar ruta'),
        ),
      ],
    );
  }

  Widget _paymentStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        const Text(
          '¿Cómo deseas pagar al conductor?',
          style: TextStyle(
            color: _navy,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige el método que usarás al finalizar el viaje.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        _PaymentCard(
          value: 'Efectivo',
          selectedValue: _payment,
          asset: 'assets/payments/efectivo.png',
          title: 'Efectivo',
          subtitle: 'Paga directamente al conductor.',
          onTap: _selectPayment,
        ),
        const SizedBox(height: 12),
        _PaymentCard(
          value: 'Plin',
          selectedValue: _payment,
          asset: 'assets/payments/plin.jpg',
          title: 'Plin',
          subtitle: 'Transfiere al conductor mediante Plin.',
          onTap: _selectPayment,
        ),
        const SizedBox(height: 12),
        _PaymentCard(
          value: 'Yape',
          selectedValue: _payment,
          asset: 'assets/payments/yape.png',
          title: 'Yape',
          subtitle: 'Transfiere al conductor mediante Yape.',
          onTap: _selectPayment,
        ),
        const SizedBox(height: 18),
        _RouteCard(
          pickup: _pickupText,
          destination: _destinationText,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFFAF6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Oferta: S/ ${_offer.toStringAsFixed(2)}   ·   Pago: $_payment',
            style: const TextStyle(
              color: _navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          key: const ValueKey('confirm-migo-ride'),
          onPressed: _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Confirmar y buscar conductor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Volver a la oferta'),
        ),
      ],
    );
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};

    if (_pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('point-a'),
          position: _pickup!,
          infoWindow: InfoWindow(
            title: 'A · Recogida',
            snippet: _gpsAccuracyMeters == null
                ? _pickupText
                : '${_pickupText} · ±${_gpsAccuracyMeters!.round()} m',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('point-b'),
          position: _destination!,
          infoWindow: InfoWindow(
            title: 'B · Destino',
            snippet: _destinationText,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.length < 2) {
      return const {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('google-route'),
        points: _routePoints,
        color: _blue,
        width: 7,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  double get _recommendedFare {
    final km = _routeDistanceKm ?? _straightDistanceKm ?? 0;
    final raw = 4.0 + (km * 1.50);
    return ((raw * 2).round() / 2).clamp(5.0, 200.0);
  }

  double? get _straightDistanceKm {
    if (_pickup == null || _destination == null) {
      return null;
    }

    return Geolocator.distanceBetween(
          _pickup!.latitude,
          _pickup!.longitude,
          _destination!.latitude,
          _destination!.longitude,
        ) /
        1000;
  }

  Future<void> _startPreciseLocation({bool forceOnce = false}) async {
    if (_locationBusy) return;

    setState(() => _locationBusy = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación del teléfono.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('MIGO necesita permiso de ubicación precisa.');
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      await _applyPosition(position, centerCamera: true);

      if (!forceOnce && _positionSubscription == null) {
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: settings,
        ).listen(
          (position) {
            unawaited(_applyPosition(position));
          },
          onError: (Object error) {
            if (mounted) {
              setState(() => _routeError = '$error');
            }
          },
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locationBusy = false);
      }
    }
  }

  Future<void> _applyPosition(
    Position position, {
    bool centerCamera = false,
  }) async {
    if (!mounted) return;

    final point = LatLng(position.latitude, position.longitude);

    setState(() {
      _pickup = point;
      _pickupText = 'Mi ubicación actual';
      _gpsAccuracyMeters = position.accuracy;
      _isMocked = position.isMocked;
      _myLocationEnabled = true;
    });

    if (centerCamera && _destination == null) {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 17.5),
      );
    }

    if (_destination != null) {
      final last = _lastRouteOrigin;
      final movedMeters = last == null
          ? double.infinity
          : Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              point.latitude,
              point.longitude,
            );

      if (movedMeters >= 15 && !_routeBusy) {
        await _refreshRoute();
      }
    }
  }

  void _setPointFromMap(LatLng point) {
    setState(() {
      if (_pinMode == _PinMode.pickup) {
        _pickup = point;
        _pickupText = 'Punto A fijado en el mapa';
        _gpsAccuracyMeters = null;
        _isMocked = false;
      } else {
        _destination = point;
        _destinationText = 'Punto B fijado en el mapa';
      }
    });

    unawaited(_refreshRoute());
  }

  Future<void> _openSearch({required bool isPickup}) async {
    final result = await showModalBottomSheet<_PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSearchSheet(
        apiV1: _apiV1,
        title: isPickup ? 'Buscar punto de recogida' : 'Buscar destino',
        center: _pickup ?? _huaraz,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (isPickup) {
        _pickup = result.point;
        _pickupText = result.label;
        _gpsAccuracyMeters = null;
      } else {
        _destination = result.point;
        _destinationText = result.label;
      }
    });

    await _refreshRoute();
  }

  Future<void> _refreshRoute() async {
    if (_pickup == null || _destination == null || _routeBusy) {
      return;
    }

    setState(() {
      _routeBusy = true;
      _routeError = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_apiV1/routes/compute'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {
                'latitude': _pickup!.latitude,
                'longitude': _pickup!.longitude,
              },
              'destination': {
                'latitude': _destination!.latitude,
                'longitude': _destination!.longitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Ruta HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = data['encoded_polyline'] as String?;
      final distanceKm = (data['distance_km'] as num?)?.toDouble();
      final durationMinutes = (data['duration_minutes'] as num?)?.round();

      if (encoded == null || encoded.isEmpty) {
        throw Exception('Google Routes no devolvió la polilínea.');
      }

      final decoded = _decodePolyline(encoded);

      if (!mounted) return;

      setState(() {
        _routePoints = decoded;
        _routeDistanceKm = distanceKm;
        _routeDurationMinutes = durationMinutes;
        _lastRouteOrigin = _pickup;
      });

      await _fitRoute();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _routeError = '$error';
        _routePoints = [_pickup!, _destination!];
        _routeDistanceKm = null;
        _routeDurationMinutes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo calcular la ruta por calles. $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _routeBusy = false);
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      result = 0;
      shift = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(
        LatLng(
          lat / 1E5,
          lng / 1E5,
        ),
      );
    }

    return points;
  }

  Future<void> _fitRoute() async {
    if (_map == null || _pickup == null || _destination == null) {
      return;
    }

    final points = <LatLng>[
      _pickup!,
      _destination!,
      ..._routePoints,
    ];

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0001 &&
        (maxLng - minLng).abs() < 0.0001) {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickup!, 17),
      );
      return;
    }

    await _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  void _nextFare() {
    setState(() {
      _offer = _recommendedFare;
      _step = 1;
    });
  }

  void _selectPayment(String value) {
    setState(() => _payment = value);
  }

  Future<void> _confirm() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(
                  Icons.local_taxi_rounded,
                  size: 54,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Solicitud preparada',
                style: TextStyle(
                  color: _navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text('A · Recogida: $_pickupText'),
              Text('B · Destino: $_destinationText'),
              if (_routeDistanceKm != null)
                Text(
                  'Ruta: ${_routeDistanceKm!.toStringAsFixed(1)} km · '
                  '${_routeDurationMinutes ?? 0} min',
                ),
              Text('Oferta: S/ ${_offer.toStringAsFixed(2)}'),
              Text('Pago al conductor: $_payment'),
              const SizedBox(height: 18),
              const Text(
                'El siguiente módulo enviará esta solicitud en tiempo real a los conductores conectados.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ImmediateRideRequestScreenState._navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF08254A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.destination,
  });

  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _RouteRow(
            color: const Color(0xFF35D19A),
            title: 'A · Recogida',
            value: pickup,
          ),
          const SizedBox(height: 10),
          _RouteRow(
            color: const Color(0xFF1E4BFF),
            title: 'B · Destino',
            value: destination,
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.color,
    required this.title,
    required this.value,
  });

  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF08254A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.value,
    required this.selectedValue,
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String value;
  final String selectedValue;
  final String asset;
  final String title;
  final String subtitle;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1E4BFF)
                  : const Color(0xFFE3E9F3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF08254A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? const Color(0xFF1E4BFF) : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceResult {
  const _PlaceResult({
    required this.label,
    required this.point,
  });

  final String label;
  final LatLng point;
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.placeId,
    required this.text,
  });

  final String placeId;
  final String text;
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.apiV1,
    required this.title,
    required this.center,
  });

  final String apiV1;
  final String title;
  final LatLng center;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _controller = TextEditingController();
  Timer? _timer;
  bool _loading = false;
  String? _error;
  List<_PlaceSuggestion> _items = const [];

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();

    if (text.trim().length < 2) {
      setState(() {
        _items = const [];
        _error = null;
      });
      return;
    }

    _timer = Timer(
      const Duration(milliseconds: 350),
      () => _search(text.trim()),
    );
  }

  Future<void> _search(String input) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${widget.apiV1}/places/autocomplete',
      ).replace(
        queryParameters: {
          'input': input,
          'lat': '${widget.center.latitude}',
          'lng': '${widget.center.longitude}',
        },
      );

      final response = await http.get(uri).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final raw = jsonDecode(response.body);

      if (raw is! List) {
        throw Exception('Respuesta Places inválida.');
      }

      final items = raw.whereType<Map<String, dynamic>>().map((item) {
        return _PlaceSuggestion(
          placeId: item['place_id'] as String,
          text: item['text'] as String,
        );
      }).toList();

      if (mounted) {
        setState(() => _items = items);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _items = const [];
          _error = 'No se pudo buscar lugares. $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _choose(_PlaceSuggestion item) async {
    setState(() => _loading = true);

    try {
      final response = await http
          .get(
            Uri.parse('${widget.apiV1}/places/${item.placeId}'),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final raw = jsonDecode(response.body) as Map<String, dynamic>;

      final result = _PlaceResult(
        label: raw['label'] as String,
        point: LatLng(
          (raw['latitude'] as num).toDouble(),
          (raw['longitude'] as num).toDouble(),
        ),
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo seleccionar ese lugar. $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    labelText: widget.title,
                    hintText: 'Ej. Plaza de Armas Huaraz',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF1E4BFF),
                      ),
                      title: Text(item.text),
                      onTap: () => _choose(item),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Google',
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
