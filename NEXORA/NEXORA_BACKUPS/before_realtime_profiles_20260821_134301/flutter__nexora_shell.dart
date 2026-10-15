import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../app/app_session.dart';
import '../account/mode_account_view.dart';
import '../driver/home/driver_home_view.dart';
import '../driver/requests/driver_requests_view.dart';
import '../passenger/home/passenger_home_view.dart';

class NexoraShell extends StatefulWidget {
  const NexoraShell({required this.session, super.key});

  final AppSession session;

  @override
  State<NexoraShell> createState() => _NexoraShellState();
}

class _NexoraShellState extends State<NexoraShell> {
  int _selectedIndex = 0;

  void _changeMode(AppMode targetMode) {
    bool success = true;

    if (targetMode == AppMode.driver) {
      success = widget.session.switchToDriver();
    } else {
      widget.session.switchToPassenger();
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu perfil de conductor todavía no está aprobado.'),
        ),
      );

      return;
    }

    setState(() {
      _selectedIndex = 0;
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, child) {
        final bool passenger = widget.session.mode == AppMode.passenger;

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
            title: const MigoBrandMark(compact: true),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: passenger
                      ? const Color(0x1A00BFA6)
                      : const Color(0x1A2563EB),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  passenger ? 'Pasajero' : 'Conductor',
                  style: const TextStyle(
                    color: NexoraColors.deepBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          drawer: _NexoraDrawer(
            session: widget.session,
            onSwitchMode: _changeMode,
          ),
          body: _buildBody(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: passenger
                ? const [
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
                      key: ValueKey('account-tab'),
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Cuenta',
                    ),
                  ]
                : const [
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
                      key: ValueKey('account-tab'),
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Cuenta',
                    ),
                  ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    final bool passenger = widget.session.mode == AppMode.passenger;

    if (_selectedIndex == 4) {
      return ModeAccountView(
        session: widget.session,
        onSwitchMode: _changeMode,
      );
    }

    if (!passenger && _selectedIndex == 1) {
      return const DriverRequestsView();
    }

    if (_selectedIndex != 0) {
      return _PlaceholderView(title: _currentSectionName());
    }

    if (passenger) {
      return const PassengerHomeView();
    }

    return const DriverHomeView();
  }

  String _currentSectionName() {
    final bool passenger = widget.session.mode == AppMode.passenger;

    final List<String> sections = passenger
        ? ['Inicio', 'Mis viajes', 'Seguridad', 'Promociones', 'Cuenta']
        : ['Inicio', 'Solicitudes', 'Rendimiento', 'Billetera', 'Cuenta'];

    return sections[_selectedIndex];
  }
}

class _NexoraDrawer extends StatelessWidget {
  const _NexoraDrawer({required this.session, required this.onSwitchMode});

  final AppSession session;
  final ValueChanged<AppMode> onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final bool passenger = session.mode == AppMode.passenger;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(20), child: MigoBrandMark()),
            const Divider(),
            ListTile(
              leading: Icon(
                passenger
                    ? Icons.local_taxi_rounded
                    : Icons.person_pin_circle_rounded,
                color: NexoraColors.turquoise,
              ),
              title: Text(
                passenger
                    ? 'Cambiar a modo conductor'
                    : 'Cambiar a modo pasajero',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Usa la misma cuenta MIGO.'),
              trailing: const Icon(Icons.swap_horiz_rounded),
              onTap: () {
                onSwitchMode(passenger ? AppMode.driver : AppMode.passenger);
              },
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Mi perfil'),
            ),
            const ListTile(
              leading: Icon(Icons.help_outline_rounded),
              title: Text('Ayuda'),
            ),
            const ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Configuración'),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                passenger ? 'Modo actual: Pasajero' : 'Modo actual: Conductor',
                style: const TextStyle(
                  color: NexoraColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_rounded,
              size: 48,
              color: NexoraColors.turquoise,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: NexoraColors.deepBlue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Esta sección se construirá en los próximos módulos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NexoraColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
