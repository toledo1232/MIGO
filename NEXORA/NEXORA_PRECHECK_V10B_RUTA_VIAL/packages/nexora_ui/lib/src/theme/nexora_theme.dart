import 'package:flutter/material.dart';

import 'nexora_colors.dart';

abstract final class NexoraTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: NexoraColors.deepBlue,
      onPrimary: NexoraColors.white,
      secondary: NexoraColors.turquoise,
      onSecondary: NexoraColors.deepBlue,
      error: NexoraColors.emergency,
      onError: NexoraColors.white,
      surface: NexoraColors.white,
      onSurface: NexoraColors.darkGray,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NexoraColors.lightGray,

      appBarTheme: const AppBarTheme(
        backgroundColor: NexoraColors.lightGray,
        foregroundColor: NexoraColors.deepBlue,
        centerTitle: false,
        elevation: 0,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: NexoraColors.turquoise,
          foregroundColor: NexoraColors.deepBlue,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: NexoraColors.deepBlue,
          side: const BorderSide(color: NexoraColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NexoraColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NexoraColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NexoraColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NexoraColors.turquoise, width: 2),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: NexoraColors.white,
        indicatorColor: Color(0x3300BFA6),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
