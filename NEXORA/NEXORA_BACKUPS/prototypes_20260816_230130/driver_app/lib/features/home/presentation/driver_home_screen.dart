import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;
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
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Solicitudes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Rendimiento',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Billetera',
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
              const SizedBox(height: 24),

              Material(
                color: _isOnline ? NexoraColors.deepBlue : NexoraColors.white,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _isOnline
                          ? NexoraColors.deepBlue
                          : NexoraColors.border,
                    ),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    value: _isOnline,
                    activeTrackColor: NexoraColors.turquoise,
                    title: Text(
                      _isOnline ? 'Conectado' : 'Desconectado',
                      style: TextStyle(
                        color: _isOnline
                            ? NexoraColors.white
                            : NexoraColors.deepBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      _isOnline
                          ? 'Puedes recibir solicitudes.'
                          : 'Activa tu disponibilidad para conducir.',
                      style: TextStyle(
                        color: _isOnline
                            ? const Color(0xFFCBD5E1)
                            : NexoraColors.mutedText,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isOnline = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Resumen de hoy',
                style: TextStyle(
                  color: NexoraColors.deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: const [
                  _MetricCard(
                    icon: Icons.toll_rounded,
                    title: 'Créditos',
                    value: '70',
                    detail: 'Disponibles',
                  ),
                  _MetricCard(
                    icon: Icons.route_rounded,
                    title: 'Viajes',
                    value: '0',
                    detail: 'Completados',
                  ),
                  _MetricCard(
                    icon: Icons.payments_outlined,
                    title: 'Ingresos',
                    value: 'S/0',
                    detail: 'Declarados',
                  ),
                  _MetricCard(
                    icon: Icons.star_rounded,
                    title: 'Calificación',
                    value: '—',
                    detail: 'Sin viajes',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: () =>
                    _showPendingFeature('La recepción de solicitudes'),
                icon: const Icon(Icons.radar_rounded),
                label: Text(
                  _isOnline
                      ? 'Buscar solicitudes cercanas'
                      : 'Conéctate para recibir viajes',
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () =>
                    _showPendingFeature('La recarga segura de créditos'),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Recargar créditos'),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: NexoraColors.warning,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El modo conductor estará disponible '
                        'solo después de verificar tus documentos.',
                        style: TextStyle(
                          color: NexoraColors.darkGray,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NexoraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: NexoraColors.turquoise, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: NexoraColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: NexoraColors.deepBlue,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            detail,
            style: const TextStyle(color: NexoraColors.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
