import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../motion/pressable_scale.dart';

/// Visual weight of a [PremiumButton].
enum PremiumButtonVariant {
  /// The single primary action on a screen. Copper fill.
  primary,

  /// Secondary action. Outlined, same hit area.
  secondary,

  /// Tertiary/low-emphasis. Text only.
  ghost,

  /// Destructive action. Red-tinted, never the default.
  danger,
}

enum PremiumButtonSize { small, medium, large }

/// The application button.
///
/// Wraps every variant in [PressableScale] so press feedback is identical
/// everywhere, guarantees a minimum 48dp touch target, and adapts its width to
/// its content — full width only when asked, so a row of buttons never gets
/// stretched into unreadable slabs.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.size = PremiumButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
    this.semanticHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final PremiumButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Stretch to the full width of the parent (primary CTAs on narrow screens).
  final bool expand;

  /// Shows a spinner and blocks interaction without changing the button's
  /// width, so a long press does not reflow the layout.
  final bool loading;

  final String? semanticHint;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _foreground(context);
    final Color background = _background(context);
    final Color border = _border(context);

    final double height = switch (size) {
      PremiumButtonSize.small => 36,
      PremiumButtonSize.medium => AppSpacing.minTouchTarget,
      PremiumButtonSize.large => 56,
    };

    final Widget content = _buildContent(context, foreground);

    final Widget button = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: size == PremiumButtonSize.small ? 16 : 24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: border == Colors.transparent ? null : Border.all(color: border),
      ),
      child: Center(
        widthFactor: expand ? null : 1.0,
        child: loading
            ? SizedBox.square(
                dimension: size == PremiumButtonSize.small ? 16 : 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              )
            : content,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      hint: semanticHint,
      child: PressableScale(
        onTap: _enabled ? onPressed : null,
        pressedScale: 0.97,
        excludedFromSemantics: true,
        child: button,
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color foreground) {
    final TextStyle? textStyle = switch (size) {
      PremiumButtonSize.small => context.text.labelMedium,
      PremiumButtonSize.large => context.text.labelLarge?.copyWith(fontSize: 16),
      PremiumButtonSize.medium => context.text.labelLarge,
    };

    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle?.copyWith(color: foreground),
    );

    if (icon == null && trailingIcon == null) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: text),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18, color: foreground),
        ],
      ],
    );
  }

  Color _background(BuildContext context) {
    final bool enabled = _enabled;
    return switch (variant) {
      PremiumButtonVariant.primary => enabled
          ? context.brand.accent
          : context.brand.surfaceRaised,
      PremiumButtonVariant.secondary => context.brand.surface,
      PremiumButtonVariant.ghost => Colors.transparent,
      PremiumButtonVariant.danger => enabled
          ? context.brand.danger.withValues(alpha: 0.16)
          : context.brand.surfaceRaised,
    };
  }

  Color _foreground(BuildContext context) {
    if (!_enabled) return context.brand.textTertiary;
    return switch (variant) {
      PremiumButtonVariant.primary => context.isDarkMode
          ? const Color(0xFF1A1005)
          : Colors.white,
      PremiumButtonVariant.secondary => context.brand.textPrimary,
      PremiumButtonVariant.ghost => context.brand.accent,
      PremiumButtonVariant.danger => context.brand.danger,
    };
  }

  Color _border(BuildContext context) => switch (variant) {
    PremiumButtonVariant.primary => Colors.transparent,
    PremiumButtonVariant.secondary => context.brand.outline,
    PremiumButtonVariant.ghost => Colors.transparent,
    PremiumButtonVariant.danger => context.brand.danger.withValues(alpha: 0.45),
  };
}
