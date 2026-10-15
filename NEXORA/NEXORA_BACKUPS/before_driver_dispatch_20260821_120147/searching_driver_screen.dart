import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class SearchingDriverScreen extends StatefulWidget {
  const SearchingDriverScreen({super.key, required this.offer});

  final double offer;

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);

  // Android Emulator -> PC host.
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  late final AnimationController _pulseController;

  Timer? _messageTimer;
  Timer? _pollTimer;

  String? _requestId;
  String _requestStatus = 'creating';

  String _statusMessage = 'Creando tu solicitud...';

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
        body: {'offer': widget.offer},
      );

      final id = data['id']?.toString();
      final status = data['status']?.toString();

      if (id == null || id.isEmpty) {
        throw const FormatException(
          'FastAPI no devolvió el ID de la solicitud.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _requestId = id;
        _requestStatus = status ?? 'searching';
        _statusMessage = 'Enviando tu solicitud a conductores cercanos...';
      });

      _startPolling();
    } catch (error) {
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

      final nextStatus = data['status']?.toString() ?? _requestStatus;

      if (!mounted) {
        return;
      }

      if (nextStatus != _requestStatus) {
        setState(() {
          _requestStatus = nextStatus;

          switch (nextStatus) {
            case 'accepted':
              _statusMessage = '¡Un conductor aceptó tu solicitud!';
              break;
            case 'cancelled':
              _statusMessage = 'La búsqueda fue cancelada.';
              break;
            default:
              _statusMessage =
                  'Enviando tu solicitud a conductores cercanos...';
          }
        });
      }

      if (nextStatus != 'searching') {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Un fallo temporal de polling no elimina la solicitud.
      // Se intentará nuevamente en el siguiente ciclo.
    } finally {
      _networkBusy = false;
    }
  }

  Future<bool> _confirmCancel() async {
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
        // La navegación no debe quedar atrapada si la red se corta.
      }
    }

    _pollTimer?.cancel();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final searching =
        _requestStatus == 'creating' || _requestStatus == 'searching';

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
          title: const Text(
            'Buscando conductor',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 210,
                  height: 210,
                  child: searching
                      ? AnimatedBuilder(
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
                        )
                      : _centerIcon(
                          _creationFailed
                              ? Icons.cloud_off_rounded
                              : Icons.local_taxi_rounded,
                          _creationFailed ? Colors.redAccent : _blue,
                        ),
                ),
                const SizedBox(height: 30),
                Text(
                  _creationFailed
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _creationFailed
                          ? Colors.redAccent
                          : const Color(0xFF748096),
                      fontSize: 15,
                      height: 1.35,
                    ),
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
                const SizedBox(height: 28),
                Container(
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
                      const Expanded(
                        child: Text(
                          'Tu oferta',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'S/ ${widget.offer.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_requestId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Solicitud MIGO activa',
                    style: TextStyle(
                      color: _navy.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
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
