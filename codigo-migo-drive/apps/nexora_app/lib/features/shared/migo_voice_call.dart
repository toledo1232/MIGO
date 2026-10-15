import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_trip_support.dart';

const _migoNavy = Color(0xFF0B1F3A);
const _migoTurquoise = Color(0xFF35D0A0);
const _migoDanger = Color(0xFFD92D20);

String _migoAssignedLabel(String role) {
  return role == 'driver'
      ? 'Conductor asignado de MIGO DRIVE'
      : 'Pasajero asignado de MIGO DRIVE';
}

String? _migoStringValue(Object? raw) {
  if (raw == null) {
    return null;
  }

  final value = raw.toString().trim();

  if (value.isEmpty ||
      value == 'null' ||
      value == 'None' ||
      value == 'undefined') {
    return null;
  }

  return value;
}

String? _migoPhotoFromMap(Map<dynamic, dynamic>? data) {
  if (data == null) {
    return null;
  }

  const keys = [
    'profile_photo',
    'profilePhoto',
    'profile_photo_path',
    'profilePhotoPath',
    'profile_photo_url',
    'profilePhotoUrl',
    'photo',
    'photo_path',
    'photoPath',
    'photo_url',
    'photoUrl',
    'photo_base64',
    'photoBase64',
    'avatar',
    'avatar_path',
    'avatarPath',
    'image',
    'image_path',
    'imagePath',
  ];

  for (final key in keys) {
    final value = _migoStringValue(data[key]);

    if (value != null) {
      return value;
    }
  }

  return null;
}

Future<String?> resolveMigoCallProfilePhoto(
  Map<String, dynamic>? ride,
  String role,
) async {
  final normalizedRole = role == 'driver' ? 'driver' : 'passenger';

  if (ride != null) {
    final nested = ride[normalizedRole];

    if (nested is Map) {
      final value = _migoPhotoFromMap(nested);

      if (value != null) {
        return value;
      }
    }

    final snakeKeys = [
      '${normalizedRole}_profile_photo',
      '${normalizedRole}_profile_photo_path',
      '${normalizedRole}_profile_photo_url',
      '${normalizedRole}_photo',
      '${normalizedRole}_photo_path',
      '${normalizedRole}_photo_url',
      '${normalizedRole}_photo_base64',
      '${normalizedRole}_avatar',
      '${normalizedRole}_avatar_path',
      '${normalizedRole}_image',
      '${normalizedRole}_image_path',
    ];

    final camelPrefix = normalizedRole == 'driver' ? 'driver' : 'passenger';

    final camelKeys = [
      '${camelPrefix}ProfilePhoto',
      '${camelPrefix}ProfilePhotoPath',
      '${camelPrefix}ProfilePhotoUrl',
      '${camelPrefix}Photo',
      '${camelPrefix}PhotoPath',
      '${camelPrefix}PhotoUrl',
      '${camelPrefix}PhotoBase64',
      '${camelPrefix}Avatar',
      '${camelPrefix}AvatarPath',
      '${camelPrefix}Image',
      '${camelPrefix}ImagePath',
    ];

    for (final key in [...snakeKeys, ...camelKeys]) {
      final value = _migoStringValue(ride[key]);

      if (value != null) {
        return value;
      }
    }
  }

  try {
    final prefs = await SharedPreferences.getInstance();

    final exactKeys = [
      'migo_${normalizedRole}_profile_photo',
      'migo_${normalizedRole}_profile_photo_path',
      'migo_${normalizedRole}_photo',
      'migo_${normalizedRole}_photo_path',
      '${normalizedRole}_profile_photo',
      '${normalizedRole}_profile_photo_path',
      '${normalizedRole}_photo',
      '${normalizedRole}_photo_path',
      '${normalizedRole}_avatar',
      '${normalizedRole}_image',
      'profile_${normalizedRole}_photo',
      'profile_${normalizedRole}_photo_path',
    ];

    for (final key in exactKeys) {
      final value = _migoStringValue(prefs.get(key));

      if (value != null) {
        return value;
      }
    }

    final scored = <({int score, String key, String value})>[];

    for (final key in prefs.getKeys()) {
      final lower = key.toLowerCase();

      final containsPhoto =
          lower.contains('photo') ||
          lower.contains('foto') ||
          lower.contains('avatar') ||
          lower.contains('image');

      if (!containsPhoto) {
        continue;
      }

      final raw = prefs.get(key);
      final value = _migoStringValue(raw);

      if (value == null) {
        continue;
      }

      var score = 0;

      if (lower.contains(normalizedRole)) {
        score += 100;
      }

      if (lower.contains('profile') || lower.contains('perfil')) {
        score += 30;
      }

      if (lower.contains('photo') || lower.contains('foto')) {
        score += 20;
      }

      if (lower.contains('path') || lower.contains('base64')) {
        score += 10;
      }

      scored.add((score: score, key: key, value: value));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isNotEmpty && scored.first.score >= 100) {
      return scored.first.value;
    }
  } catch (_) {
    // Si la persistencia local no está disponible,
    // se usará el avatar de respaldo.
  }

  return null;
}

