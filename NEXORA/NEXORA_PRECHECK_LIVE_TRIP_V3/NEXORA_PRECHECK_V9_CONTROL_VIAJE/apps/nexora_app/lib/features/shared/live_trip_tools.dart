import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'live_trip_support.dart';

class LiveTripMarkerFactory {
  const LiveTripMarkerFactory._();

  static Future<BitmapDescriptor> carMarker() async {
    const size = 144;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(center, 62, Paint()..color = Colors.white);

    canvas.drawCircle(center, 58, Paint()..color = const Color(0xFF0B1F3A));

    final bodyPaint = Paint()..color = const Color(0xFF35D0A0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 57, 72, 42),
        const Radius.circular(15),
      ),
      bodyPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(49, 40, 46, 31),
        const Radius.circular(12),
      ),
      bodyPaint,
    );

    final glassPaint = Paint()..color = const Color(0xFFE9FFF8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 47, 32, 18),
        const Radius.circular(6),
      ),
      glassPaint,
    );

    final wheelPaint = Paint()..color = const Color(0xFF17202A);

    canvas.drawCircle(const Offset(50, 101), 10, wheelPaint);
    canvas.drawCircle(const Offset(94, 101), 10, wheelPaint);

    canvas.drawCircle(const Offset(50, 101), 4, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(94, 101), 4, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

    if (data == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: 54,
      height: 54,
    );
  }

  static Future<BitmapDescriptor> profileMarker({
    required String name,
    String? base64Photo,
  }) async {
    const size = 144;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(center, 64, Paint()..color = Colors.white);

    canvas.drawCircle(center, 58, Paint()..color = const Color(0xFF35D0A0));

    final photo = base64Photo;

    if (photo != null && photo.isNotEmpty) {
      try {
        final bytes = base64Decode(photo);
        final codec = await ui.instantiateImageCodec(
          Uint8List.fromList(bytes),
          targetWidth: 116,
          targetHeight: 116,
        );
        final frame = await codec.getNextFrame();

        canvas.save();
        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: 53)),
        );

        paintImage(
          canvas: canvas,
          rect: const Rect.fromLTWH(19, 19, 106, 106),
          image: frame.image,
          fit: BoxFit.cover,
        );

        canvas.restore();
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        _paintInitial(canvas, name, center);
      }
    } else {
      _paintInitial(canvas, name, center);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

    if (data == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: 54,
      height: 54,
    );
  }

  static void _paintInitial(Canvas canvas, String name, Offset center) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    final painter = TextPainter(
      text: TextSpan(
        text: initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 54,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}

class LiveTripChatSheet extends StatefulWidget {
  const LiveTripChatSheet({
    required this.requestId,
    required this.actor,
    required this.otherName,
    super.key,
  });

  final String requestId;
  final String actor;
  final String otherName;

  @override
  State<LiveTripChatSheet> createState() => _LiveTripChatSheetState();
}

class _LiveTripChatSheetState extends State<LiveTripChatSheet> {
  static const _navy = Color(0xFF0B1F3A);
  static const _blue = Color(0xFF2557FF);

  final TextEditingController _controller = TextEditingController();

  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  String? _error;

  List<String> get _quickMessages {
    if (widget.actor == 'driver') {
      return const [
        'Ya estoy en camino',
        'Llegué a tu ubicación',
        'En 5 minutos estoy llegando',
        'Hay tráfico',
        '¿Dónde te encuentras?',
      ];
    }

    return const [
      'Hola',
      '¿Ya llegaste?',
      'Ya estoy saliendo',
      'Espérame un momento',
      '¿Tienes espacio para una maleta?',
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await LiveTripApi.getMessages(widget.requestId);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _sendText(String rawText, {bool clearComposer = false}) async {
    final text = rawText.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await LiveTripApi.sendMessage(
        widget.requestId,
        actor: widget.actor,
        text: text,
      );

      if (clearComposer) {
        _controller.clear();
      }

      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _send() async {
    await _sendText(_controller.text, clearComposer: true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D9E3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, color: _blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mensajes con ${widget.otherName}',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFD92D20),
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];
                  final own = message['actor']?.toString() == widget.actor;

                  return Align(
                    alignment: own
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 290),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: own ? _blue : const Color(0xFFF0F3F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message['text']?.toString() ?? '',
                        style: TextStyle(
                          color: own ? Colors.white : _navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final message = _quickMessages[index];

                    return ActionChip(
                      onPressed: _sending ? null : () => _sendText(message),
                      avatar: const Icon(
                        Icons.bolt_rounded,
                        size: 17,
                        color: _blue,
                      ),
                      label: Text(message, maxLines: 1),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 500,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Escribe un mensaje...',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripCancellationChoice {
  const TripCancellationChoice({
    required this.reason,
    required this.label,
    this.details,
  });

  final String reason;
  final String label;
  final String? details;
}

Future<TripCancellationChoice?> showTripCancellationSheet(
  BuildContext context, {
  required String actor,
}) async {
  final reasons = actor == 'driver'
      ? const <MapEntry<String, String>>[
          MapEntry('passenger_no_show', 'El pasajero no aparece'),
          MapEntry('passenger_delay', 'El pasajero está demorando demasiado'),
          MapEntry('unsafe_pickup', 'El punto de recojo no es seguro'),
          MapEntry('passenger_behavior', 'Problema con el pasajero'),
          MapEntry('vehicle_problem', 'Problema con el vehículo'),
          MapEntry('emergency', 'Emergencia'),
          MapEntry('other', 'Otro motivo'),
        ]
      : const <MapEntry<String, String>>[
          MapEntry('driver_delay', 'El conductor está demorando demasiado'),
          MapEntry('change_of_plans', 'Cambió mi plan'),
          MapEntry('wrong_pickup', 'Elegí mal el punto de recojo'),
          MapEntry('driver_behavior', 'Problema con el conductor'),
          MapEntry('safety', 'Me siento inseguro/a'),
          MapEntry('emergency', 'Emergencia'),
          MapEntry('other', 'Otro motivo'),
        ];

  return showModalBottomSheet<TripCancellationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      var selected = reasons.first.key;
      final controller = TextEditingController();

      return StatefulBuilder(
        builder: (context, setModalState) {
          final selectedLabel = reasons
              .firstWhere((entry) => entry.key == selected)
              .value;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4D9E3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Cancelar viaje',
                    style: TextStyle(
                      color: Color(0xFF0B1F3A),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona el motivo. MIGO conservará esta información '
                    'para seguridad y revisión administrativa.',
                    style: TextStyle(color: Color(0xFF748096), height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map(
                    (entry) => RadioListTile<String>(
                      value: entry.key,
                      groupValue: selected,
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            selected = value;
                          });
                        }
                      },
                      title: Text(entry.value),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Cuéntanos qué pasó (opcional)',
                      hintText: 'Puedes escribir detalles para revisión.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Si el viaje ya había iniciado, los créditos no se '
                      'resolverán a ciegas: el caso quedará para revisión.',
                      style: TextStyle(
                        color: Color(0xFF0B1F3A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(
                        TripCancellationChoice(
                          reason: selected,
                          label: selectedLabel,
                          details: controller.text.trim().isEmpty
                              ? null
                              : controller.text.trim(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD92D20),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text(
                      'Confirmar cancelación',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Mantener viaje'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class HoldSosButton extends StatefulWidget {
  const HoldSosButton({required this.onTriggered, super.key});

  final Future<void> Function() onTriggered;

  @override
  State<HoldSosButton> createState() => _HoldSosButtonState();
}

class _HoldSosButtonState extends State<HoldSosButton> {
  Timer? _timer;
  bool _holding = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();

    setState(() {
      _holding = true;
    });

    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _holding = false;
      });

      await widget.onTriggered();
    });
  }

  void _cancel() {
    _timer?.cancel();

    if (mounted && _holding) {
      setState(() {
        _holding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _holding ? const Color(0xFFB42318) : const Color(0xFFD92D20),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sos_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPrivateCallNotice(
  BuildContext context, {
  required String otherName,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.call_rounded),
            SizedBox(width: 8),
            Text('Llamada privada'),
          ],
        ),
        content: Text(
          'El botón de llamada para $otherName ya queda dentro del viaje. '
          'La voz real se habilitará con un proveedor de llamadas '
          'enmascaradas para que ninguno vea el número personal del otro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}
