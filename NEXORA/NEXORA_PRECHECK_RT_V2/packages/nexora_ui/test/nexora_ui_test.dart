import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_ui/nexora_ui.dart';

void main() {
  test('NEXORA mantiene su color azul principal', () {
    expect(NexoraColors.deepBlue, const Color(0xFF0B1F3A));
  });
}
