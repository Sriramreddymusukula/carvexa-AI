import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ergonomic access to the design system from a [BuildContext].
///
/// Screens write `context.colors.surface`, `context.text.body`,
/// `context.brand.accent` instead of threading colours through constructors.
/// Static tokens (spacing, radii, motion) are referenced directly as
/// `AppSpacing.lg`, `AppRadius.md`, `AppMotion.standard` — they are constants,
/// not runtime values, so there is nothing to resolve.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// True when the OS asks for reduced motion (accessibility "remove
  /// animations"). Every non-essential animation in the app checks this.
  bool get prefersReducedMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;

  /// Brand-specific colours that are not part of the Material [ColorScheme].
  BrandPalette get brand => BrandPalette.of(this);
}

/// Resolved brand palette for the current brightness.
class BrandPalette {
  const BrandPalette._({
    required this.accent,
    required this.accentBright,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  factory BrandPalette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  static final BrandPalette _dark = BrandPalette._(
    accent: AppColors.accent,
    accentBright: AppColors.accentBright,
    info: AppColors.info,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    scaffoldBackground: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceRaised,
    surfaceOverlay: AppColors.darkSurfaceOverlay,
    outline: AppColors.darkOutline,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
  );

  static final BrandPalette _light = BrandPalette._(
    accent: AppColors.accentDim,
    accentBright: AppColors.accent,
    info: AppColors.info,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    scaffoldBackground: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceMuted,
    surfaceOverlay: AppColors.lightSurfaceMuted,
    outline: AppColors.lightOutline,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
  );

  final Color accent;
  final Color accentBright;
  final Color info;
  final Color success;
  final Color warning;
  final Color danger;
  final Color scaffoldBackground;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
}

