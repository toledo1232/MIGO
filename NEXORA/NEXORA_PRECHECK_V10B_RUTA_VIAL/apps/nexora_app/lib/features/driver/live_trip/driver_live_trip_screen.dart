import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/app_session.dart';
import '../../shared/live_trip_support.dart';
import '../../shared/live_trip_tools.dart';

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
  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _passengerMarkerIcon;

  bool _routeBusy = false;
  bool _actionBusy = false;
  bool _sendingLocation = false;
  bool _completionAlertShown = false;
  bool _cancellationAlertShown = false;
  String? _locationError;
  String? _routeError;

  DateTime? _lastLocationSentAt;
  DateTime? _lastRouteAt;

  String get _requestId => _ride['id']?.toString() ?? '';
  String get _status => _ride['status']?.toString() ?? 'accepted';
  String? get _visibleError => _locationError ?? _routeError;

  bool get _nearDestination {
    final destination = _destination;
    final driver = _driver;

    if (destination == null || driver == null) {
      return false;
    }

    final meters = Geolocator.distanceBetween(
      driver.latitude,
      driver.longitude,
      destination.latitude,
      destination.longitude,
    );

    return meters <= 400;
  }

  LatLng? get _pickup => LiveTripApi.pointFromRide(_ride, 'pickup');
  LatLng? get _destination => LiveTripApi.pointFromRide(_ride, 'destination');

  LatLng? get _passengerLive {
    final lat = (_ride['passenger_live_lat'] as num?)?.toDouble();
    final lng = (_ride['passenger_live_lng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      return _pickup;
    }

    return LatLng(lat, lng);
  }

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
      _loadMarkerIcons();
      _connectRealtime();
      _startLocationTracking();
      _refreshRoute(force: true);

      if (_status == 'arrival_reported' &&
          _ride['completion_requested_by']?.toString() == 'passenger') {
        _showCompletionDialog();
      } else if (_status == 'cancelled') {
        _showCancelledAlert();
      }
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

  Future<void> _loadMarkerIcons() async {
    final car = await LiveTripMarkerFactory.carMarker();
    final passenger = await LiveTripMarkerFactory.profileMarker(
      name: _ride['passenger_name']?.toString() ?? 'Pasajero MIGO',
      base64Photo: _ride['passenger_photo_base64']?.toString(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _driverMarkerIcon = car;
      _passengerMarkerIcon = passenger;
    });
  }

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LiveTripChatSheet(
        requestId: _requestId,
        actor: 'driver',
        otherName: _ride['passenger_name']?.toString() ?? 'tu pasajero',
      ),
    );
  }

  Future<void> _cancelTrip() async {
    if (_actionBusy || _status == 'completed' || _status == 'cancelled') {
      return;
    }

    final choice = await showTripCancellationSheet(context, actor: 'driver');

    if (choice == null || !mounted) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final ride = await LiveTripApi.postRideAction(
        _requestId,
        'cancel',
        body: {
          'actor': 'driver',
          'reason': choice.reason,
          'details': choice.details,
        },
      );

      _applyRide(ride, forceRoute: true);
      await _showCancelledAlert();
    } catch (error) {
      if (mounted) {
        setState(() {
          _routeError = 'No se pudo cancelar el viaje: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _showCancelledAlert() async {
    if (!mounted || _cancellationAlertShown) {
      return;
    }

    _cancellationAlertShown = true;

    final actor = _ride['cancelled_by']?.toString();
    final reason = _ride['cancellation_reason']?.toString() ?? 'Sin motivo';
    final details = _ride['cancellation_details']?.toString();
    final creditsStatus = _ride['credits_status']?.toString() ?? 'none';
    final review = _ride['cancellation_review_required'] == true;

    final creditText = review || creditsStatus == 'review'
        ? 'Los créditos quedan pendientes de revisión administrativa; '
              'MIGO no los consume definitivamente a ciegas.'
        : creditsStatus == 'released'
        ? 'La reserva de créditos fue liberada porque el viaje no '
              'había iniciado.'
        : 'No había créditos consumidos por este viaje.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cancel_rounded, color: _danger, size: 40),
        title: const Text('Viaje cancelado'),
        content: Text(
          '${actor == 'passenger' ? 'El pasajero' : 'El conductor'} canceló '
          'el viaje.\\n\\nMotivo: $reason'
          '${details == null || details.isEmpty ? '' : '\\nDetalles: $details'}'
          '\\n\\n$creditText',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompletion() async {
    if (_actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final ride = await LiveTripApi.postRideAction(
        _requestId,
        'complete-confirm',
        body: {
          'actor': 'driver',
          'reason': _nearDestination
              ? 'destination_reached'
              : 'mutual_early_finish',
        },
      );

      _applyRide(ride, forceRoute: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _routeError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _continueTripAfterFinishRequest() async {
    if (_actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final ride = await LiveTripApi.postRideAction(
        _requestId,
        'complete-problem',
      );

      _completionAlertShown = false;
      _applyRide(ride, forceRoute: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _routeError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _showCompletionDialog() async {
    if (!mounted || _completionAlertShown) {
      return;
    }

    _completionAlertShown = true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('El pasajero solicita finalizar'),
        content: Text(
          _ride['completion_near_destination'] == true
              ? 'El pasajero indica que llegaron al destino. '
                    '¿Confirmas la finalización del viaje?'
              : 'El pasajero solicita finalizar antes del punto B. '
                    'Confirma solo si ambos están de acuerdo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar viaje'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (accepted == true) {
      await _confirmCompletion();
    } else if (accepted == false) {
      await _continueTripAfterFinishRequest();
    }
  }

  Future<void> _triggerSos() async {
    final driver = _driver;

    try {
      await LiveTripApi.triggerSos(
        _requestId,
        actor: 'driver',
        position: driver,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _danger,
          content: Text('Alerta SOS enviada a MIGO y al pasajero.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _routeError = 'No se pudo enviar SOS: $error';
        });
      }
    }
  }

  Future<void> _showSosAlert(String actor) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos_rounded, color: _danger, size: 38),
        title: const Text('Alerta de seguridad'),
        content: Text(
          actor == 'passenger'
              ? 'El pasajero activó una alerta SOS durante el viaje.'
              : 'Se activó una alerta SOS para este viaje.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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

    if (!mounted || _status == 'completed' || _status == 'cancelled') {
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

      if (event == 'ride_message') {
        final message = decoded['message'];

        if (message is Map<String, dynamic> &&
            message['actor']?.toString() == 'passenger' &&
            mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mensaje del pasajero: ${message['text'] ?? ''}'),
            ),
          );
        }
        return;
      }

      if (event == 'passenger_location') {
        final lat = (decoded['latitude'] as num?)?.toDouble();
        final lng = (decoded['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null && mounted) {
          setState(() {
            _ride['passenger_live_lat'] = lat;
            _ride['passenger_live_lng'] = lng;
            _ride['passenger_location_updated_at'] = decoded['updated_at'];
          });
          _fitMap();
        }
        return;
      }

      if (event == 'sos_alert') {
        final actor = decoded['actor']?.toString() ?? '';
        if (actor != 'driver') {
          _showSosAlert(actor);
        }
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

    if (_status == 'completed' || _status == 'cancelled') {
      _positionSubscription?.cancel();
    }

    if (_status == 'arrival_reported' &&
        previousStatus != 'arrival_reported' &&
        _ride['completion_requested_by']?.toString() == 'passenger') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showCompletionDialog(),
      );
    }

    if (_status == 'cancelled' && previousStatus != 'cancelled') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showCancelledAlert(),
      );
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
    if (_sendingLocation || _status == 'completed' || _status == 'cancelled') {
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
        _tripClosed) {
      return;
    }

    final now = DateTime.now();

    if (!force &&
        _lastRouteAt != null &&
        now.difference(_lastRouteAt!) < const Duration(seconds: 8)) {
      return;
    }

    _lastRouteAt = now;

    final target = (_status == 'in_progress' || _status == 'arrival_reported')
        ? destination
        : pickup;

    if ((driver.latitude - target.latitude).abs() < 0.000001 &&
        (driver.longitude - target.longitude).abs() < 0.000001) {
      if (mounted) {
        setState(() {
          _route = null;
          _routeError = null;
        });
      }
      return;
    }

    _routeBusy = true;

    try {
      final route = await LiveTripApi.computeRoute(driver, target);

      if (!mounted) {
        return;
      }

      setState(() {
        _route = route;
        _routeError = null;
      });

      await _fitMap();
    } catch (error) {
      if (mounted) {
        setState(() {
          _route = null;
          _routeError =
              'No se pudo calcular temporalmente la ruta por calles. '
              'MIGO no mostrará una línea recta falsa. $error';
        });
      }
    } finally {
      _routeBusy = false;
    }
  }

  Future<void> _fitMap() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    final points = <LatLng>[?_driver, ?_passengerLive, ?_pickup, ?_destination];

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
          icon:
              _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 10,
        ),
      );
    }

    final passengerLive = _passengerLive;

    if (passengerLive != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('passenger_live'),
          position: passengerLive,
          infoWindow: const InfoWindow(title: 'Ubicación del pasajero'),
          icon:
              _passengerMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          zIndexInt: 9,
        ),
      );
    }

    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Punto A · Recogida'),
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
          infoWindow: const InfoWindow(title: 'Punto B · Destino'),
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
      'arrival_reported' => 'Finalización pendiente',
      'cancelled' => 'Viaje cancelado',
      'completed' => 'Viaje finalizado',
      _ => 'Viaje MIGO',
    };
  }

  String get _statusSubtitle {
    return switch (_status) {
      'accepted' => 'Activando GPS y compartiendo tu ubicación.',
      'driver_en_route' =>
        'Recoge al pasajero en ${_ride['pickup_text'] ?? 'el punto A'}.',
      'driver_arrived' => 'Confirma cuando el pasajero haya abordado.',
      'in_progress' =>
        'Conduce hacia ${_ride['destination_text'] ?? 'el destino'}.',
      'arrival_reported' =>
        _ride['completion_requested_by']?.toString() == 'driver'
            ? 'Esperando que el pasajero confirme la finalización.'
            : 'El pasajero solicita finalizar el viaje.',
      'cancelled' => 'El viaje fue cancelado y quedó registrado en MIGO.',
      'completed' => 'El viaje se completó correctamente.',
      _ => 'Sincronizando el estado del viaje.',
    };
  }

  String get _actionText {
    return switch (_status) {
      'accepted' || 'driver_en_route' => 'Ya llegué',
      'driver_arrived' => 'Iniciar viaje',
      'in_progress' => 'Solicitar finalizar viaje',
      'arrival_reported' => 'Esperando confirmación',
      'cancelled' => 'Volver al inicio',
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
        await _requestCompletion();
        break;
      case 'arrival_reported':
        break;
      case 'cancelled':
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        break;
      case 'completed':
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        break;
    }
  }

  Future<void> _requestCompletion() async {
    if (_actionBusy || _status != 'in_progress') {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final ride = await LiveTripApi.postRideAction(
        _requestId,
        'complete-request',
        body: const {'actor': 'driver'},
      );

      if (!mounted) {
        return;
      }

      _applyRide(ride, forceRoute: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _routeError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
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
      canPop: _status == 'completed' || _status == 'cancelled',
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
                myLocationEnabled: false,
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
            if (_visibleError != null)
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
                            _visibleError!,
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
                        (_status == 'in_progress' ||
                                _status == 'arrival_reported')
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
            if (_status != 'completed' && _status != 'cancelled') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showPrivateCallNotice(
                        context,
                        otherName: passengerName,
                      ),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Llamar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Mensaje', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: HoldSosButton(onTriggered: _triggerSos)),
                ],
              ),
            ],
            if (_status == 'accepted' ||
                _status == 'driver_en_route' ||
                _status == 'driver_arrived') ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _actionBusy ? null : _primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
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
            if (_status == 'in_progress') ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _actionBusy ? null : _requestCompletion,
                style: FilledButton.styleFrom(
                  backgroundColor: _danger,
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
                    : const Text(
                        'Finalizar viaje',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ],
            if (_status == 'arrival_reported') ...[
              const SizedBox(height: 12),
              if (_ride['completion_requested_by']?.toString() == 'driver')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Solicitaste finalizar. Esperando confirmación del pasajero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                  ),
                )
              else
                FilledButton(
                  onPressed: _actionBusy ? null : _showCompletionDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text(
                    'Revisar solicitud de finalización',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
            if (_status == 'accepted' ||
                _status == 'driver_en_route' ||
                _status == 'driver_arrived' ||
                _status == 'in_progress' ||
                _status == 'arrival_reported') ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _actionBusy ? null : _cancelTrip,
                style: TextButton.styleFrom(
                  foregroundColor: _danger,
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                  'Cancelar viaje',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            if (_status == 'cancelled') ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _actionBusy ? null : _primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  'Volver al inicio',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
            if (_status == 'completed') ...[
              const SizedBox(height: 15),
              FilledButton(
                onPressed: _actionBusy ? null : _primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
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
