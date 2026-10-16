import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';

/// Layered, low-key motion for a hero vehicle.
///
/// Two independent layers, the way a real photograph of a car has a subject and
/// a background:
///  * **Parallax** — the background plate drifts slower than the foreground as
///    the page scrolls, which produces depth. Driven by an external
///    [ScrollController] so it costs nothing while idle.
///  * **Breathing** — an extremely small, very slow scale pulse. This is the
///    only continuous animation in the app and it is deliberately near the
///    threshold of perception: it stops the hero looking like a flat image
///    without ever reading as "bouncing".
///
/// Both are disabled when the OS requests reduced motion.
class ShowcaseParallax extends StatefulWidget {
  const ShowcaseParallax({
    super.key,
    required this.child,
    this.background,
    this.scrollController,
    this.parallaxStrength = 0.12,
    this.enableBreathing = true,
  });

  /// Foreground layer: the vehicle.
  final Widget child;

  /// Optional slower layer behind [child] (studio backdrop, road, lighting).
  final Widget? background;

  /// When supplied, the layers react to this scroll position.
  final ScrollController? scrollController;

  /// How far the layers separate at full scroll travel.
  final double parallaxStrength;

  final bool enableBreathing;

  @override
  State<ShowcaseParallax> createState() => _ShowcaseParallaxState();
}

class _ShowcaseParallaxState extends State<ShowcaseParallax>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  /// The controller currently being observed, or null when the widget is used
  /// outside a scrollable (in which case parallax is simply inert).
  ScrollController? _observed;

  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _breath = AnimationController(
      vsync: this,
      duration: AppMotion.showcaseCycle,
    )..repeat(reverse: true);

    _attach(widget.scrollController);
  }

  @override
  void didUpdateWidget(ShowcaseParallax oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      _attach(widget.scrollController);
    }
  }

  void _attach(ScrollController? controller) {
    _observed?.removeListener(_handleScroll);
    _observed = controller;
    _scrollOffset = 0;
    _observed?.addListener(_handleScroll);
  }

  void _handleScroll() {
    final ScrollController? controller = _observed;
    if (controller == null || !controller.hasClients) return;
    // Store a scalar and rebuild nothing; the transform below reads it during
    // the existing animation tick.
    _scrollOffset = controller.offset;
  }

  @override
  void dispose() {
    _observed?.removeListener(_handleScroll);
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.prefersReducedMotion) {
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[if (widget.background != null) widget.background!, widget.child],
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_breath, ?_observed]),
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        // Breathing: sine easing keeps the turnaround soft, not mechanical.
        final double breathT = Curves.easeInOutSine.transform(_breath.value);
        final double scale =
            widget.enableBreathing ? 1 + (AppMotion.showcaseScale - 1) * breathT : 1.0;

        // Parallax: the foreground travels further than the background, so the
        // two layers separate as the page moves.
        final double offset = _scrollOffset * widget.parallaxStrength;

        return Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            if (widget.background != null)
              Transform.translate(offset: Offset(-offset * 0.35, 0), child: widget.background),
            Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Transform.translate(offset: Offset(-offset, 0), child: child),
            ),
          ],
        );
      },
    );
  }
}
