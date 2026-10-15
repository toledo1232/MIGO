import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_session.dart';

class SearchingDriverScreen extends StatefulWidget {
  const SearchingDriverScreen({
    super.key,
    required this.offer,
    this.pickupText = 'Recogida no especificada',
    this.destinationText = 'Destino no especificado',
    this.paymentMethod = 'Efectivo',
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
  });

  final double offer;
  final String pickupText;
  final String destinationText;
  final String paymentMethod;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  late final AnimationController _pulseController;

  Timer? _messageTimer;
  Timer? _pollTimer;
  Timer? _wsReconnectTimer;
  WebSocket? _requestSocket;
  StreamSubscription<dynamic>? _requestSocketSubscription;

  String? _requestId;
  String _requestStatus = 'creating';

  String _statusMessage = 'Creando tu solicitud...';

  double? _driverOffer;
  double? _acceptedOffer;

  String? _driverName;
  String? _driverPhotoBase64;
  double? _driverRating;
  int? _driverTrips;
  String? _vehicleModel;
  String? _vehiclePlate;
  String? _vehicleColor;

  bool _networkBusy = false;
  bool _creationFailed = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _createRideRequest();

    _messageTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _requestStatus != 'searching') {
        return;
      }

      setState(() {
        _statusMessage =
            'Seguimos buscando. Te avisaremos cuando un conductor responda.';
      });
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _pollTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _requestSocketSubscription?.cancel();
    _requestSocket?.close();
    _pulseController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      final uri = Uri.parse('$_apiBaseUrl$path');

      final HttpClientRequest request;

      switch (method) {
        case 'POST':
          request = await client.postUrl(uri);
          break;
        case 'GET':
          request = await client.getUrl(uri);
          break;
        default:
          throw UnsupportedError('Método HTTP no soportado.');
      }

      request.headers.contentType = ContentType.json;

      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();

      final raw = await utf8.decoder.bind(response).join();

      Map<String, dynamic> decoded = {};

      if (raw.trim().isNotEmpty) {
        final value = jsonDecode(raw);

        if (value is Map<String, dynamic>) {
          decoded = value;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail =
            decoded['detail']?.toString() ?? 'HTTP ${response.statusCode}';

        throw HttpException(detail);
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _createRideRequest() async {
    if (_networkBusy) {
      return;
    }

    _networkBusy = true;

    if (mounted) {
      setState(() {
        _creationFailed = false;
        _requestStatus = 'creating';
        _statusMessage = 'Creando tu solicitud...';
      });
    }

    try {
      final data = await _requestJson(
        method: 'POST',
        path: '/ride-requests',
        body: {
          'offer': widget.offer,
          'pickup_text': widget.pickupText,
          'destination_text': widget.destinationText,
          'payment_method': widget.paymentMethod,
          'pickup_lat': widget.pickupLat,
          'pickup_lng': widget.pickupLng,
          'destination_lat': widget.destinationLat,
          'destination_lng': widget.destinationLng,
          'passenger_name':
              AppSession.current?.passengerName ?? 'Pasajero MIGO',
          'passenger_photo_base64': AppSession.current?.passengerPhotoBase64,
          'passenger_rating': AppSession.current?.passengerRating ?? 5.0,
          'passenger_trips': AppSession.current?.passengerTrips ?? 0,
        },
      );

      final id = data['id']?.toString();

      if (id == null || id.isEmpty) {
        throw const FormatException('FastAPI no devolvió el ID.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _requestId = id;
        _requestStatus = data['status']?.toString() ?? 'searching';
        _statusMessage = 'Enviando tu solicitud a conductores cercanos...';
      });

      _startPolling();
      _connectRequestRealtime(id);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _creationFailed = true;
        _requestStatus = 'error';
        _statusMessage =
            'No pudimos conectar con MIGO. Verifica que FastAPI esté encendido.';
      });
    } finally {
      _networkBusy = false;
    }
  }

  Future<void> _connectRequestRealtime(String requestId) async {
    await _requestSocketSubscription?.cancel();
    await _requestSocket?.close();

    _requestSocketSubscription = null;
    _requestSocket = null;

    try {
      final socket = await WebSocket.connect(
        'ws://10.0.2.2:8000/api/v1/ride-requests/ws/request/$requestId',
      ).timeout(const Duration(seconds: 6));

      if (!mounted || _requestId != requestId) {
        await socket.close();
        return;
      }

      _requestSocket = socket;

      _requestSocketSubscription = socket.listen(
        (raw) {
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
              _applyRideData(ride);
            }
          } catch (_) {
            // Se mantiene el polling como respaldo.
          }
        },
        onDone: () => _scheduleRequestReconnect(requestId),
        onError: (_) => _scheduleRequestReconnect(requestId),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRequestReconnect(requestId);
    }
  }

  void _scheduleRequestReconnect(String requestId) {
    _requestSocketSubscription = null;
    _requestSocket = null;

    if (!mounted ||
        _requestId != requestId ||
        _requestStatus == 'accepted' ||
        _requestStatus == 'cancelled') {
      return;
    }

    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(
      const Duration(seconds: 2),
      () => _connectRequestRealtime(requestId),
    );
  }

  void _applyRideData(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }

    final nextStatus = data['status']?.toString() ?? _requestStatus;

    final nextDriverOffer = (data['driver_offer'] as num?)?.toDouble();

    final nextAcceptedOffer = (data['offer'] as num?)?.toDouble();

    setState(() {
      _requestStatus = nextStatus;
      _driverOffer = nextDriverOffer;
      _driverName = data['driver_name']?.toString();
      _driverPhotoBase64 = data['driver_photo_base64']?.toString();
      _driverRating = (data['driver_rating'] as num?)?.toDouble();
      _driverTrips = (data['driver_trips'] as num?)?.toInt();
      _vehicleModel = data['vehicle_model']?.toString();
      _vehiclePlate = data['vehicle_plate']?.toString();
      _vehicleColor = data['vehicle_color']?.toString();

      switch (nextStatus) {
        case 'accepted':
          _acceptedOffer = nextAcceptedOffer;
          _statusMessage = '¡Un conductor aceptó tu viaje!';
          break;
        case 'counter_offer':
          _statusMessage = 'Un conductor te propone otro precio.';
          break;
        case 'cancelled':
          _statusMessage = 'La búsqueda fue cancelada.';
          break;
        default:
          _statusMessage = 'Enviando tu solicitud a conductores cercanos...';
      }
    });

    if (nextStatus == 'accepted' || nextStatus == 'cancelled') {
      _pollTimer?.cancel();
      _wsReconnectTimer?.cancel();
      _requestSocketSubscription?.cancel();
      _requestSocket?.close();
      _requestSocket = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshStatus(),
    );
  }

  Future<void> _refreshStatus() async {
    final requestId = _requestId;

    if (requestId == null || _networkBusy) {
      return;
    }

    _networkBusy = true;

    try {
      final data = await _requestJson(
        method: 'GET',
        path: '/ride-requests/$requestId',
      );

      _applyRideData(data);
    } catch (_) {
      // Un fallo temporal de polling no elimina
      // la solicitud activa.
    } finally {
      _networkBusy = false;
    }
  }

  Future<void> _acceptCounter() async {
    final requestId = _requestId;

    if (requestId == null || _networkBusy) {
      return;
    }

    _networkBusy = true;

    try {
      final data = await _requestJson(
        method: 'POST',
        path: '/ride-requests/$requestId/counter/accept',
      );

      if (!mounted) {
        return;
      }

      _applyRideData(data);

      if (mounted) {
        setState(() {
          _statusMessage = '¡Precio acordado! Tu conductor fue confirmado.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo aceptar: $error')));
    } finally {
      _networkBusy = false;
    }
  }

  Future<void> _rejectCounter() async {
    final requestId = _requestId;

    if (requestId == null || _networkBusy) {
      return;
    }

    _networkBusy = true;

    try {
      await _requestJson(
        method: 'POST',
        path: '/ride-requests/$requestId/counter/reject',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _requestStatus = 'searching';
        _driverOffer = null;
        _driverName = null;
        _driverPhotoBase64 = null;
        _driverRating = null;
        _driverTrips = null;
        _vehicleModel = null;
        _vehiclePlate = null;
        _vehicleColor = null;
        _statusMessage =
            'Contraoferta rechazada. Seguimos buscando conductores.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo rechazar: $error')));
    } finally {
      _networkBusy = false;
    }
  }

  Future<bool> _confirmCancel() async {
    if (_requestStatus == 'accepted') {
      return true;
    }

    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Cancelar búsqueda?'),
          content: const Text(
            'La solicitud dejará de buscar conductores cercanos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir buscando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancelar búsqueda'),
            ),
          ],
        );
      },
    );

    return cancel ?? false;
  }

  Future<void> _cancelAndReturn() async {
    if (_requestStatus == 'accepted') {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final shouldCancel = await _confirmCancel();

    if (!mounted || !shouldCancel) {
      return;
    }

    final requestId = _requestId;

    if (requestId != null) {
      try {
        await _requestJson(
          method: 'POST',
          path: '/ride-requests/$requestId/cancel',
        );
      } catch (_) {
        // No atrapamos al usuario si se corta
        // la red durante la cancelación.
      }
    }

    _pollTimer?.cancel();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching =
        _requestStatus == 'creating' || _requestStatus == 'searching';

    final accepted = _requestStatus == 'accepted';

    final counter = _requestStatus == 'counter_offer';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _cancelAndReturn();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FD),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F9FD),
          foregroundColor: _navy,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            accepted ? 'Conductor confirmado' : 'Buscando conductor',
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: accepted || counter ? 130 : 210,
                  height: accepted || counter ? 130 : 210,
                  child: searching
                      ? _searchingAnimation()
                      : _centerIcon(
                          accepted
                              ? Icons.check_rounded
                              : counter
                              ? Icons.currency_exchange_rounded
                              : _creationFailed
                              ? Icons.cloud_off_rounded
                              : Icons.local_taxi_rounded,
                          accepted
                              ? _turquoise
                              : counter
                              ? _blue
                              : _creationFailed
                              ? Colors.redAccent
                              : _blue,
                        ),
                ),
                const SizedBox(height: 30),
                Text(
                  accepted
                      ? '¡Viaje aceptado!'
                      : counter
                      ? 'Nueva propuesta'
                      : _creationFailed
                      ? 'No se pudo iniciar la búsqueda'
                      : 'Buscando conductores cercanos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _creationFailed
                        ? Colors.redAccent
                        : const Color(0xFF748096),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                if (_creationFailed) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _networkBusy ? null : _createRideRequest,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
                const SizedBox(height: 20),
                if (counter) _counterCard() else _offerCard(),
                if ((accepted || counter) && _driverName != null) ...[
                  const SizedBox(height: 12),
                  _driverProfileCard(),
                ],
                const Spacer(),
                if (!accepted)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF748096),
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'MIGO te avisará cuando un conductor responda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF748096),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),

                if (accepted)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: _cancelAndReturn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: Color(0xFFC9D5EA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Cancelar búsqueda',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _driverProfileCard() {
    final name = _driverName ?? 'Conductor MIGO';
    final rating = _driverRating ?? 5.0;
    final trips = _driverTrips ?? 0;

    Widget avatar;

    if (_driverPhotoBase64 != null && _driverPhotoBase64!.isNotEmpty) {
      try {
        avatar = CircleAvatar(
          radius: 27,
          backgroundColor: const Color(0xFFEAF0FF),
          backgroundImage: MemoryImage(base64Decode(_driverPhotoBase64!)),
        );
      } catch (_) {
        avatar = _driverFallbackAvatar(name);
      }
    } else {
      avatar = _driverFallbackAvatar(name);
    }

    final vehicleParts = <String>[
      if (_vehicleModel != null) _vehicleModel!,
      if (_vehicleColor != null) _vehicleColor!,
      if (_vehiclePlate != null) _vehiclePlate!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9F7)),
      ),
      child: Row(
        children: [
          avatar,
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
                if (vehicleParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    vehicleParts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF748096),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: _turquoise),
        ],
      ),
    );
  }

  Widget _driverFallbackAvatar(String name) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _counterCard() {
    final amount = _driverOffer ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFD0FF), width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'El conductor propone',
            style: TextStyle(color: Color(0xFF748096), fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'S/ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _navy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _networkBusy ? null : _rejectCounter,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _networkBusy ? null : _acceptCounter,
                  child: Text('Aceptar S/ ${amount.toStringAsFixed(2)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offerCard() {
    final amount = _acceptedOffer ?? widget.offer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E9F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.sell_rounded, color: _blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              accepted ? 'Precio acordado' : 'Tu oferta',
              style: const TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            'S/ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  bool get accepted => _requestStatus == 'accepted';

  Widget _searchingAnimation() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final p1 = _pulseController.value;
        final p2 = (p1 + 0.50) % 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.70 + (p1 * 0.55),
              child: Opacity(
                opacity: (1 - p1) * 0.40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: _turquoise,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.70 + (p2 * 0.55),
              child: Opacity(
                opacity: (1 - p2) * 0.32,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            _centerIcon(Icons.local_taxi_rounded, _blue),
          ],
        );
      },
    );
  }

  Widget _centerIcon(IconData icon, Color iconColor) {
    return Center(
      child: Container(
        width: 94,
        height: 94,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              offset: const Offset(0, 8),
              color: Colors.black.withValues(alpha: 0.10),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 48),
      ),
    );
  }
}
