import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class DriverHomeView extends StatefulWidget {
  const DriverHomeView({super.key});

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  bool _isOnline = false;
  bool _hasRequest = false;

  Timer? _requestTimer;
  Timer? _countdownTimer;

  int _secondsRemaining = 15;

  final int _credits = 70;
  final int _ridesToday = 0;
  final double _earningsToday = 0;

  @override
  void dispose() {
    _requestTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setOnline(bool value) {
    _requestTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _isOnline = value;
      _hasRequest = false;
      _secondsRemaining = 15;
    });

    if (value) {
      _showMessage('Estás disponible. MIGO empezará a buscar solicitudes.');

      // SIMULACIÓN:
      // Una solicitud aparece después de 3 segundos.
      //
      // Más adelante este evento llegará desde el backend
      // mediante WebSocket / Push Notification.
      _requestTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_isOnline) {
          return;
        }

        _showIncomingRequest();
      });
    } else {
      _showMessage('Te desconectaste. Ya no recibirás nuevas solicitudes.');
    }
  }

  void _showIncomingRequest() {
    _countdownTimer?.cancel();

    setState(() {
      _hasRequest = true;
      _secondsRemaining = 15;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();

        setState(() {
          _hasRequest = false;
          _secondsRemaining = 15;
        });

        _showMessage('La solicitud expiró.');

        _scheduleNextPrototypeRequest();

        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  void _scheduleNextPrototypeRequest() {
    if (!_isOnline) {
      return;
    }

    _requestTimer?.cancel();

    _requestTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isOnline && !_hasRequest) {
        _showIncomingRequest();
      }
    });
  }

  void _acceptRequest() {
    _countdownTimer?.cancel();

    setState(() {
      _hasRequest = false;
      _secondsRemaining = 15;
    });

    _showMessage(
      'Solicitud aceptada en modo demostración. '
      'En producción el servidor confirmará la asignación.',
    );
  }

  void _rejectRequest() {
    _countdownTimer?.cancel();

    setState(() {
      _hasRequest = false;
      _secondsRemaining = 15;
    });

    _showMessage('Solicitud rechazada.');

    _scheduleNextPrototypeRequest();
  }

  void _sendCounterOffer(double price) {
    _countdownTimer?.cancel();

    setState(() {
      _hasRequest = false;
      _secondsRemaining = 15;
    });

    _showMessage(
      'Contraoferta S/ ${price.toStringAsFixed(2)} enviada '
      'en modo demostración.',
    );

    _scheduleNextPrototypeRequest();
  }

  Future<void> _showCustomCounterOffer() async {
    final controller = TextEditingController(text: '21.00');

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            decoration: const BoxDecoration(
              color: NexoraColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: NexoraColors.breezeBlue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tu contraoferta',
                  style: TextStyle(
                    color: NexoraColors.softSand,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escribe cuánto propones cobrar por este viaje.',
                  style: TextStyle(color: NexoraColors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: 'S/ ',
                    labelText: 'Precio',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final value = double.tryParse(
                        controller.text.replaceAll(',', '.'),
                      );

                      if (value == null || value <= 0) {
                        return;
                      }

                      Navigator.of(context).pop(value);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: NexoraColors.royalBlue,
                      foregroundColor: NexoraColors.white,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text('Enviar contraoferta'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (result != null && mounted) {
      _sendCounterOffer(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NexoraColors.lightGray,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildStatusCard(),
                const SizedBox(height: 18),
                _buildRadar(),
                const SizedBox(height: 22),
                _buildCompactStats(),
                const SizedBox(height: 16),
                _buildCreditsCard(),
              ],
            ),
          ),

          if (_hasRequest)
            Positioned.fill(
              child: _IncomingRequestOverlay(
                secondsRemaining: _secondsRemaining,
                onAccept: _acceptRequest,
                onReject: _rejectRequest,
                onCounterOffer: _sendCounterOffer,
                onCustomCounterOffer: _showCustomCounterOffer,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MIGO DRIVER',
                style: TextStyle(
                  color: NexoraColors.royalBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isOnline ? 'Buscando pasajeros' : '¿Listo para conducir?',
                style: const TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: NexoraColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NexoraColors.breezeBlue),
          ),
          child: IconButton(
            onPressed: () {
              _showMessage(
                'Aquí aparecerán las notificaciones '
                'importantes del conductor.',
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isOnline ? const Color(0xFFEAFBF5) : NexoraColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isOnline ? const Color(0x6635D19A) : NexoraColors.breezeBlue,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: _isOnline
                  ? NexoraColors.mintGreen
                  : NexoraColors.mutedText,
              shape: BoxShape.circle,
              boxShadow: _isOnline
                  ? const [
                      BoxShadow(
                        color: Color(0x6635D19A),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'DISPONIBLE' : 'DESCONECTADO',
                  style: const TextStyle(
                    color: NexoraColors.softSand,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isOnline
                      ? 'Puedes recibir nuevas solicitudes.'
                      : 'Conéctate para empezar a trabajar.',
                  style: const TextStyle(
                    color: NexoraColors.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: _isOnline,
            activeThumbColor: NexoraColors.mintGreen,
            onChanged: (value) {
              if (value && _credits <= 0) {
                _showMessage('Necesitas créditos para conectarte.');
                return;
              }

              _setOnline(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadar() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: NexoraColors.softSand,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(225, 225),
            painter: _RadarPainter(active: _isOnline),
          ),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _isOnline
                  ? NexoraColors.mintGreen
                  : NexoraColors.breezeBlue,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 18),
              ],
            ),
            child: Icon(
              Icons.local_taxi_rounded,
              color: _isOnline ? NexoraColors.white : NexoraColors.softSand,
              size: 34,
            ),
          ),

          Positioned(
            bottom: 23,
            child: Text(
              _isOnline
                  ? 'Buscando viajes cerca de ti...'
                  : 'Activa Disponible para comenzar',
              style: const TextStyle(
                color: NexoraColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStats() {
    return Row(
      children: [
        Expanded(
          child: _DriverMiniStat(
            icon: Icons.route_rounded,
            value: '$_ridesToday',
            label: 'Viajes hoy',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DriverMiniStat(
            icon: Icons.payments_outlined,
            value: 'S/ ${_earningsToday.toStringAsFixed(2)}',
            label: 'Ganancias',
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _DriverMiniStat(
            icon: Icons.star_rounded,
            value: '—',
            label: 'Calificación',
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NexoraColors.breezeBlue),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NexoraColors.breezeBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: NexoraColors.royalBlue,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créditos disponibles',
                  style: TextStyle(color: NexoraColors.mutedText, fontSize: 11),
                ),
                Text(
                  '$_credits créditos',
                  style: const TextStyle(
                    color: NexoraColors.softSand,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _showMessage('La recarga se conectará al sistema de pagos.');
            },
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IncomingRequestOverlay extends StatelessWidget {
  const _IncomingRequestOverlay({
    required this.secondsRemaining,
    required this.onAccept,
    required this.onReject,
    required this.onCounterOffer,
    required this.onCustomCounterOffer,
  });

  final int secondsRemaining;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final ValueChanged<double> onCounterOffer;
  final VoidCallback onCustomCounterOffer;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x520B1F3D),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: NexoraColors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330B1F3D),
                  blurRadius: 30,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: NexoraColors.breezeBlue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAFBF5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: NexoraColors.mintGreen,
                              size: 17,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'NUEVA SOLICITUD',
                              style: TextStyle(
                                color: NexoraColors.softSand,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: secondsRemaining <= 5
                              ? const Color(0xFFFFECEA)
                              : NexoraColors.breezeBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${secondsRemaining}s',
                          style: TextStyle(
                            color: secondsRemaining <= 5
                                ? NexoraColors.emergency
                                : NexoraColors.royalBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 17),

                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: NexoraColors.breezeBlue,
                        child: Icon(
                          Icons.person_rounded,
                          color: NexoraColors.royalBlue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pasajero MIGO',
                              style: TextStyle(
                                color: NexoraColors.softSand,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '★ 4.9   •   36 viajes',
                              style: TextStyle(
                                color: NexoraColors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NexoraColors.lightGray,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        _RequestLocation(
                          icon: Icons.my_location_rounded,
                          iconColor: NexoraColors.mintGreen,
                          label: 'RECOJO',
                          value: 'Av. Luzuriaga, Huaraz',
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 17),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 18,
                              child: VerticalDivider(
                                thickness: 2,
                                color: NexoraColors.breezeBlue,
                              ),
                            ),
                          ),
                        ),
                        _RequestLocation(
                          icon: Icons.location_on_rounded,
                          iconColor: NexoraColors.royalBlue,
                          label: 'DESTINO',
                          value: 'Independencia, Huaraz',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Row(
                    children: [
                      Expanded(
                        child: _RequestFact(
                          icon: Icons.near_me_outlined,
                          title: '1.4 km',
                          subtitle: 'hasta pasajero',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _RequestFact(
                          icon: Icons.schedule_rounded,
                          title: '5 min',
                          subtitle: 'para recoger',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _RequestFact(
                          icon: Icons.payments_outlined,
                          title: 'Efectivo',
                          subtitle: 'forma de pago',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 19),

                  const Text(
                    'PRECIO OFRECIDO',
                    style: TextStyle(
                      color: NexoraColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'S/ 18.50',
                    style: TextStyle(
                      color: NexoraColors.softSand,
                      fontSize: 37,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('accept-driver-request'),
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: NexoraColors.royalBlue,
                        foregroundColor: NexoraColors.white,
                        minimumSize: const Size.fromHeight(57),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        'ACEPTAR  •  S/ 18.50',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    '¿Quieres proponer otra tarifa?',
                    style: TextStyle(
                      color: NexoraColors.softSand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _QuickPriceButton(
                          price: 19,
                          onTap: onCounterOffer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickPriceButton(
                          price: 20,
                          onTap: onCounterOffer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickPriceButton(
                          price: 21,
                          onTap: onCounterOffer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 51,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onCustomCounterOffer,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(
                              color: NexoraColors.breezeBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: NexoraColors.royalBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    key: const ValueKey('reject-driver-request'),
                    onPressed: onReject,
                    child: const Text(
                      'Rechazar solicitud',
                      style: TextStyle(
                        color: NexoraColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPriceButton extends StatelessWidget {
  const _QuickPriceButton({required this.price, required this.onTap});

  final double price;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          onTap(price);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: NexoraColors.royalBlue,
          side: const BorderSide(color: NexoraColors.breezeBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'S/${price.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _RequestLocation extends StatelessWidget {
  const _RequestLocation({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestFact extends StatelessWidget {
  const _RequestFact({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 83,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NexoraColors.lightGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: NexoraColors.royalBlue, size: 19),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: NexoraColors.softSand,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: NexoraColors.mutedText, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _DriverMiniStat extends StatelessWidget {
  const _DriverMiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NexoraColors.breezeBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NexoraColors.royalBlue, size: 21),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NexoraColors.softSand,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: NexoraColors.mutedText, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = active ? const Color(0x5535D19A) : const Color(0x334A5B75);

    for (final radius in <double>[45, 75, 105]) {
      canvas.drawCircle(center, radius, circlePaint);
    }

    final crossPaint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x2235D19A);

    canvas.drawLine(
      Offset(center.dx, 5),
      Offset(center.dx, size.height - 5),
      crossPaint,
    );

    canvas.drawLine(
      Offset(5, center.dy),
      Offset(size.width - 5, center.dy),
      crossPaint,
    );

    if (active) {
      final pointPaint = Paint()..color = NexoraColors.mintGreen;

      canvas.drawCircle(Offset(center.dx - 69, center.dy - 47), 5, pointPaint);

      canvas.drawCircle(Offset(center.dx + 72, center.dy - 28), 4, pointPaint);

      canvas.drawCircle(Offset(center.dx + 48, center.dy + 67), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.active != active;
  }
}
