import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';

/// Vehicle entrance animation: a controlled drive-in reveal.
///
/// A car pulling away from the line of sight and settling into frame, rather
/// than a generic fade. Implemented as a transform + opacity tween driven by a
/// single [AnimationController] so it costs one repaint per frame and never
/// rebuilds the subtree.
///
/// Set [delay] to stagger a list of vehicles so they arrive in sequence.
class DriveInReveal extends StatefulWidget {
  const DriveInReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = AppMotion.driveInOffset,
    this.fromLeft = true,
    this.duration = AppMotion.enter,
  });

  final Widget child;

  /// Stagger offset applied before the reveal starts.
  final Duration delay;

  /// Fraction of the child's width the vehicle travels. Kept small on purpose:
  /// a large slide reads as a cartoon, not as weight.
  final double offset;

  /// Direction the vehicle enters from.
  final bool fromLeft;

  final Duration duration;

  @override
  State<DriveInReveal> createState() => _DriveInRevealState();
}

class _DriveInRevealState extends State<DriveInReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      // The controller must own the duration; `forward()` with no duration is
      // an assertion failure in debug builds.
      duration: widget.duration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.driveIn,
    ).drive(Tween<double>(begin: 0, end: 1));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // Deferred so the delay is applied once, without a Timer leak.
      Future<void>.delayed(widget.delay).then((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "remove animations" setting: show the content immediately.
    if (context.prefersReducedMotion) return widget.child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (BuildContext context, Widget? child) {
          final double t = _progress.value;
          // FractionalTranslation resolves against the child's own size, so the
          // travel is proportional on every screen without a LayoutBuilder.
          final double dx = (widget.fromLeft ? -1 : 1) * widget.offset * (1 - t);

          return Opacity(
            // Opacity starts just above zero so there is no hard pop.
            opacity: 0.001 + 0.999 * Curves.easeOut.transform(t),
            child: FractionalTranslation(
              // Slight settle-in scale: a car arriving has weight.
              translation: Offset(dx, 0),
              transformHitTests: false,
              child: Transform.scale(
                scale: 1 - 0.02 * (1 - t),
                alignment: widget.fromLeft ? Alignment.centerLeft : Alignment.centerRight,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Staggers a list of children with [DriveInReveal].
///
/// The delay grows sub-linearly so a long list does not take seconds to finish
/// revealing.
class StaggeredDriveIn extends StatelessWidget {
  const StaggeredDriveIn({
    super.key,
    required this.children,
    this.stagger = const Duration(milliseconds: 70),
    this.initialDelay = Duration.zero,
  });

  final List<Widget> children;
  final Duration stagger;
  final Duration initialDelay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          DriveInReveal(
            key: ValueKey<int>(i),
            delay: initialDelay + stagger * i,
            child: children[i],
          ),
      ],
    );
  }
}
