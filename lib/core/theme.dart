import 'package:flutter/material.dart';
import 'style/app_colors.dart';
import 'style/app_text_styles.dart';
import 'style/app_dimensions.dart';

/// Assembles raw [AppColors] / [AppTextStyles] into [ThemeData].
/// Static field aliases below are kept so legacy call-sites keep compiling.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondaryColor = AppColors.secondary;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;
  static const Color errorColor = AppColors.error;

  static const Color darkBackground = AppColors.darkBackground;
  static const Color darkCard = AppColors.darkCard;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color lightBackground = AppColors.lightBackground;
  static const Color lightCard = AppColors.lightCard;
  static const Color lightSurface = AppColors.lightSurface;

  static const Color darkTextPrimary = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;
  static const Color darkTextHint = AppColors.darkTextHint;
  static const Color lightTextPrimary = AppColors.lightTextPrimary;
  static const Color lightTextSecondary = AppColors.lightTextSecondary;
  static const Color lightTextHint = AppColors.lightTextHint;

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        card: AppColors.darkCard,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        textHint: AppColors.darkTextHint,
        border: AppColors.darkBorder,
        fieldFill: Colors.white.withValues(alpha: 0.05),
        navBackground: AppColors.darkCard,
        cardElevation: 0,
      );

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        card: AppColors.lightCard,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        textHint: AppColors.lightTextHint,
        border: AppColors.lightBorder,
        fieldFill: Colors.grey.shade100,
        navBackground: Colors.white,
        cardElevation: 2,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textHint,
    required Color border,
    required Color fieldFill,
    required Color navBackground,
    required double cardElevation,
  }) {
    return ThemeData(
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: background,
      cardColor: card,
      cardTheme: CardThemeData(
        color: card,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBar(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        hintStyle: TextStyle(color: textHint),
        labelStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            vertical: AppDimensions.buttonPaddingV,
            horizontal: AppDimensions.buttonPaddingH,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headlineLarge(color: textPrimary),
        headlineMedium: AppTextStyles.headlineMedium(color: textPrimary),
        titleLarge: AppTextStyles.titleLarge(color: textPrimary),
        titleMedium: AppTextStyles.titleMedium(color: textPrimary),
        bodyLarge: AppTextStyles.bodyLarge(color: textPrimary),
        bodyMedium: AppTextStyles.bodyMedium(color: textSecondary),
        bodySmall: AppTextStyles.bodySmall(color: textHint),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

extension ThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get adaptiveCardColor =>
      isDarkMode ? AppColors.darkCard : AppColors.lightCard;

  Color get adaptiveTextPrimary =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

  Color get adaptiveTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  Color get adaptiveHintColor =>
      isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint;

  Color get adaptiveBackground =>
      isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
}
