import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';

/// A titled block of content with consistent vertical rhythm.
///
/// Replaces ad-hoc `Padding + Text` pairs so every section on every screen is
/// aligned the same way and spacing can be tuned globally.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.action,
  });

  final String title;
  final String? subtitle;

  /// Small label above the title, e.g. "FEATURED".
  final String? overline;

  /// Optional trailing control, usually a "See all" text button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.pageGutter,
        right: AppSpacing.pageGutter,
        bottom: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (overline != null) ...<Widget>[
                  Text(
                    overline!.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: context.brand.accent,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  title,
                  style: context.text.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// The default "See all" affordance for a [SectionHeader].
///
/// Small and secondary on purpose: a whole row of these must never compete
/// with the content.
class SeeAllLink extends StatelessWidget {
  const SeeAllLink({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: context.text.labelMedium?.copyWith(color: context.brand.accent)),
          const SizedBox(width: AppSpacing.xxs),
          Icon(Icons.chevron_right, size: 16, color: context.brand.accent),
        ],
      ),
    );
  }
}
