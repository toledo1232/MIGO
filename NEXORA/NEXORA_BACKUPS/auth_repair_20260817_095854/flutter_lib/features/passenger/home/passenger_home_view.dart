import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class PassengerHomeView extends StatefulWidget {
  const PassengerHomeView({super.key});

  @override
  State<PassengerHomeView> createState() => _PassengerHomeViewState();
}

class _PassengerHomeViewState extends State<PassengerHomeView> {
  int _selectedService = 0;

  static const _services = <_ServiceOption>[
    _ServiceOption(
      icon: Icons.local_taxi_rounded,
      title: 'Viaje inmediato',
      subtitle: 'Pide ahora',
    ),
    _ServiceOption(
      icon: Icons.schedule_rounded,
      title: 'Programar recojo',
      subtitle: 'Elige fecha',
    ),
    _ServiceOption(
      icon: Icons.route_rounded,
      title: 'Ciudad a ciudad',
      subtitle: 'Viaje privado',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NexoraColors.lightGray,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),

            const SizedBox(height: 22),

            _buildSearchCard(),

            const SizedBox(height: 18),

            _buildMapPreview(),

            const SizedBox(height: 26),

            const Text(
              'Â¿CÃ³mo quieres viajar?',
              style: TextStyle(
                color: NexoraColors.softSand,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 14),

            _buildServices(),

            const SizedBox(height: 26),

            _buildPriceCard(),

            const SizedBox(height: 18),

            _buildSafetyCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hola ðŸ‘‹',
                style: TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Â¿A dÃ³nde vamos?',
                style: TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
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
            tooltip: 'Notificaciones',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Las notificaciones se conectarÃ¡n '
                    'al servidor mÃ¡s adelante.',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: NexoraColors.softSand,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NexoraColors.breezeBlue),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100B1F3D),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _LocationField(
            icon: Icons.my_location_rounded,
            iconColor: NexoraColors.mintGreen,
            label: 'UbicaciÃ³n actual',
            value: 'Usar mi ubicaciÃ³n',
            onTap: () {
              _showPrototypeMessage('AquÃ­ conectaremos el GPS del pasajero.');
            },
          ),

          Padding(
            padding: const EdgeInsets.only(left: 17),
            child: Row(
              children: [
                Container(width: 2, height: 20, color: NexoraColors.breezeBlue),
              ],
            ),
          ),

          _LocationField(
            icon: Icons.location_on_rounded,
            iconColor: NexoraColors.royalBlue,
            label: 'Destino',
            value: 'Â¿A dÃ³nde quieres ir?',
            onTap: () {
              _showPrototypeMessage(
                'AquÃ­ conectaremos bÃºsqueda de destinos '
                'y Google Places.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 205,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF1FF), Color(0xFFF7FAFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapLinesPainter())),

            const Positioned(
              top: 24,
              left: 38,
              child: _MapPoint(
                color: NexoraColors.mintGreen,
                icon: Icons.my_location_rounded,
              ),
            ),

            const Positioned(
              right: 48,
              bottom: 36,
              child: _MapPoint(
                color: NexoraColors.royalBlue,
                icon: Icons.location_on_rounded,
              ),
            ),

            Positioned(
              left: 24,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: NexoraColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160B1F3D),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_filled_rounded,
                      color: NexoraColors.royalBlue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tu ruta aparecerÃ¡ aquÃ­',
                      style: TextStyle(
                        color: NexoraColors.softSand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: NexoraColors.white,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    _showPrototypeMessage(
                      'El mapa interactivo se integrarÃ¡ '
                      'en el mÃ³dulo de mapas.',
                    );
                  },
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.layers_outlined,
                      color: NexoraColors.softSand,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServices() {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _services[index];
          final selected = _selectedService == index;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _selectedService = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 132,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? NexoraColors.royalBlue : NexoraColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? NexoraColors.royalBlue
                      : NexoraColors.breezeBlue,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    color: selected
                        ? NexoraColors.white
                        : NexoraColors.royalBlue,
                    size: 27,
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    maxLines: 2,
                    style: TextStyle(
                      color: selected
                          ? NexoraColors.white
                          : NexoraColors.softSand,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFDCE8FF)
                          : NexoraColors.mutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NexoraColors.softSand,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'TÃº propones el precio',
                  style: TextStyle(
                    color: NexoraColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.payments_outlined, color: NexoraColors.mintGreen),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Cuando elijas origen y destino podrÃ¡s '
            'proponer cuÃ¡nto pagar por tu viaje.',
            style: TextStyle(
              color: Color(0xFFDCE8FF),
              fontSize: 13,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _showPrototypeMessage(
                  'Primero seleccionaremos origen y destino. '
                  'DespuÃ©s activaremos la propuesta de precio.',
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continuar con mi viaje'),
              style: FilledButton.styleFrom(
                backgroundColor: NexoraColors.mintGreen,
                foregroundColor: NexoraColors.softSand,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x5535D19A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: NexoraColors.mintGreen,
            child: Icon(Icons.verified_user_rounded, color: NexoraColors.white),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu seguridad es prioridad',
                  style: TextStyle(
                    color: NexoraColors.softSand,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Los conductores deberÃ¡n estar '
                  'verificados antes de poder conectarse '
                  'y recibir solicitudes.',
                  style: TextStyle(
                    color: NexoraColors.mutedText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrototypeMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: NexoraColors.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: NexoraColors.softSand,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: NexoraColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceOption {
  const _ServiceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _MapPoint extends StatelessWidget {
  const _MapPoint({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: NexoraColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240B1F3D),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _MapLinesPainter extends CustomPainter {
  const _MapLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryRoadPaint = Paint()
      ..color = const Color(0xFFDCE8FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = NexoraColors.royalBlue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(-20, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.1,
        size.width * 0.58,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.75,
        size.width + 30,
        size.height * 0.4,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.2, -20)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.38,
        size.width * 0.25,
        size.height + 20,
      );

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..lineTo(size.width * 0.38, size.height * 0.45)
      ..lineTo(size.width * 0.58, size.height * 0.38)
      ..lineTo(size.width * 0.78, size.height * 0.72);

    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, secondaryRoadPaint);
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
