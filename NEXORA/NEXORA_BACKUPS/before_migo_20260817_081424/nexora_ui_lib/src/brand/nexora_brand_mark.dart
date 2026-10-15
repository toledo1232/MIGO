import 'package:flutter/material.dart';

class NexoraBrandMark extends StatelessWidget {
  const NexoraBrandMark({
    super.key,
    this.compact = false,
    this.onDarkBackground = false,
  });

  final bool compact;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/nexora_logo_horizontal.png',
      height: compact ? 38 : 56,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticLabel: 'NEXORA MOVE',
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Text(
              'NEXORA MOVE',
              style: TextStyle(
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.w900,
              ),
            );
          },
    );
  }
}
