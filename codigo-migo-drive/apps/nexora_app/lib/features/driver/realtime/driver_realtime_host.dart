import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_session.dart';
import '../live_trip/driver_live_trip_screen.dart';

class DriverRealtimeHost extends StatefulWidget {
  const DriverRealtimeHost({
    required this.session,
    required this.child,
    super.key,
  });

  final AppSession session;
  final Widget child;

  @override
  State<DriverRealtimeHost> createState() => _DriverRealtimeHostState();
}

class _DriverRealtimeHostState extends State<DriverRealtimeHost> {
  static const _blue = Color(0xFF2557FF);
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const _wsUrl = 'ws://10.0.2.2:8000/api/v1/ride-requests/ws/drivers';

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;

  final List<Map<String, dynamic>> _queue = [];
  final Set<String> _dismissed = {};

  Map<String, dynamic>? _activeRide;
  bool _connecting = false;
  bool _actionBusy = false;
  String? _liveTripId;

  bool get _shouldConnect =>
      widget.session.mode == AppMode.driver &&
      widget.session.driverOnline &&
      widget.session.hasDriverPhoto;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncConnection();
    });
  }

  @override
  void didUpdateWidget(covariant DriverRealtimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_sessionChanged);
      widget.session.addListener(_sessionChanged);
      _syncConnection();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    super.dispose();
  }

  void _sessionChanged() {
    _syncConnection();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncConnection() async {
    if (!_shouldConnect) {
      _reconnectTimer?.cancel();
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      await _socket?.close();
      _socket = null;

      if (mounted) {
        setState(() {
          _activeRide = null;
          _queue.clear();
        });
      }
      return;
    }

    if (_socket != null || _connecting) {
      return;
    }

    await _connect();
  }

  Future<void> _connect() async {
    if (!_shouldConnect || _connecting) {
      return;
    }

    _connecting = true;

    try {
      final socket = await WebSocket.connect(
        _wsUrl,
      ).timeout(const Duration(seconds: 6));

      if (!mounted || !_shouldConnect) {
        await socket.close();
        return;
      }

      _socket = socket;

      _socketSubscription = socket.listen(
        _handleSocketMessage,
        onDone: _socketClosed,
        onError: (_) => _socketClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _socketClosed() {
    _socketSubscription = null;
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldConnect || !mounted) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _connect);
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final event = decoded['event']?.toString();

      switch (event) {
        case 'pending_snapshot':
          final rides = decoded['rides'];

          if (rides is List) {
            final pending = <Map<String, dynamic>>[];

            for (final item in rides) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString();

                if (id != null &&
                    !_dismissed.contains(id) &&
                    item['status']?.toString() == 'searching') {
                  pending.add(item);
                }
              }
            }

            _replaceQueue(pending);
          }
          break;

        case 'ride_created':
          final ride = decoded['ride'];

          if (ride is Map<String, dynamic>) {
            _addRide(ride);
          }
          break;

        case 'ride_removed':
          final requestId = decoded['request_id']?.toString();
          final reason = decoded['reason']?.toString();
          final ride = decoded['ride'];

          if (requestId != null) {
            _removeRide(
              requestId,
              showReason: reason != 'accepted',
              reason: reason,
            );
          }

          if (reason == 'accepted' &&
              ride is Map<String, dynamic> &&
              _isOwnAcceptedRide(ride)) {
            unawaited(_openLiveTrip(ride));
          }
          break;

        case 'ride_updated':
          final ride = decoded['ride'];

          if (ride is Map<String, dynamic>) {
            final id = ride['id']?.toString();
            final status = ride['status']?.toString();

            if (id == null) {
              return;
            }

            if (status == 'searching') {
              _addRide(ride);
            } else {
              _removeRide(id);
            }
          }
          break;
      }
    } catch (_) {
      // Mensaje no válido: se ignora sin romper la experiencia del conductor.
    }
  }

  void _replaceQueue(List<Map<String, dynamic>> pending) {
    if (!mounted) {
      return;
    }

    setState(() {
      final activeId = _activeRide?['id']?.toString();

      _queue
        ..clear()
        ..addAll(pending.where((ride) => ride['id']?.toString() != activeId));

      if (_activeRide != null) {
        final stillPending = pending.any(
          (ride) => ride['id']?.toString() == activeId,
        );

        if (!stillPending) {
          _activeRide = null;
        }
      }

      _showNextIfNeeded();
    });
  }

  void _addRide(Map<String, dynamic> ride) {
    final id = ride['id']?.toString();

    if (id == null ||
        id.isEmpty ||
        _dismissed.contains(id) ||
        ride['status']?.toString() != 'searching') {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (_activeRide?['id']?.toString() == id) {
        _activeRide = ride;
        return;
      }

      final index = _queue.indexWhere((item) => item['id']?.toString() == id);

      if (index >= 0) {
        _queue[index] = ride;
      } else {
        _queue.add(ride);
      }

      _showNextIfNeeded();
    });
  }

  void _showNextIfNeeded() {
    if (_activeRide != null || _queue.isEmpty) {
      return;
    }

    _activeRide = _queue.removeAt(0);
  }

  void _removeRide(
    String requestId, {
    bool showReason = false,
    String? reason,
  }) {
    if (!mounted) {
      return;
    }

    final wasActive = _activeRide?['id']?.toString() == requestId;

    setState(() {
      _queue.removeWhere((item) => item['id']?.toString() == requestId);

      if (wasActive) {
        _activeRide = null;
        _showNextIfNeeded();
      }
    });

    if (wasActive && showReason) {
      final message = switch (reason) {
        'cancelled' => 'El pasajero canceló esta solicitud.',
        'accepted' => 'La solicitud ya fue aceptada.',
        'counter_offer' =>
          'La solicitud está esperando respuesta del pasajero.',
        _ => 'La solicitud ya no está disponible.',
      };

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool _isOwnAcceptedRide(Map<String, dynamic> ride) {
    final ridePhoto = ride['driver_photo_base64']?.toString();
    final sessionPhoto = widget.session.driverPhotoBase64;

    if (ride['status']?.toString() != 'accepted' ||
        ridePhoto == null ||
        sessionPhoto == null) {
      return false;
    }

    return ridePhoto == sessionPhoto &&
        ride['driver_name']?.toString() == widget.session.driverName;
  }

  Future<void> _openLiveTrip(Map<String, dynamic> ride) async {
    final id = ride['id']?.toString();

    if (id == null || id.isEmpty || !mounted || _liveTripId == id) {
      return;
    }

    _liveTripId = id;

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DriverLiveTripScreen(
            session: widget.session,
            initialRide: Map<String, dynamic>.from(ride),
          ),
        ),
      );
    } finally {
      if (_liveTripId == id) {
        _liveTripId = null;
      }
    }
  }

  Map<String, dynamic> _driverProfilePayload() {
    return {
      'driver_name': widget.session.driverName,
      'driver_photo_base64': widget.session.driverPhotoBase64,
      'driver_rating': widget.session.driverRating,
      'driver_trips': widget.session.driverTrips,
      'vehicle_model': widget.session.driverVehicle,
      'vehicle_plate': widget.session.driverPlate,
      'vehicle_color': widget.session.driverColor,
    };
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.postUrl(Uri.parse('$_apiBaseUrl$path'));

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
        throw HttpException(
          decoded['detail']?.toString() ?? 'HTTP ${response.statusCode}',
        );
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _acceptRide() async {
    final ride = _activeRide;
    final id = ride?['id']?.toString();

    if (id == null || _actionBusy) {
      return;
    }

    if (!widget.session.hasDriverPhoto) {
      _showMessage('Tu foto de conductor es obligatoria para aceptar viajes.');
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final acceptedRide = await _post(
        '/ride-requests/$id/accept',
        body: _driverProfilePayload(),
      );

      _removeRide(id);
      _showMessage('Viaje aceptado. Abriendo navegación.');

      if (mounted) {
        await _openLiveTrip(acceptedRide);
      }
    } catch (error) {
      _removeRide(id);
      _showMessage('No se pudo aceptar: $error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _counterOffer() async {
    final ride = _activeRide;
    final id = ride?['id']?.toString();
    final currentOffer = (ride?['offer'] as num?)?.toDouble() ?? 0;

    if (id == null || _actionBusy) {
      return;
    }

    if (!widget.session.hasDriverPhoto) {
      _showMessage(
        'Tu foto de conductor es obligatoria para proponer tarifas.',
      );
      return;
    }

    var typed = (currentOffer + 1).toStringAsFixed(2);
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Proponer otro precio'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: typed,
              autofocus: true,
              selectAllOnFocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tu propuesta',
                prefixText: 'S/ ',
                hintText: 'Ej. 23',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                typed = value;
              },
              validator: (value) {
                final parsed = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );

                if (parsed == null) {
                  return 'Escribe un precio válido.';
                }

                if (parsed < 3 || parsed > 500) {
                  return 'Usa un monto entre S/ 3 y S/ 500.';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                final parsed = double.tryParse(
                  typed.trim().replaceAll(',', '.'),
                );

                if (parsed != null) {
                  Navigator.pop(dialogContext, parsed);
                }
              },
              child: const Text('Enviar propuesta'),
            ),
          ],
        );
      },
    );

    if (amount == null || !mounted) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      await _post(
        '/ride-requests/$id/counter',
        body: {..._driverProfilePayload(), 'offer': amount},
      );

      _removeRide(id);
      _showMessage('Propuesta S/ ${amount.toStringAsFixed(2)} enviada.');
    } catch (error) {
      _removeRide(id);
      _showMessage('No se pudo enviar la propuesta: $error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _rejectRide() {
    final id = _activeRide?['id']?.toString();

    if (id == null) {
      return;
    }

    _dismissed.add(id);
    _removeRide(id);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _avatar(String? base64Photo, String name) {
    if (base64Photo != null && base64Photo.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Photo);

        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(bytes),
          backgroundColor: const Color(0xFFEAF0FF),
        );
      } catch (_) {
        // Se usa inicial si la imagen no puede decodificarse.
      }
    }

    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = _activeRide;

    return Stack(
      children: [
        widget.child,
        if (_shouldConnect && ride != null)
          Positioned.fill(
            child: Material(
              color: const Color(0x99000000),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: _IncomingRideCard(
                      ride: ride,
                      actionBusy: _actionBusy,
                      avatarBuilder: _avatar,
                      onAccept: _acceptRide,
                      onCounter: _counterOffer,
                      onReject: _rejectRide,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingRideCard extends StatelessWidget {
  const _IncomingRideCard({
    required this.ride,
    required this.actionBusy,
    required this.avatarBuilder,
    required this.onAccept,
    required this.onCounter,
    required this.onReject,
  });

  final Map<String, dynamic> ride;
  final bool actionBusy;
  final Widget Function(String?, String) avatarBuilder;
  final VoidCallback onAccept;
  final VoidCallback onCounter;
  final VoidCallback onReject;

  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);

  @override
  Widget build(BuildContext context) {
    final offer = (ride['offer'] as num?)?.toDouble() ?? 0;
    final passengerName = ride['passenger_name']?.toString() ?? 'Pasajero MIGO';
    final passengerPhoto = ride['passenger_photo_base64']?.toString();
    final passengerRating = (ride['passenger_rating'] as num?)?.toDouble() ?? 5;
    final passengerTrips = (ride['passenger_trips'] as num?)?.toInt() ?? 0;

    final pickup =
        ride['pickup_text']?.toString() ?? 'Recogida no especificada';
    final destination =
        ride['destination_text']?.toString() ?? 'Destino no especificado';
    final payment = ride['payment_method']?.toString() ?? 'Efectivo';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FBF5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: _turquoise,
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'NUEVA SOLICITUD',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'S/ ${offer.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              avatarBuilder(passengerPhoto, passengerName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '★ ${passengerRating.toStringAsFixed(1)} · '
                      '$passengerTrips viajes',
                      style: const TextStyle(
                        color: Color(0xFF748096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _RouteLine(color: _turquoise, label: 'Recogida', value: pickup),
          const SizedBox(height: 12),
          _RouteLine(color: _blue, label: 'Destino', value: destination),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: _blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Pago',
                  style: TextStyle(
                    color: Color(0xFF748096),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  payment,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: actionBusy ? null : onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Aceptar S/ ${offer.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: actionBusy ? null : onCounter,
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Proponer otro precio',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(
            onPressed: actionBusy ? null : onReject,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('Rechazar esta solicitud'),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_rounded, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF748096),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF0B1F3A),
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
