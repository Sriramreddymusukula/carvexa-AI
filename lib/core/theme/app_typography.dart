import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for the application.
///
/// Design intent: automotive brands set short, wide, confident headlines and
/// compact, dense labels. Negative letter-spacing on large sizes and positive
/// letter-spacing on small caps-style labels is what makes the result read as
/// "automotive" rather than "generic app".
///
/// The scale uses the platform font family on purpose. Bundling a custom face
/// would add megabytes to the APK and a network/runtime dependency for no
/// functional gain; hierarchy, weight and tracking do the design work here.
abstract final class AppTypography {
  static const String _family = 'Roboto';

  static const TextTheme textTheme = TextTheme(
    // ---- Display: hero vehicle names, splash --------------------------
    displayLarge: TextStyle(
      fontFamily: _family,
      fontSize: 40,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: AppColors.darkTextPrimary,
    ),
    displayMedium: TextStyle(
      fontFamily: _family,
      fontSize: 32,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
      color: AppColors.darkTextPrimary,
    ),
    displaySmall: TextStyle(
      fontFamily: _family,
      fontSize: 28,
      height: 1.16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.darkTextPrimary,
    ),

    // ---- Headline: screen titles, section headers ---------------------
    headlineLarge: TextStyle(
      fontFamily: _family,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.darkTextPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: _family,
      fontSize: 20,
      height: 1.24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.darkTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _family,
      fontSize: 18,
      height: 1.28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.darkTextPrimary,
    ),

    // ---- Title: card titles, list rows --------------------------------
    titleLarge: TextStyle(
      fontFamily: _family,
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _family,
      fontSize: 15,
      height: 1.34,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: _family,
      fontSize: 13,
      height: 1.36,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextSecondary,
    ),

    // ---- Body ----------------------------------------------------------
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: _family,
      fontSize: 12.5,
      height: 1.42,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextSecondary,
    ),

    // ---- Label: buttons, chips, metadata -------------------------------
    labelLarge: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: _family,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
    labelSmall: TextStyle(
      fontFamily: _family,
      fontSize: 10.5,
      height: 1.2,
      fontWeight: FontWeight.w700,
      // Wide tracking on small labels is the classic automotive "spec plate"
      // treatment.
      letterSpacing: 1.1,
    ),
  );

  /// Overline used above section titles.
  static const TextStyle overline = TextStyle(
    fontFamily: _family,
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.accent,
  );

  /// Tabular figures for prices and specs so columns stay aligned.
  static const TextStyle numeric = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
