import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Applies component-level theme styles to [base].
///
/// Kept out of `AppTheme` so the base theme stays readable and each group of
/// component styles can be reviewed on its own.
ThemeData applyComponentThemes(
  ThemeData base, {
  required bool isDark,
  required Color surface,
  required Color surfaceRaised,
  required Color outline,
  required Color textPrimary,
  required Color textSecondary,
}) {
  final TextTheme text = base.textTheme;

  return base.copyWith(
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: outline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceRaised,
      selectedColor: AppColors.accent,
      side: BorderSide(color: outline),
      labelStyle: text.labelMedium!,
      secondaryLabelStyle: text.labelMedium!.copyWith(color: Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceRaised,
      hintStyle: text.bodyMedium?.copyWith(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.dangerBright, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: isDark ? const Color(0xFF1A1005) : Colors.white,
        disabledBackgroundColor: surfaceRaised,
        disabledForegroundColor: textSecondary,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        side: BorderSide(color: outline),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textPrimary,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
      selectedLabelStyle: text.labelSmall?.copyWith(
        color: AppColors.accent,
        letterSpacing: 0.6,
      ),
      unselectedLabelStyle: text.labelSmall?.copyWith(
        color: textSecondary,
        letterSpacing: 0.6,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accent.withValues(alpha: 0.16),
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(text.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? AppColors.accent : textSecondary,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColors.darkSurfaceOverlay : AppColors.lightTextPrimary,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceOverlay : AppColors.lightTextPrimary,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      textStyle: text.bodySmall?.copyWith(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightSurface,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.darkOutline,
      circularTrackColor: AppColors.darkOutline,
    ),
  );
}
