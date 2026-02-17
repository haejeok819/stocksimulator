import 'package:flutter/material.dart';

class AppColors {
  static const Color upSegment = Color(0xFFE54B4B);
  static const Color downSegment = Color(0xFF266DD3);
  static const Color action = Color(0xFF5677E7);
  static const Color background = Color(0xFF1E1E24);
  static const Color helperText = Color(0xFFCCDBDC);
}

class AppTheme {
  static ThemeData get darkTheme {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.action,
      brightness: Brightness.dark,
      background: AppColors.background,
      surface: const Color(0xFF24242D),
    ).copyWith(
      primary: AppColors.action,
      secondary: AppColors.action,
      onSurface: Colors.white,
      onBackground: AppColors.helperText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: AppColors.helperText),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.action,
        inactiveTrackColor: Color(0xFF3B3B46),
        thumbColor: AppColors.action,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
