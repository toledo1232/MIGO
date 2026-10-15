import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'app/app_session.dart';
import 'features/shell/nexora_shell.dart';

class NexoraApp extends StatefulWidget {
  const NexoraApp({super.key});

  @override
  State<NexoraApp> createState() => _NexoraAppState();
}

class _NexoraAppState extends State<NexoraApp> {
  late final AppSession _session;

  @override
  void initState() {
    super.initState();
    _session = AppSession();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXORA MOVE',
      debugShowCheckedModeBanner: false,
      theme: NexoraTheme.light,
      home: NexoraShell(session: _session),
    );
  }
}
