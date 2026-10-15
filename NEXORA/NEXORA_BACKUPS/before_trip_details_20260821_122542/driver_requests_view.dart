import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class DriverRequestsView extends StatefulWidget {
  const DriverRequestsView({super.key});

  @override
  State<DriverRequestsView> createState() => _DriverRequestsViewState();
}

class _DriverRequestsViewState extends State<DriverRequestsView> {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);
  static const _turquoise = Color(0xFF35D0A0);
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  Timer? _timer;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPending();

    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadPending(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<dynamic> _requestJson({
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

      dynamic decoded;

      if (raw.trim().isEmpty) {
        decoded = null;
      } else {
        decoded = jsonDecode(raw);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        var detail = 'HTTP ${response.statusCode}';

        if (decoded is Map<String, dynamic>) {
          detail = decoded['detail']?.toString() ?? detail;
        }

        throw HttpException(detail);
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadPending({bool silent = false}) async {
    if (_busy) {
      return;
    }

    _busy = true;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _requestJson(
        method: 'GET',
        path: '/ride-requests/pending',
      );

      final items = <Map<String, dynamic>>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'No pudimos conectar con MIGO. Verifica que FastAPI esté encendido.';
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _accept(Map<String, dynamic> request) async {
    final id = request['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    try {
      await _requestJson(method: 'POST', path: '/ride-requests/$id/accept');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud aceptada. El pasajero será notificado.'),
        ),
      );

      await _loadPending();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo aceptar: $error')));
    }
  }

  Future<void> _counter(Map<String, dynamic> request) async {
    final id = request['id']?.toString();
    final currentOffer = (request['offer'] as num?)?.toDouble() ?? 0;

    if (id == null || id.isEmpty) {
      return;
    }

    var typedPrice = (currentOffer + 1).toStringAsFixed(2);

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Proponer otro precio'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: typedPrice,
              autofocus: true,
              selectAllOnFocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tu propuesta',
                prefixText: 'S/ ',
                hintText: 'Ej. 17',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                typedPrice = value;
              },
              validator: (value) {
                final normalized = (value ?? '').trim().replaceAll(',', '.');

                final parsed = double.tryParse(normalized);

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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                final normalized = typedPrice.trim().replaceAll(',', '.');

                final parsed = double.tryParse(normalized);

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

    if (result == null || !mounted) {
      return;
    }

    try {
      await _requestJson(
        method: 'POST',
        path: '/ride-requests/$id/counter',
        body: {'offer': result},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Propuesta S/ ${result.toStringAsFixed(2)} enviada.'),
        ),
      );

      await _loadPending();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la propuesta: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 54,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadPending,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        children: [
          const Text(
            'Solicitudes cercanas',
            style: TextStyle(
              color: _navy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aquí aparecerán pasajeros que están buscando conductor.',
            style: TextStyle(color: Color(0xFF748096), height: 1.35),
          ),
          const SizedBox(height: 20),
          if (_requests.isEmpty)
            _emptyState()
          else
            ..._requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E9F7)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 54, color: Color(0xFF9AA6BA)),
          SizedBox(height: 14),
          Text(
            'No hay solicitudes nuevas',
            style: TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'MIGO actualizará esta pantalla automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF748096)),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final offer = (request['offer'] as num?)?.toDouble() ?? 0;

    final id = request['id']?.toString() ?? '';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9FFF8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_pin_circle_outlined,
                  color: _turquoise,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva solicitud',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pasajero cercano',
                      style: TextStyle(color: Color(0xFF748096)),
                    ),
                  ],
                ),
              ),
              Text(
                'S/ ${offer.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Solicitud #$shortId',
            style: const TextStyle(color: Color(0xFF748096), fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _counter(request),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              'Proponer otro precio',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 9),
          FilledButton(
            onPressed: () => _accept(request),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              'Aceptar S/ ${offer.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
