import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF090A0D);
  static const surface = Color(0xFF14171D);
  static const surface2 = Color(0xFF1C2028);
  static const border = Color(0xFF292E38);
  static const red = Color(0xFFE10600);
  static const muted = Color(0xFF9299A6);
  static const green = Color(0xFF39C98A);
  static const amber = Color(0xFFFFC247);
}

class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.red,
      secondary: Color(0xFFFF5B55),
      surface: AppColors.surface,
      error: Color(0xFFFF625C),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerColor: AppColors.border,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF101217),
        indicatorColor: AppColors.red.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.muted,
          );
        }),
      ),
    );
  }
}
