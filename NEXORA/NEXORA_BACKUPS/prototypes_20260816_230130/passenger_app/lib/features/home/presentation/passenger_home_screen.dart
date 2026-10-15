import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _selectedIndex = 0;

  void _showPendingFeature(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature se programará en los siguientes módulos.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Mis viajes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Seguridad',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer_rounded),
            label: 'Promos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NexoraBrandMark(),
              const SizedBox(height: 26),

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

              _LocationPanel(
                onTap: () => _showPendingFeature('La selección de ubicaciones'),
              ),
              const SizedBox(height: 26),

              const Text(
                'Elige una modalidad',
                style: TextStyle(
                  color: NexoraColors.deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),

              _RideOptionCard(
                icon: Icons.bolt_rounded,
                title: 'Viaje inmediato',
                description: 'Encuentra un conductor ahora.',
                accentColor: NexoraColors.turquoise,
                onTap: () => _showPendingFeature('El viaje inmediato'),
              ),
              const SizedBox(height: 12),

              _RideOptionCard(
                icon: Icons.calendar_month_rounded,
                title: 'Programar recojo',
                description: 'Reserva un conductor para otra hora.',
                accentColor: NexoraColors.secondaryBlue,
                onTap: () => _showPendingFeature('Los recojos programados'),
              ),
              const SizedBox(height: 12),

              _RideOptionCard(
                icon: Icons.signpost_rounded,
                title: 'Ciudad a ciudad',
                description: 'Solicita un vehículo privado para viajar.',
                accentColor: NexoraColors.warning,
                onTap: () => _showPendingFeature('Los viajes entre ciudades'),
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
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
                      size: 32,
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
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: NexoraColors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NexoraColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
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
                iconColor: NexoraColors.turquoise,
                label: 'Punto de recojo',
                value: 'Usar mi ubicación actual',
              ),
              Padding(
                padding: EdgeInsets.only(left: 13),
                child: Divider(height: 26),
              ),
              _LocationRow(
                icon: Icons.location_on_rounded,
                iconColor: NexoraColors.emergency,
                label: 'Destino',
                value: 'Escribe o selecciona un lugar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
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
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
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
        const Icon(Icons.chevron_right_rounded, color: NexoraColors.mutedText),
      ],
    );
  }
}

class _RideOptionCard extends StatelessWidget {
  const _RideOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: NexoraColors.deepBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
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
