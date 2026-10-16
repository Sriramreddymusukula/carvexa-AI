import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_component_themes.dart';
import 'app_typography.dart';

/// Assembles the application [ThemeData] from the design-system tokens.
///
/// Screens read colours, spacing and text from the theme; they never construct
/// their own. Component-level styles live in `app_component_themes.dart`.
abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color background = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color surfaceRaised = isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceMuted;
    final Color outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: isDark ? const Color(0xFF1A1005) : Colors.white,
      primaryContainer: AppColors.accentDim,
      onPrimaryContainer: isDark ? AppColors.accentBright : Colors.white,
      secondary: AppColors.info,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF23323D) : const Color(0xFFDCE7EF),
      onSecondaryContainer: isDark ? AppColors.infoBright : const Color(0xFF1B2C38),
      tertiary: AppColors.accentBright,
      onTertiary: const Color(0xFF1A1005),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3A1E1B) : const Color(0xFFF7DEDB),
      onErrorContainer: isDark ? AppColors.dangerBright : const Color(0xFF5A1B14),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: isDark ? AppColors.darkBackground : AppColors.lightSurface,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceRaised,
      surfaceContainerHigh: isDark ? AppColors.darkSurfaceOverlay : AppColors.lightSurfaceMuted,
      surfaceContainerHighest: isDark ? AppColors.darkSurfaceOverlay : AppColors.lightSurfaceMuted,
      onSurfaceVariant: textSecondary,
      outline: outline,
      outlineVariant: isDark ? AppColors.darkOutlineStrong : AppColors.lightOutline,
      shadow: Colors.black,
      scrim: AppColors.scrim,
      inverseSurface: isDark ? AppColors.lightSurface : AppColors.darkSurface,
      onInverseSurface: isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      inversePrimary: AppColors.accentBright,
    );

    // Retint the shared type scale so one scale serves both brightnesses.
    final TextTheme text = AppTypography.textTheme
        .apply(bodyColor: textPrimary, displayColor: textPrimary)
        .copyWith(
          titleMedium: AppTypography.textTheme.titleMedium?.copyWith(color: textPrimary),
          titleSmall: AppTypography.textTheme.titleSmall?.copyWith(color: textSecondary),
          bodyMedium: AppTypography.textTheme.bodyMedium?.copyWith(color: textSecondary),
          bodySmall: AppTypography.textTheme.bodySmall?.copyWith(color: textSecondary),
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    );

    return applyComponentThemes(
      base,
      isDark: isDark,
      surface: surface,
      surfaceRaised: surfaceRaised,
      outline: outline,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
    );
  }
}
