import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/error/app_failure.dart';
import '../../core/theme/app_spacing.dart';
import 'automotive_loader.dart';
import 'premium_button.dart';
import 'vehicle_silhouette.dart';

/// Shared layout for "nothing here" and "something went wrong".
///
/// Both need the same ingredients: a calm visual, a plain-language headline, an
/// optional explanation, and - crucially - a clear next action. Keeping them in
/// one widget is what stops the app from showing dead ends.
class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.visual,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIcon,
  });

  final Widget visual;
  final String title;
  final String? message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        // Keeps content reachable on short screens and at large font scales
        // instead of overflowing.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(width: 168, height: 76, child: visual),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
              ),
            ],
            if (primaryLabel != null && onPrimary != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(
                label: primaryLabel!,
                onPressed: onPrimary,
                expand: false,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: onSecondary,
                icon: Icon(secondaryIcon ?? Icons.open_in_new_rounded),
                label: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nothing to show, and that is a normal outcome rather than a failure.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIcon,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData? secondaryActionIcon;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      visual: icon == null
          ? VehicleSilhouette(
              color: context.brand.textTertiary.withValues(alpha: 0.5),
            )
          : Icon(
              icon,
              size: 56,
              color: context.brand.textTertiary.withValues(alpha: 0.6),
            ),
      title: title,
      message: message,
      primaryLabel: actionLabel,
      onPrimary: onAction,
      secondaryLabel: secondaryActionLabel,
      onSecondary: onSecondaryAction,
      secondaryIcon: secondaryActionIcon,
    );
  }
}

/// A failure, with a single obvious way forward.
///
/// The technical detail is shown only in debug builds - a user never sees a
/// stack trace or a socket error.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.debugDetail,
    this.isLoading = false,
  });

  /// Builds from an [AppFailure] so every screen presents failures identically.
  factory ErrorState.fromFailure({
    Key? key,
    required String title,
    required AppFailure failure,
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
    bool isLoading = false,
  }) {
    return ErrorState(
      key: key,
      title: title,
      message: failure.message,
      onRetry: onRetry,
      retryLabel: retryLabel,
      debugDetail: failure.debugDetail,
      isLoading: isLoading,
    );
  }

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? debugDetail;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      visual: isLoading
          ? const AutomotiveLoader(size: 64, strokeWidth: 2.4)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: context.brand.danger.withValues(alpha: 0.8),
                ),
                const SizedBox(height: AppSpacing.xs),
                VehicleSilhouette(
                  color: context.brand.textTertiary.withValues(alpha: 0.3),
                ),
              ],
            ),
      title: title,
      message: message,
      primaryLabel: onRetry == null ? null : retryLabel,
      onPrimary: onRetry,
    );
  }
}

/// Full-page loading. Prefer skeletons at the call site; this is for when the
/// shape of the content is genuinely unknown.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AutomotiveLoader(
        size: 56,
        strokeWidth: 2.2,
        showLabel: true,
        label: label,
      ),
    );
  }
}
