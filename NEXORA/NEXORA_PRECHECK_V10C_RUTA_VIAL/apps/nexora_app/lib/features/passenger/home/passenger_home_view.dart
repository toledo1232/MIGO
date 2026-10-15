import 'package:flutter/material.dart';

import '../ride_request/immediate_ride_request_screen.dart' as ride_request;

class PassengerHomeView extends StatelessWidget {
  const PassengerHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Hola 👋', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          '¿A dónde vamos?',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.my_location_rounded),
                  title: Text('Ubicación actual'),
                  subtitle: Text('Usar mi ubicación'),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.location_on_rounded),
                  title: Text('Destino'),
                  subtitle: Text('¿A dónde quieres ir?'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          '¿Cómo quieres viajar?',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 145,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ServiceCard(
                key: const ValueKey('immediate-ride-card'),
                title: 'Viaje inmediato',
                subtitle: 'Pide ahora',
                icon: Icons.local_taxi_rounded,
                selected: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ride_request.ImmediateRideRequestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _ServiceCard(
                title: 'Programar recojo',
                subtitle: 'Elige fecha',
                icon: Icons.schedule_rounded,
                onTap: () {},
              ),
              const SizedBox(width: 12),
              _ServiceCard(
                title: 'Ciudad a ciudad',
                subtitle: 'Viaje privado',
                icon: Icons.route_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color: selected ? const Color(0xFF1E4BFF) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFF1E4BFF),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF08254A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.black54,
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
