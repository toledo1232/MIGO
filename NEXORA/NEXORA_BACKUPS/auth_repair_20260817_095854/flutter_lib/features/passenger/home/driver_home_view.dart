import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class DriverHomeView extends StatefulWidget {
  const DriverHomeView({super.key});

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  bool _isOnline = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: _isOnline ? NexoraColors.deepBlue : NexoraColors.white,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isOnline
                      ? NexoraColors.deepBlue
                      : NexoraColors.border,
                ),
                borderRadius: BorderRadius.circular(22),
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

          const SizedBox(height: 26),

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

          const SizedBox(height: 22),

          FilledButton.icon(
            onPressed: _isOnline ? () {} : null,
            icon: const Icon(Icons.radar_rounded),
            label: Text(
              _isOnline
                  ? 'Esperando solicitudes'
                  : 'Conéctate para recibir viajes',
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Recargar créditos'),
          ),

          const SizedBox(height: 22),

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
                Icon(Icons.info_outline_rounded, color: NexoraColors.warning),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu autorización de conductor será '
                    'controlada por NEXORA MOVE.',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
        border: Border.all(color: NexoraColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: NexoraColors.turquoise, size: 20),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
