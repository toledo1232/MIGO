import 'dart:async';

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

  late final AnimationController _pulseController;
  Timer? _messageTimer;

  String _statusMessage = 'Enviando tu solicitud a conductores cercanos...';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _messageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
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
    _pulseController.dispose();
    super.dispose();
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

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: AnimatedBuilder(
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
                          Container(
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
                            child: const Icon(
                              Icons.local_taxi_rounded,
                              color: _blue,
                              size: 48,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Buscando conductores cercanos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                    style: const TextStyle(
                      color: Color(0xFF748096),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
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
}
