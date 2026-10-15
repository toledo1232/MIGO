import 'package:flutter/material.dart';

class MigoBrandMark extends StatelessWidget {
  const MigoBrandMark({
    super.key,
    this.compact = false,
    this.onDarkBackground = false,
  });

  final bool compact;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/migo_logo_vertical.png',
      height: compact ? 50 : 76,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticLabel: 'MIGO DRIVE',
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Text(
              'MIGO DRIVE',
              style: TextStyle(fontWeight: FontWeight.w900),
            );
          },
    );
  }
}

// Compatibilidad temporal durante la migracion.
class NexoraBrandMark extends MigoBrandMark {
  const NexoraBrandMark({super.key, super.compact, super.onDarkBackground});
}
