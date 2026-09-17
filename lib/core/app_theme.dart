import 'package:flutter/material.dart';

class AppTheme {
  static const _darkBg = Color(0xFF070912);
  static const _darkSurface = Color(0xFF0F1422);
  static const _lightBg = Color(0xFFF5F7FF);

  static ThemeData themeFor(String preset, Brightness systemBrightness) {
    if (preset == 'system') return presetTheme('system', systemBrightness);
    final dark = preset == 'dark' || preset == 'ocean' || preset == 'forest';
    return presetTheme(preset, dark ? Brightness.dark : Brightness.light);
  }

  static ThemeData presetTheme(String preset, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final (seed, secondary, tertiary) = switch (preset) {
      'ocean' => (const Color(0xFF18E7FF), const Color(0xFF2F7BFF), const Color(0xFF7B61FF)),
      'forest' => (const Color(0xFFB6FF3B), const Color(0xFF00F5A0), const Color(0xFF27E7FF)),
      'sunset' => (const Color(0xFFFF5E9C), const Color(0xFFFF9F43), const Color(0xFFFFD166)),
      'lavender' => (const Color(0xFF9B6CFF), const Color(0xFFFF4FD8), const Color(0xFF27E7FF)),
      'light' => (const Color(0xFF655CFF), const Color(0xFFFF4FD8), const Color(0xFF00CFE8)),
      'dark' => (const Color(0xFF27E7FF), const Color(0xFFFF4FD8), const Color(0xFFB6FF3B)),
      _ => (const Color(0xFF655CFF), const Color(0xFFFF4FD8), const Color(0xFF27E7FF)),
    };

    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = base.copyWith(
      primary: seed,
      onPrimary: dark ? const Color(0xFF061018) : Colors.white,
      secondary: secondary,
      tertiary: tertiary,
      surface: dark ? _darkSurface : _lightBg,
      surfaceContainerLowest: dark ? const Color(0xFF080B13) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF0C111C) : const Color(0xFFFBFCFF),
      surfaceContainer: dark ? const Color(0xFF121827) : Colors.white,
      surfaceContainerHigh: dark ? const Color(0xFF182033) : const Color(0xFFEFF2FF),
      surfaceContainerHighest: dark ? const Color(0xFF202A40) : const Color(0xFFE8EBF9),
      outlineVariant: dark ? const Color(0xFF34405A) : const Color(0xFFD4D8E7),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? _darkBg : _lightBg,
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.8, color: scheme.onSurface),
        displaySmall: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.2, color: scheme.onSurface),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, color: scheme.onSurface),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.8, color: scheme.onSurface),
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5, color: scheme.onSurface),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.3, color: scheme.onSurface),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
        bodyLarge: TextStyle(height: 1.4, color: scheme.onSurface),
        bodyMedium: TextStyle(height: 1.4, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
        labelMedium: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: dark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF111725) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: dark ? _darkSurface : Colors.white, indicatorColor: scheme.primaryContainer),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }

  static ThemeData get darkTheme => themeFor('dark', Brightness.dark);
  static ThemeData get lightTheme => themeFor('light', Brightness.light);
}
