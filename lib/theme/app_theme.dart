import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ivoire,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.rougePrincipal,
        primary: AppColors.rougePrincipal,
        secondary: AppColors.rougeSecondaire,
        surface: AppColors.ivoire,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivoire,
        foregroundColor: AppColors.bordeauxProfond,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: AppColors.bordeauxProfond, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.bordeauxProfond, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Colors.black87),
        bodySmall: TextStyle(color: AppColors.grisDoux),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rougePrincipal,
          foregroundColor: AppColors.ivoire,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bleuCielDoux,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.grisDoux),
      ),
    );
  }
}