import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../../app/app_session.dart';

class DriverHomeView extends StatefulWidget {
  const DriverHomeView({required this.session, super.key});

  final AppSession session;

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  bool get _isOnline => widget.session.driverOnline;

  final int _credits = 70;
  final int _ridesToday = 0;
  final double _earningsToday = 0;

  void _setOnline(bool value) {
    if (value && !widget.session.hasDriverPhoto) {
      _showMessage(
        'Agrega primero tu foto obligatoria en Cuenta para recibir viajes.',
      );
      return;
    }

    widget.session.setDriverOnline(value);

    if (value) {
      _showMessage(
        'Estás disponible. Las nuevas solicitudes aparecerán automáticamente.',
      );
    } else {
      _showMessage('Te desconectaste. Ya no recibirás nuevas solicitudes.');
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
