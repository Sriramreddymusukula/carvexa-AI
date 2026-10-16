import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';
import 'vehicle_silhouette.dart';

/// A shimmering placeholder block.
///
/// Used instead of a spinner when the *shape* of the incoming content is
/// known: a skeleton means the user sees the page they are about to get, which
/// is faster and calmer than a spinner on a blank screen.
///
/// One [AnimationController] per skeleton is acceptable at the small counts
/// these are used for; for long lists, wrap the group in a single
/// [TweenAnimationBuilder]-driven shimmer instead.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.xs,
    this.shape = BoxShape.rectangle,
  });

  /// Square block, used for images and avatars.
  const LoadingSkeleton.square({
    super.key,
    required double size,
    this.borderRadius = AppRadius.xs,
  }) : width = size,
       height = size,
       shape = BoxShape.rectangle;

  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _SkeletonPainter(
            position: _controller.value,
            base: context.brand.surfaceRaised,
            highlight: context.isDarkMode
                ? const Color(0xFF2A2F35)
                : const Color(0xFFFDFCFB),
          ),
          child: child,
        ),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.brand.surfaceRaised,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.position,
    required this.base,
    required this.highlight,
  });

  final double position;
  final Color base;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.save();
    canvas.clipRRect(rect);

    final double bandWidth = size.width * 0.6;
    final double x = -bandWidth + position * (size.width + bandWidth * 2);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[base, highlight, base],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(x, 0, bandWidth, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight;
}


/// A skeleton shaped like a vehicle card, so the loading state matches the
/// content that replaces it and the layout does not jump.
class CarCardSkeleton extends StatelessWidget {
  const CarCardSkeleton({super.key, this.vertical = false});

  /// Grid variant: a taller image with the text stacked underneath.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (!vertical) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const LoadingSkeleton(width: 108, height: 82, borderRadius: AppRadius.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                LoadingSkeleton(width: 150, height: 15),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 100, height: 13),
                SizedBox(height: AppSpacing.md),
                LoadingSkeleton(width: 80, height: 13),
              ],
            ),
          ),
        ],
      );
    }

    // Mirrors CarCard._buildStacked, including the same short-tile handling,
    // so the skeleton occupies exactly the box the real card will occupy
    // and nothing shifts when the data arrives.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Below this height the skeleton would be clipped by the real card, so
        // it is reduced here too. FittedBox is the final guarantee: a skeleton
        // may scale, but it must never throw an overflow.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Flexible(
              child: AspectRatio(
                aspectRatio: AutomotiveImageRatio.tile,
                child: const LoadingSkeleton(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppRadius.md,
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const LoadingSkeleton(width: 64, height: 11),
                      const SizedBox(height: AppSpacing.xs),
                      const LoadingSkeleton(width: 130, height: 15),
                      if (constraints.maxHeight >= 215) ...const <Widget>[
                        SizedBox(height: AppSpacing.xxs),
                        LoadingSkeleton(width: 96, height: 13),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      const LoadingSkeleton(width: 78, height: 15),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}