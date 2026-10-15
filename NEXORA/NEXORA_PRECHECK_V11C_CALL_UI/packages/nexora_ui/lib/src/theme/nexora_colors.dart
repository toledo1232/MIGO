import 'package:flutter/material.dart';

abstract final class NexoraColors {
  // -------------------------------------------------------
  // MIGO DRIVE - PALETA OFICIAL
  // -------------------------------------------------------

  static const Color royalBlue = Color(0xFF1E4BFF);

  static const Color mintGreen = Color(0xFF35D19A);

  static const Color breezeBlue = Color(0xFFDCE8FF);

  static const Color warmCream = Color(0xFFFFF7E6);

  static const Color softSand = Color(0xFF0B1F3D);

  // -------------------------------------------------------
  // ALIASES TEMPORALES
  // Permiten migrar la interfaz sin romper componentes.
  // -------------------------------------------------------

  static const Color deepBlue = softSand;

  static const Color turquoise = mintGreen;

  static const Color secondaryBlue = royalBlue;

  static const Color lightGray = Color(0xFFF8FAFF);

  static const Color darkGray = softSand;

  static const Color white = Color(0xFFFFFFFF);

  static const Color border = breezeBlue;

  static const Color mutedText = Color(0xFF667085);

  static const Color warning = Color(0xFFF4B740);

  static const Color emergency = Color(0xFFD92D20);
}
