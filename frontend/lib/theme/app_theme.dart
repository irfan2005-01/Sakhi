import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Refined Clinical Palette
  static const Color ivoryBackground = Color(0xFFFBF9F5);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color forestGreen = Color(0xFF244434);
  static const Color sageGreen = Color(0xFF3B644F);
  static const Color sageGreenLight = Color(0xFFEEF4F0);
  static const Color sageGreenMedium = Color(0xFF8BA796);
  static const Color charcoal = Color(0xFF1E2621);
  static const Color charcoalMuted = Color(0xFF5A6660);
  static const Color charcoalLight = Color(0xFF88968F);
  static const Color lavenderAccent = Color(0xFF7B6291);
  static const Color lavenderLight = Color(0xFFF4EFF8);
  static const Color emergencyRed = Color(0xFFC24141);
  static const Color emergencyRedLight = Color(0xFFFDF2F2);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color warningOrangeLight = Color(0xFFFEF3C7);
  static const Color borderColor = Color(0xFFE5EAE6);
  static const Color borderSubtle = Color(0xFFEFF2F0);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ivoryBackground,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sageGreen,
        onPrimary: Colors.white,
        primaryContainer: AppColors.sageGreenLight,
        onPrimaryContainer: AppColors.forestGreen,
        secondary: AppColors.lavenderAccent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.lavenderLight,
        surface: AppColors.cardSurface,
        onSurface: AppColors.charcoal,
        error: AppColors.emergencyRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ivoryBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
          color: AppColors.charcoal,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sageGreen,
          side: const BorderSide(color: AppColors.sageGreen, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
        hintStyle: TextStyle(color: AppColors.charcoalLight, fontSize: 13.5),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
