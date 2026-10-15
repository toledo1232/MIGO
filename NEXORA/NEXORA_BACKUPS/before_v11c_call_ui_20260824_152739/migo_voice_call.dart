import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_trip_support.dart';

const _migoNavy = Color(0xFF0B1F3A);
const _migoTurquoise = Color(0xFF35D0A0);
const _migoDanger = Color(0xFFD92D20);

Future<void> startMigoVoiceCall(
  BuildContext context, {
  required String requestId,
  required String actor,
  required String otherName,
}) async {
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
}) async {
  final callId = call['id']?.toString();
  final status = call['status']?.toString();

  if (callId == null || callId.isEmpty || status != 'ringing') {
    return;
  }

  final accepted =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFE5FBF5),
                  child: Icon(Icons.call_rounded, color: _migoTurquoise),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Llamada entrante')),
              ],
            ),
            content: Text('$otherName te está llamando por MIGO.'),
            actions: [
              TextButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.call_end_rounded, color: _migoDanger),
                label: const Text('Rechazar'),
              ),
              FilledButton.icon(
                onPressed: () async {
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
                          content: Text(
                            'No se pudo aceptar la llamada. $error',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.call_rounded),
                label: const Text('Aceptar'),
              ),
            ],
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
        incoming: true,
      ),
    ),
  );
}

class MigoVoiceCallPage extends StatefulWidget {
  const MigoVoiceCallPage({
    required this.requestId,
    required this.callId,
    required this.actor,
    required this.otherName,
    required this.incoming,
    super.key,
  });

  final String requestId;
  final String callId;
  final String actor;
  final String otherName;
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
                'En producción MIGO usará un servidor TURN.';
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
      } catch (_) {
        // Otro candidato podrá completar la conexión.
      }
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
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: Color(0xFF173659),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
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
                const SizedBox(height: 10),
                Text(
                  _connected ? _formattedDuration : _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
