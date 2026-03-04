import 'package:flutter/material.dart';

class AppColors {
  static const Color upSegment = Color(0xFFE54B4B);
  static const Color downSegment = Color(0xFF266DD3);
  static const Color action = Color(0xFF5677E7);
  static const Color background = Color(0xFF1E1E24);
  static const Color helperText = Color(0xFFCCDBDC);
  static const Color surface = Color(0xFF24242D);
}

class AppTheme {
  static ThemeData get darkTheme {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.action,
      secondary: AppColors.action,
      surface: AppColors.surface,
      error: AppColors.upSegment,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: AppColors.helperText),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.action.withOpacity(0.25),
        iconTheme: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: AppColors.helperText);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: AppColors.helperText);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.helperText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.helperText),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.helperText),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.action, width: 1.4),
        ),
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return AppColors.action;
            }
            return AppColors.surface;
          }),
          foregroundColor: const MaterialStatePropertyAll<Color>(Colors.white),
          side: const MaterialStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.helperText),
          ),
        ),
      ),
    );
  }
}
