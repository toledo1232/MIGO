import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'live_trip_support.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  static const _danger = Color(0xFFD92D20);

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _timer;
  StreamSubscription<void>? _playerCompleteSubscription;
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  bool _recording = false;
  DateTime? _recordStartedAt;
  String? _playingMessageId;
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

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingMessageId = null;
        });
      }
    });

    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerCompleteSubscription?.cancel();
    _controller.dispose();
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
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
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
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

  Future<void> _pickPhoto() async {
    if (_sending || _recording) {
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 68,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();

      if (bytes.length > 1500000) {
        if (mounted) {
          setState(() {
            _error = 'La foto es demasiado grande.';
          });
        }
        return;
      }

      final lowerName = picked.name.toLowerCase();
      final mime = lowerName.endsWith('.png')
          ? 'image/png'
          : lowerName.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      setState(() {
        _sending = true;
      });

      await LiveTripApi.sendMessage(
        widget.requestId,
        actor: widget.actor,
        kind: 'image',
        text: 'Foto',
        mediaBase64: base64Encode(bytes),
        mediaMime: mime,
      );

      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo enviar la foto. $error';
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

  Future<void> _toggleRecording() async {
    if (_sending) {
      return;
    }

    if (_recording) {
      await _finishRecording();
      return;
    }

    try {
      final allowed = await _recorder.hasPermission();

      if (!allowed) {
        if (mounted) {
          setState(() {
            _error = 'MIGO necesita permiso de micrófono para enviar audio.';
          });
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/migo_audio_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (mounted) {
        setState(() {
          _recording = true;
          _recordStartedAt = DateTime.now();
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo iniciar la grabación. $error';
        });
      }
    }
  }

  Future<void> _finishRecording() async {
    final startedAt = _recordStartedAt;

    try {
      final path = await _recorder.stop();

      if (mounted) {
        setState(() {
          _recording = false;
        });
      }

      if (path == null || startedAt == null) {
        return;
      }

      final duration = DateTime.now().difference(startedAt);

      if (duration.inMilliseconds < 500) {
        if (mounted) {
          setState(() {
            _error = 'Graba por lo menos medio segundo.';
          });
        }
        return;
      }

      if (duration > const Duration(seconds: 60)) {
        if (mounted) {
          setState(() {
            _error = 'La nota de voz puede durar hasta 60 segundos.';
          });
        }
        return;
      }

      final file = File(path);

      if (!await file.exists()) {
        throw const FileSystemException('No se encontró el audio grabado.');
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > 1500000) {
        if (mounted) {
          setState(() {
            _error = 'La nota de voz es demasiado grande.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _sending = true;
        });
      }

      await LiveTripApi.sendMessage(
        widget.requestId,
        actor: widget.actor,
        kind: 'audio',
        text: 'Nota de voz',
        mediaBase64: base64Encode(bytes),
        mediaMime: 'audio/mp4',
        durationMs: duration.inMilliseconds,
      );

      try {
        await file.delete();
      } catch (_) {}

      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo enviar la nota de voz. $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _sending = false;
          _recordStartedAt = null;
        });
      }
    }
  }

  Future<void> _playAudio(Map<String, dynamic> message) async {
    final id = message['id']?.toString();
    final raw = message['media_base64']?.toString();

    if (id == null || raw == null || raw.isEmpty) {
      return;
    }

    try {
      if (_playingMessageId == id) {
        await _audioPlayer.stop();

        if (mounted) {
          setState(() {
            _playingMessageId = null;
          });
        }
        return;
      }

      final bytes = base64Decode(raw);

      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));

      if (mounted) {
        setState(() {
          _playingMessageId = id;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo reproducir el audio. $error';
        });
      }
    }
  }

  Widget _messageBody(Map<String, dynamic> message, {required bool own}) {
    final kind = message['kind']?.toString() ?? 'text';
    final text = message['text']?.toString() ?? '';

    if (kind == 'image') {
      final raw = message['media_base64']?.toString();

      if (raw == null || raw.isEmpty) {
        return const Text('Foto no disponible');
      }

      try {
        final bytes = base64Decode(raw);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        return Text(
          'Foto no disponible',
          style: TextStyle(color: own ? Colors.white : _navy),
        );
      }
    }

    if (kind == 'audio') {
      final durationMs = (message['duration_ms'] as num?)?.toInt() ?? 0;
      final seconds = (durationMs / 1000).ceil();
      final id = message['id']?.toString();
      final playing = id != null && id == _playingMessageId;

      return InkWell(
        onTap: () => _playAudio(message),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: own ? Colors.white : _blue,
              size: 31,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.graphic_eq_rounded,
              color: own
                  ? Colors.white.withValues(alpha: 0.9)
                  : _navy.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              '${seconds}s',
              style: TextStyle(
                color: own ? Colors.white : _navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: own ? Colors.white : _navy,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
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
            if (_recording)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic_rounded, color: _danger),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Grabando… toca el micrófono otra vez para enviar.',
                        style: TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: _danger, fontSize: 12),
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
                      child: _messageBody(message, own: own),
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final message = _quickMessages[index];

                    return ActionChip(
                      onPressed: _sending || _recording
                          ? null
                          : () => _sendText(message),
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
                8,
                8,
                8,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Enviar foto',
                    onPressed: _sending || _recording ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library_rounded, color: _blue),
                  ),
                  IconButton(
                    tooltip: _recording ? 'Enviar audio' : 'Grabar audio',
                    onPressed: _sending ? null : _toggleRecording,
                    icon: Icon(
                      _recording
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                      color: _recording ? _danger : _blue,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_recording,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 500,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _recording
                            ? 'Grabando audio…'
                            : 'Escribe un mensaje...',
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
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Enviar mensaje',
                    onPressed: _sending || _recording ? null : _send,
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

String _migoCancellationStageMessage(String? tripStatus) {
  if (tripStatus == 'searching' || tripStatus == 'counter_offer') {
    return 'Toda cancelación queda registrada para revisión '
        'administrativa. En esta etapa todavía no hay créditos '
        'de un conductor asignado que resolver.';
  }

  if (tripStatus == 'accepted' ||
      tripStatus == 'driver_en_route' ||
      tripStatus == 'driver_arrived') {
    return 'La cancelación será revisada por MIGO. Los créditos '
        'reservados del conductor NO se liberarán automáticamente: '
        'quedarán retenidos hasta que el administrador decida.';
  }

  if (tripStatus == 'in_progress' || tripStatus == 'arrival_reported') {
    return 'El viaje ya inició. La cancelación quedará en revisión '
        'administrativa y MIGO no liberará ni consumirá créditos '
        'automáticamente.';
  }

  return 'Toda cancelación queda registrada y pendiente de revisión '
      'administrativa. Ninguna decisión sobre créditos será automática.';
}

Future<TripCancellationChoice?> showTripCancellationSheet(
  BuildContext context, {
  required String actor,
  String? tripStatus,
}) async {
  final reasons = actor == 'driver'
      ? const <MapEntry<String, String>>[
          MapEntry('passenger_no_show', 'El pasajero no aparece'),
          MapEntry('passenger_delay', 'El pasajero está demorando demasiado'),
          MapEntry('passenger_no_response', 'El pasajero no responde'),
          MapEntry(
            'wrong_pickup',
            'La ubicación de recojo es incorrecta o confusa',
          ),
          MapEntry('unsafe_pickup', 'El punto de recojo no es seguro'),
          MapEntry('passenger_behavior', 'Problema con el pasajero'),
          MapEntry('vehicle_problem', 'Problema con el vehículo'),
          MapEntry('emergency', 'Emergencia'),
          MapEntry('other', 'Otro motivo'),
        ]
      : const <MapEntry<String, String>>[
          MapEntry('driver_delay', 'El conductor está demorando demasiado'),
          MapEntry(
            'driver_no_progress',
            'El conductor no se acerca a mi ubicación',
          ),
          MapEntry('driver_no_response', 'El conductor no responde'),
          MapEntry('change_of_plans', 'Ya no necesito el viaje'),
          MapEntry('wrong_pickup', 'Me equivoqué en el punto de recojo'),
          MapEntry('wrong_destination', 'Me equivoqué en el destino'),
          MapEntry('driver_behavior', 'Problema con el conductor'),
          MapEntry('safety', 'Me siento inseguro/a'),
          MapEntry('emergency', 'Emergencia'),
          MapEntry('other', 'Otro motivo'),
        ];

  return showModalBottomSheet<TripCancellationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    builder: (sheetContext) {
      var selected = reasons.first.key;
      String? detailError;
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
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFFFECEA),
                        child: Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿Por qué quieres cancelar?',
                          style: TextStyle(
                            color: Color(0xFF0B1F3A),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona el motivo que mejor explique lo ocurrido.',
                    style: TextStyle(color: Color(0xFF748096), height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB46A00),
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _migoCancellationStageMessage(tripStatus),
                            style: const TextStyle(
                              color: Color(0xFF0B1F3A),
                              height: 1.35,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setModalState(() {
                        selected = value;
                        detailError = null;
                      });
                    },
                    child: Column(
                      children: reasons
                          .map(
                            (entry) => RadioListTile<String>(
                              value: entry.key,
                              title: Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Color(0xFF0B1F3A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              activeColor: const Color(0xFF2557FF),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (detailError != null) {
                        setModalState(() {
                          detailError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: selected == 'other'
                          ? 'Explica el motivo *'
                          : 'Detalles adicionales (opcional)',
                      hintText: 'Cuéntanos brevemente qué ocurrió.',
                      errorText: detailError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El motivo quedará asociado al viaje y podrá ser '
                    'revisado por MIGO.',
                    style: TextStyle(color: Color(0xFF748096), fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final details = controller.text.trim();

                      if (selected == 'other' && details.isEmpty) {
                        setModalState(() {
                          detailError = 'Escribe brevemente qué ocurrió.';
                        });
                        return;
                      }

                      Navigator.of(sheetContext).pop(
                        TripCancellationChoice(
                          reason: selected,
                          label: selectedLabel,
                          details: details.isEmpty ? null : details,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD92D20),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text(
                      'Cancelar viaje',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('No cancelar'),
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
