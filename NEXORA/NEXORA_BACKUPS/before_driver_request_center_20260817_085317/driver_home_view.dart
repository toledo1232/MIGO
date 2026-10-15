import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class DriverHomeView extends StatefulWidget {
  const DriverHomeView({super.key});

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  bool _isOnline = false;

  final int _credits = 70;
  final int _ridesToday = 0;
  final double _earningsToday = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NexoraColors.lightGray,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 20),

            _buildAvailabilityCard(),

            const SizedBox(height: 24),

            const Text(
              'Resumen de hoy',
              style: TextStyle(
                color: NexoraColors.softSand,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 14),

            _buildSummary(),

            const SizedBox(height: 24),

            _buildCreditsCard(),

            const SizedBox(height: 24),

            _buildRequestsSection(),

            const SizedBox(height: 24),

            _buildVerificationCard(),
          ],
        ),
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
                'Modo conductor',
                style: TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isOnline
                    ? 'Listo para conducir'
                    : 'Conéctate cuando estés listo',
                style: const TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 25,
                  height: 1.1,
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
            tooltip: 'Notificaciones',
            onPressed: () {
              _showMessage(
                'Aquí llegarán avisos importantes '
                'para el conductor.',
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

  Widget _buildAvailabilityCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isOnline ? const Color(0xFFEAFBF5) : NexoraColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isOnline ? const Color(0x6635D19A) : NexoraColors.breezeBlue,
        ),
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
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _isOnline
                      ? NexoraColors.mintGreen
                      : NexoraColors.breezeBlue,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _isOnline
                      ? Icons.local_taxi_rounded
                      : Icons.power_settings_new_rounded,
                  color: _isOnline
                      ? NexoraColors.white
                      : NexoraColors.royalBlue,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'Disponible' : 'No disponible',
                      style: const TextStyle(
                        color: NexoraColors.softSand,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline
                          ? 'Puedes recibir solicitudes.'
                          : 'No recibirás solicitudes de viaje.',
                      style: const TextStyle(
                        color: NexoraColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: _isOnline,
                activeThumbColor: NexoraColors.mintGreen,
                onChanged: _changeAvailability,
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _changeAvailability(!_isOnline);
              },
              icon: Icon(
                _isOnline
                    ? Icons.pause_rounded
                    : Icons.power_settings_new_rounded,
              ),
              label: Text(_isOnline ? 'Dejar de recibir viajes' : 'Conectarme'),
              style: FilledButton.styleFrom(
                backgroundColor: _isOnline
                    ? NexoraColors.softSand
                    : NexoraColors.royalBlue,
                foregroundColor: NexoraColors.white,
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

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.route_rounded,
            label: 'Viajes',
            value: '$_ridesToday',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_outlined,
            label: 'Ganancias',
            value: 'S/ ${_earningsToday.toStringAsFixed(2)}',
          ),
        ),

        const SizedBox(width: 10),

        const Expanded(
          child: _SummaryCard(
            icon: Icons.star_rounded,
            label: 'Calificación',
            value: '—',
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsCard() {
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
              Icon(
                Icons.account_balance_wallet_rounded,
                color: NexoraColors.mintGreen,
              ),
              SizedBox(width: 9),
              Text(
                'Créditos MIGO',
                style: TextStyle(
                  color: NexoraColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_credits',
                style: const TextStyle(
                  color: NexoraColors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'créditos',
                  style: TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Los créditos se consumirán solamente '
            'en viajes completados según las reglas '
            'del sistema MIGO.',
            style: TextStyle(
              color: Color(0xFFDCE8FF),
              fontSize: 12,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 17),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showMessage(
                  'La recarga de créditos se conectará '
                  'al sistema de pagos.',
                );
              },
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Recargar créditos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NexoraColors.white,
                side: const BorderSide(color: NexoraColors.mintGreen),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Solicitudes cercanas',
                style: TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _showMessage(
                  'Aquí abriremos la lista completa '
                  'de solicitudes.',
                );
              },
              child: const Text('Ver todas'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (!_isOnline) _buildOfflineRequests() else _buildPrototypeRequest(),
      ],
    );
  }

  Widget _buildOfflineRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NexoraColors.breezeBlue),
      ),
      child: const Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: NexoraColors.mutedText, size: 38),
          SizedBox(height: 12),
          Text(
            'Estás desconectado',
            style: TextStyle(
              color: NexoraColors.softSand,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Conéctate para empezar a recibir '
            'solicitudes cercanas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NexoraColors.mutedText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrototypeRequest() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NexoraColors.breezeBlue),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100B1F3D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
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
                      'Pasajero cercano',
                      style: TextStyle(
                        color: NexoraColors.softSand,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '4.9 ★  •  1.2 km de ti',
                      style: TextStyle(
                        color: NexoraColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'S/ 18.50',
                style: TextStyle(
                  color: NexoraColors.royalBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const _TripLocationRow(
            icon: Icons.trip_origin_rounded,
            color: NexoraColors.mintGreen,
            label: 'Recojo',
            value: 'Ubicación de pasajero',
          ),

          const SizedBox(height: 12),

          const _TripLocationRow(
            icon: Icons.location_on_rounded,
            color: NexoraColors.royalBlue,
            label: 'Destino',
            value: 'Destino solicitado',
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showMessage(
                      'Aquí el conductor podrá '
                      'realizar una contraoferta.',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexoraColors.royalBlue,
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: NexoraColors.royalBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Contraoferta'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: FilledButton(
                  onPressed: () {
                    _showMessage(
                      'La aceptación real será '
                      'validada por el servidor.',
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraColors.royalBlue,
                    foregroundColor: NexoraColors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
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
                  'Conductor verificado',
                  style: TextStyle(
                    color: NexoraColors.softSand,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'En producción, MIGO verificará '
                  'desde el servidor que tu identidad, '
                  'licencia, vehículo y documentos '
                  'estén aprobados y vigentes.',
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

  void _changeAvailability(bool value) {
    if (value && _credits <= 0) {
      _showMessage(
        'Necesitas créditos disponibles '
        'para conectarte.',
      );
      return;
    }

    setState(() {
      _isOnline = value;
    });

    _showMessage(
      value
          ? 'Modo disponible activado.'
          : 'Ya no recibirás nuevas solicitudes.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexoraColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NexoraColors.breezeBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NexoraColors.royalBlue, size: 24),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: NexoraColors.softSand,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: NexoraColors.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TripLocationRow extends StatelessWidget {
  const _TripLocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 21),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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
