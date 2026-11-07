import 'package:flutter/material.dart';

/// Palette shared by the premium F1 screens. Selected theme is persisted by F1TrackerApp.
class AppColors {
  static String themeId = 'dark';
  static bool get _light => themeId == 'light';
  static bool get _pitwall => themeId == 'pitwall';
  static Color get background => _light ? const Color(0xFFF2F4F7) : _pitwall ? const Color(0xFF07131B) : const Color(0xFF090A0D);
  static Color get surface => _light ? Colors.white : _pitwall ? const Color(0xFF10212B) : const Color(0xFF14171D);
  static Color get surface2 => _light ? const Color(0xFFE8ECF1) : _pitwall ? const Color(0xFF18303C) : const Color(0xFF1C2028);
  static Color get border => _light ? const Color(0xFFD5DAE2) : _pitwall ? const Color(0xFF24414E) : const Color(0xFF292E38);
  static Color get red => const Color(0xFFE10600);
  static Color get muted => _light ? const Color(0xFF59616D) : const Color(0xFF9299A6);
  static Color get green => _light ? const Color(0xFF16784B) : const Color(0xFF39C98A);
  static Color get amber => _light ? const Color(0xFF8A5D00) : const Color(0xFFFFC247);
}

class AppTheme {
  static ThemeData forId(String id) {
    AppColors.themeId = id;
    final light = id == 'light';
    final background = AppColors.background;
    final surface = AppColors.surface;
    final border = AppColors.border;
    final muted = AppColors.muted;
    final scheme = light
        ? ColorScheme.light(primary: AppColors.red, secondary: const Color(0xFFB8201A), surface: surface, error: const Color(0xFFB3261E))
        : ColorScheme.dark(primary: AppColors.red, secondary: const Color(0xFFFF5B55), surface: surface, error: const Color(0xFFFF625C));
    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: light ? const Color(0xFF15181F) : Colors.white, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border))),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.red.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, color: states.contains(WidgetState.selected) ? (light ? AppColors.red : Colors.white) : muted)),
      ),
    );
  }
  static ThemeData get dark => forId('dark');
  static ThemeData get light => forId('light');
  static ThemeData get pitwall => forId('pitwall');
}
