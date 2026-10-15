import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../app/app_session.dart';

class ModeAccountView extends StatelessWidget {
  const ModeAccountView({
    required this.session,
    required this.onSwitchMode,
    super.key,
  });

  final AppSession session;
  final ValueChanged<AppMode> onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final bool passengerMode = session.mode == AppMode.passenger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi cuenta',
            style: TextStyle(
              color: NexoraColors.deepBlue,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NexoraColors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NexoraColors.border),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: NexoraColors.deepBlue,
                  child: Icon(Icons.person_rounded, color: NexoraColors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuario MIGO',
                        style: TextStyle(
                          color: NexoraColors.deepBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Cuenta verificada',
                        style: TextStyle(
                          color: NexoraColors.turquoise,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NexoraColors.deepBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  passengerMode
                      ? Icons.local_taxi_rounded
                      : Icons.person_pin_circle_rounded,
                  color: NexoraColors.turquoise,
                  size: 36,
                ),
                const SizedBox(height: 14),
                Text(
                  passengerMode ? 'Modo conductor' : 'Modo pasajero',
                  style: const TextStyle(
                    color: NexoraColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  passengerMode
                      ? 'Recibe solicitudes y genera ingresos '
                            'con tu misma cuenta MIGO.'
                      : 'Solicita viajes nuevamente con '
                            'tu misma cuenta.',
                  style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    onSwitchMode(
                      passengerMode ? AppMode.driver : AppMode.passenger,
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(
                    passengerMode
                        ? 'Cambiar a modo conductor'
                        : 'Cambiar a modo pasajero',
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
