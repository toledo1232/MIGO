import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'features/home/presentation/passenger_home_screen.dart';

class NexoraPassengerApp extends StatelessWidget {
  const NexoraPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXORA MOVE',
      debugShowCheckedModeBanner: false,
      theme: NexoraTheme.light,
      home: const PassengerHomeScreen(),
    );
  }
}