Uint8List? _migoTryBase64(String source) {
  var raw = source.trim();

  if (raw.startsWith('data:image/')) {
    final comma = raw.indexOf(',');

    if (comma >= 0 && comma + 1 < raw.length) {
      raw = raw.substring(comma + 1);
    }
  }

  if (raw.length < 80) {
    return null;
  }

  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

ImageProvider<Object>? _migoImageProvider(String? source) {
  final value = _migoStringValue(source);

  if (value == null) {
    return null;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return NetworkImage(value);
  }

  final bytes = _migoTryBase64(value);

  if (bytes != null && bytes.isNotEmpty) {
    return MemoryImage(bytes);
  }

  if (value.startsWith('assets/')) {
    return AssetImage(value);
  }

  try {
    final file = File(value);

    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (_) {
    // El valor no era una ruta local válida.
  }

  return null;
}

String _migoInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'M';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _MigoCallAvatar extends StatelessWidget {
  const _MigoCallAvatar({
    required this.name,
    required this.photoSource,
    this.size = 58,
  });

  final String name;
  final String? photoSource;
  final double size;

  @override
  Widget build(BuildContext context) {
    final provider = _migoImageProvider(photoSource);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE4FBF4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: provider == null
          ? Text(
              _migoInitials(name),
              style: TextStyle(
                color: _migoNavy,
                fontSize: size * 0.30,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

Future<void> startMigoVoiceCall(
  BuildContext context, {
  required String requestId,
  required String actor,
  required String otherName,
  Map<String, dynamic>? ride,
}) async {
  final otherRole = actor == 'passenger' ? 'driver' : 'passenger';

  final photoSource = await resolveMigoCallProfilePhoto(ride, otherRole);

  try {
    final call = await LiveTripApi.startVoiceCall(requestId, actor: actor);

    if (!context.mounted) {
      return;
    }

    final callId = call['id']?.toString();

    if (callId == null || callId.isEmpty) {
      throw const FormatException('MIGO no recibió el ID de la llamada.');
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MigoVoiceCallPage(
          requestId: requestId,
          callId: callId,
          actor: actor,
          otherName: otherName,
          otherRole: otherRole,
          photoSource: photoSource,
          incoming: false,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo iniciar la llamada. $error')),
    );
  }
}

Future<void> receiveMigoVoiceCall(
  BuildContext context, {
  required String requestId,
  required String actor,
  required String otherName,
  required Map<String, dynamic> call,
  Map<String, dynamic>? ride,
}) async {
  final callId = call['id']?.toString();
  final status = call['status']?.toString();

  if (callId == null || callId.isEmpty || status != 'ringing') {
    return;
  }

  final otherRole = actor == 'passenger' ? 'driver' : 'passenger';

  final photoSource = await resolveMigoCallProfilePhoto(ride, otherRole);

  if (!context.mounted) {
    return;
  }

  final accepted =
      await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Llamada entrante MIGO',
        barrierColor: Colors.black.withValues(alpha: 0.18),
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.18),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.sizeOf(dialogContext).width - 24,
                  constraints: const BoxConstraints(maxWidth: 430),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _MigoCallAvatar(
                        name: otherName,
                        photoSource: photoSource,
                        size: 58,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Llamada entrante',
                              style: TextStyle(
                                color: Color(0xFF7C879A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              otherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _migoNavy,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _migoAssignedLabel(otherRole),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF68758A),
                                fontSize: 11,
                                height: 1.18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IncomingCallCircleButton(
                        tooltip: 'Aceptar',
                        icon: Icons.call_rounded,
                        backgroundColor: _migoTurquoise,
                        onTap: () async {
                          try {
                            await LiveTripApi.voiceCallAction(
                              requestId,
                              actor: actor,
                              action: 'accept',
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo aceptar. $error'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _IncomingCallCircleButton(
                        tooltip: 'Rechazar',
                        icon: Icons.call_end_rounded,
                        backgroundColor: _migoDanger,
                        onTap: () async {
                          try {
                            await LiveTripApi.voiceCallAction(
                              requestId,
                              actor: actor,
                              action: 'reject',
                            );
                          } catch (_) {}

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(false);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ) ??
      false;

  if (!accepted || !context.mounted) {
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MigoVoiceCallPage(
        requestId: requestId,
        callId: callId,
        actor: actor,
        otherName: otherName,
        otherRole: otherRole,
        photoSource: photoSource,
        incoming: true,
      ),
    ),
  );
}

class _IncomingCallCircleButton extends StatelessWidget {
  const _IncomingCallCircleButton({
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () async {
          await onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class MigoVoiceCallPage extends StatefulWidget {
  const MigoVoiceCallPage({
    required this.requestId,
    required this.callId,
    required this.actor,
    required this.otherName,
    required this.otherRole,
    required this.photoSource,
    required this.incoming,
    super.key,
  });

  final String requestId;
  final String callId;
  final String actor;
  final String otherName;
  final String otherRole;
  final String? photoSource;
  final bool incoming;

  @override
  State<MigoVoiceCallPage> createState() => _MigoVoiceCallPageState();
}

class _MigoVoiceCallPageState extends State<MigoVoiceCallPage> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final Set<String> _processedSignalIds = <String>{};
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  Timer? _pollTimer;
  Timer? _durationTimer;

  bool _remoteDescriptionSet = false;
  bool _closing = false;
  bool _muted = false;
  bool _speaker = true;
  bool _connected = false;

  DateTime? _connectedAt;

  String _status = 'Preparando llamada…';
  String? _error;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _durationTimer?.cancel();
    unawaited(_cleanupMedia());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Helper.setSpeakerphoneOn(true);

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      final peer = await createPeerConnection({
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
        ],
        'sdpSemantics': 'unified-plan',
      });

      _peerConnection = peer;

      peer.onIceCandidate = (candidate) {
        final value = candidate.candidate;

        if (value == null || value.isEmpty || _closing) {
          return;
        }

        unawaited(
          LiveTripApi.sendVoiceSignal(
            widget.requestId,
            actor: widget.actor,
            signalType: 'candidate',
            payload: {
              'candidate': value,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          ),
        );
      };

      peer.onTrack = (event) {
        if (event.track.kind == 'audio' && mounted) {
          setState(() {
            _status = 'Audio conectado';
          });
        }
      };

      peer.onConnectionState = (state) {
        if (!mounted) {
          return;
        }

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _markConnected();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
          setState(() {
            _status = 'Conectando…';
          });
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          setState(() {
            _status = 'No se pudo conectar';
            _error =
                'WebRTC no logró establecer el audio. '
                'Para producción MIGO usará TURN.';
          });
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          setState(() {
            _status = 'Reconectando…';
          });
        }
      };

      final stream = _localStream;

      if (stream == null) {
        throw StateError('No se pudo abrir el micrófono.');
      }

      for (final track in stream.getTracks()) {
        await peer.addTrack(track, stream);
      }

      if (!widget.incoming) {
        if (mounted) {
          setState(() {
            _status = 'Llamando a ${widget.otherName}…';
          });
        }

        final offer = await peer.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false,
        });

        await peer.setLocalDescription(offer);

        await LiveTripApi.sendVoiceSignal(
          widget.requestId,
          actor: widget.actor,
          signalType: 'offer',
          payload: {'sdp': offer.sdp, 'type': offer.type},
        );
      } else if (mounted) {
        setState(() {
          _status = 'Conectando con ${widget.otherName}…';
        });
      }

      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => unawaited(_pollCall()),
      );

      await _pollCall();
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = 'No se pudo iniciar la llamada';
          _error = error.toString();
        });
      }
    }
  }

  void _markConnected() {
    if (_connected) {
      return;
    }

    _connected = true;
    _connectedAt = DateTime.now();

    setState(() {
      _status = 'En llamada';
      _duration = Duration.zero;
    });

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _connectedAt;

      if (!mounted || started == null) {
        return;
      }

      setState(() {
        _duration = DateTime.now().difference(started);
      });
    });
  }

  Future<void> _pollCall() async {
    if (_closing) {
      return;
    }

    try {
      final call = await LiveTripApi.getVoiceCall(
        widget.requestId,
        actor: widget.actor,
      );

      if (call['id']?.toString() != widget.callId) {
        return;
      }

      final status = call['status']?.toString() ?? '';

      if (status == 'rejected') {
        await _remoteFinished('Llamada rechazada');
        return;
      }

      if (status == 'ended') {
        await _remoteFinished('Llamada finalizada');
        return;
      }

      if (!widget.incoming && status == 'accepted' && mounted) {
        setState(() {
          _status = 'Conectando…';
        });
      }

      final signals = call['signals'];

      if (signals is List) {
        for (final raw in signals) {
          if (raw is! Map) {
            continue;
          }

          await _processSignal(Map<String, dynamic>.from(raw));
        }
      }
    } catch (error) {
      if (mounted && !_closing) {
        setState(() {
          _error = 'Señalización: $error';
        });
      }
    }
  }

  Future<void> _processSignal(Map<String, dynamic> signal) async {
    final id = signal['id']?.toString();

    if (id == null ||
        id.isEmpty ||
        _processedSignalIds.contains(id) ||
        signal['actor']?.toString() == widget.actor) {
      return;
    }

    _processedSignalIds.add(id);

    final peer = _peerConnection;

    if (peer == null) {
      return;
    }

    final type = signal['signal_type']?.toString();
    final rawPayload = signal['payload'];

    if (rawPayload is! Map) {
      return;
    }

    final payload = Map<String, dynamic>.from(rawPayload);

    if (type == 'offer' && widget.incoming && !_remoteDescriptionSet) {
      final sdp = payload['sdp']?.toString();
      final sdpType = payload['type']?.toString();

      if (sdp == null || sdpType == null) {
        return;
      }

      await peer.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
      _remoteDescriptionSet = true;
      await _flushCandidates();

      final answer = await peer.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await peer.setLocalDescription(answer);

      await LiveTripApi.sendVoiceSignal(
        widget.requestId,
        actor: widget.actor,
        signalType: 'answer',
        payload: {'sdp': answer.sdp, 'type': answer.type},
      );

      return;
    }

    if (type == 'answer' && !widget.incoming && !_remoteDescriptionSet) {
      final sdp = payload['sdp']?.toString();
      final sdpType = payload['type']?.toString();

      if (sdp == null || sdpType == null) {
        return;
      }

      await peer.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
      _remoteDescriptionSet = true;
      await _flushCandidates();
      return;
    }

    if (type == 'candidate') {
      final candidateText = payload['candidate']?.toString();

      if (candidateText == null || candidateText.isEmpty) {
        return;
      }

      final candidate = RTCIceCandidate(
        candidateText,
        payload['sdpMid']?.toString(),
        (payload['sdpMLineIndex'] as num?)?.toInt(),
      );

      if (_remoteDescriptionSet) {
        await peer.addCandidate(candidate);
      } else {
        _pendingCandidates.add(candidate);
      }
    }
  }

  Future<void> _flushCandidates() async {
    final peer = _peerConnection;

    if (peer == null || !_remoteDescriptionSet) {
      return;
    }

    final pending = List<RTCIceCandidate>.from(_pendingCandidates);

    _pendingCandidates.clear();

    for (final candidate in pending) {
      try {
        await peer.addCandidate(candidate);
      } catch (_) {}
    }
  }

  Future<void> _toggleMute() async {
    final stream = _localStream;

    if (stream == null) {
      return;
    }

    final tracks = stream.getAudioTracks();

    if (tracks.isEmpty) {
      return;
    }

    final next = !_muted;

    try {
      await Helper.setMicrophoneMute(next, tracks.first);

      if (mounted) {
        setState(() {
          _muted = next;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cambiar el micrófono. $error';
        });
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speaker;

    try {
      await Helper.setSpeakerphoneOn(next);

      if (mounted) {
        setState(() {
          _speaker = next;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cambiar el altavoz. $error';
        });
      }
    }
  }

  Future<void> _hangUp() async {
    if (_closing) {
      return;
    }

    _closing = true;

    try {
      await LiveTripApi.voiceCallAction(
        widget.requestId,
        actor: widget.actor,
        action: 'end',
      );
    } catch (_) {}

    await _cleanupMedia();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _remoteFinished(String message) async {
    if (_closing) {
      return;
    }

    _closing = true;

    if (mounted) {
      setState(() {
        _status = message;
      });
    }

    await _cleanupMedia();

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cleanupMedia() async {
    _pollTimer?.cancel();
    _durationTimer?.cancel();

    final stream = _localStream;
    _localStream = null;

    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }

      try {
        await stream.dispose();
      } catch (_) {}
    }

    final peer = _peerConnection;
    _peerConnection = null;

    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {}

      try {
        await peer.dispose();
      } catch (_) {}
    }

    try {
      await Helper.clearAndroidCommunicationDevice();
    } catch (_) {}
  }

  String get _formattedDuration {
    final minutes = _duration.inMinutes;
    final seconds = _duration.inSeconds.remainder(60);

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _migoNavy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
            child: Column(
              children: [
                const Spacer(),
                _MigoCallAvatar(
                  name: widget.otherName,
                  photoSource: widget.photoSource,
                  size: 118,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.otherName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _migoAssignedLabel(widget.otherRole),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  _connected ? _formattedDuration : _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallControl(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'Activar' : 'Silenciar',
                      active: _muted,
                      onTap: _toggleMute,
                    ),
                    _CallControl(
                      icon: _speaker
                          ? Icons.volume_up_rounded
                          : Icons.hearing_rounded,
                      label: 'Altavoz',
                      active: _speaker,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                InkWell(
                  onTap: _hangUp,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: _migoDanger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Colgar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            await onTap();
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? _migoNavy : Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
