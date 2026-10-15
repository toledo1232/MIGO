import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'features/home/presentation/driver_home_screen.dart';

class NexoraDriverApp extends StatelessWidget {
  const NexoraDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXORA MOVE Conductor',
      debugShowCheckedModeBanner: false,
      theme: NexoraTheme.light,
      home: const DriverHomeScreen(),
    );
  }
}
