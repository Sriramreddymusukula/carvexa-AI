import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/pointer_capability.dart';

/// Press and hover feedback for any tappable surface.
///
/// Every interactive card, button and chip in the app uses this so touch
/// feedback is identical everywhere. It also provides a **guaranteed visible
/// state** for assistive technology and for users who cannot rely on the
/// ripple, which matters for the "never leave the user wondering whether their
/// action worked" requirement.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = AppMotion.pressScale,
    this.enableHover = true,
    this.hoverElevation,
    this.semanticLabel,
    this.semanticHint,
    this.excludedFromSemantics = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  /// Hover is only wired up on devices that actually have a pointer.
  final bool enableHover;

  /// Optional extra shadow applied while hovered.
  final List<BoxShadow>? hoverElevation;

  final String? semanticLabel;
  final String? semanticHint;

  /// Set when the child already carries the semantics (e.g. a button).
  final bool excludedFromSemantics;

  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    final bool enabled = widget.enableHover && PointerCapability.supportsHover(context);
    final bool next = enabled && value;
    if (_hovered == next) return;
    setState(() => _hovered = next);
  }

  @override
  Widget build(BuildContext context) {
    final Widget scaled = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.press,
      child: widget.child,
    );

    final Widget elevated =
        (_hovered && widget.hoverElevation != null)
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              boxShadow: widget.hoverElevation,
            ),
            child: scaled,
          )
        : scaled;

    Widget interactive = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      child: elevated,
    );

    // A single MouseRegion covers enter/exit and is inert on touch devices.
    interactive = MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: interactive,
    );

    if (widget.excludedFromSemantics || widget.semanticLabel == null) {
      return interactive;
    }

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: interactive,
    );
  }
}
