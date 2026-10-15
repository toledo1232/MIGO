import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class PassengerHomeView extends StatelessWidget {
  const PassengerHomeView({super.key});

  void _pending(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature se programará en los siguientes módulos.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hola, viajero',
            style: TextStyle(
              color: NexoraColors.mutedText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '¿A dónde vamos?',
            style: TextStyle(
              color: NexoraColors.deepBlue,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: NexoraColors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _pending(context, 'La selección de ubicaciones'),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: NexoraColors.border),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    _LocationRow(
                      icon: Icons.my_location_rounded,
                      color: NexoraColors.turquoise,
                      title: 'Punto de recojo',
                      value: 'Usar mi ubicación actual',
                    ),
                    Divider(height: 28),
                    _LocationRow(
                      icon: Icons.location_on_rounded,
                      color: NexoraColors.emergency,
                      title: 'Destino',
                      value: 'Escribe o selecciona un lugar',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Elige una modalidad',
            style: TextStyle(
              color: NexoraColors.deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _RideCard(
            icon: Icons.bolt_rounded,
            color: NexoraColors.turquoise,
            title: 'Viaje inmediato',
            subtitle: 'Encuentra un conductor ahora.',
            onTap: () => _pending(context, 'El viaje inmediato'),
          ),
          const SizedBox(height: 12),
          _RideCard(
            icon: Icons.calendar_month_rounded,
            color: NexoraColors.secondaryBlue,
            title: 'Programar recojo',
            subtitle: 'Reserva un conductor para otra hora.',
            onTap: () => _pending(context, 'Los recojos programados'),
          ),
          const SizedBox(height: 12),
          _RideCard(
            icon: Icons.signpost_rounded,
            color: NexoraColors.warning,
            title: 'Ciudad a ciudad',
            subtitle: 'Solicita un vehículo privado para viajar.',
            onTap: () => _pending(context, 'Los viajes entre ciudades'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NexoraColors.deepBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: NexoraColors.turquoise,
                  size: 30,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu seguridad es prioridad',
                        style: TextStyle(
                          color: NexoraColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Conductores e identidades verificadas.',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: NexoraColors.darkGray,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NexoraColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: NexoraColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: NexoraColors.deepBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: NexoraColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: NexoraColors.deepBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
