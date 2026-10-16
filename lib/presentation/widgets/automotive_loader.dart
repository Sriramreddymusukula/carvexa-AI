import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// Automotive loading indicator: a vehicle above a moving road.
///
/// Design notes:
///  * A single [AnimationController] drives everything and the whole thing is
///    one [CustomPaint] — one repaint per frame, no widget rebuilds, which
///    matters when a list is loading behind it.
///  * Road markings scroll; the car stays put. It reads as forward motion
///    without the vehicle ever bobbing, which is what separates "premium" from
///    "cartoon".
///  * The cycle is 1.5s: long enough to read as motion, short enough that
///    nobody waits.
class AutomotiveLoader extends StatefulWidget {
  const AutomotiveLoader({
    super.key,
    this.size = 44,
    this.strokeWidth = 2,
    this.showLabel = false,
    this.label,
  });

  final double size;
  final double strokeWidth;
  final bool showLabel;
  final String? label;

  @override
  State<AutomotiveLoader> createState() => _AutomotiveLoaderState();
}

class _AutomotiveLoaderState extends State<AutomotiveLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.roadCycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Read here, not in initState: an inherited widget may not be depended on
    // before the element has been mounted.
    final bool reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion || _started) return;

    _started = true;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget indicator = SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            painter: _RoadMotionPainter(
              progress: _controller.value,
              accent: context.brand.accent,
              track: context.isDarkMode
                  ? AppColors.darkOutlineStrong
                  : AppColors.lightOutline,
              vehicle: context.brand.textPrimary,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );

    if (!widget.showLabel) return indicator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        indicator,
        const SizedBox(height: 14),
        Text(
          widget.label ?? 'Loading',
          style: context.text.labelSmall?.copyWith(
            color: context.brand.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RoadMotionPainter extends CustomPainter {
  _RoadMotionPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.vehicle,
    required this.strokeWidth,
  });

  final double progress;
  final Color accent;
  final Color track;
  final Color vehicle;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double carHeight = h * 0.42;
    final double roadY = h * 0.76;

    // ---- Road line ----------------------------------------------------
    final Paint road = Paint()
      ..color = track
      ..strokeWidth = strokeWidth * 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.08, roadY), Offset(w * 0.92, roadY), road);

    // ---- Moving centre markings --------------------------------------
    final Paint dash = Paint()
      ..color = accent
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const int dashCount = 3;
    final double span = w * 0.84;
    final double dashWidth = span / (dashCount * 2);
    for (int i = 0; i < dashCount; i++) {
      final double start = w * 0.08 + i * dashWidth * 2 + progress * dashWidth * 2;
      if (start + dashWidth > w * 0.92) continue;
      canvas.drawLine(Offset(start, roadY), Offset(start + dashWidth, roadY), dash);
    }

    // ---- Vehicle silhouette -------------------------------------------
    final double carLeft = w * 0.26;
    final double carRight = w * 0.74;

    final Paint body = Paint()
      ..color = vehicle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Path silhouette = Path()
      ..moveTo(carLeft, roadY - carHeight * 0.18)
      ..lineTo(carLeft, roadY - carHeight * 0.42)
      ..cubicTo(
        carLeft + w * 0.04,
        roadY - carHeight * 0.62,
        carLeft + w * 0.10,
        roadY - carHeight * 0.70,
        carLeft + w * 0.16,
        roadY - carHeight * 0.74,
      )
      ..cubicTo(
        carLeft + w * 0.24,
        roadY - carHeight * 0.96,
        carRight - w * 0.24,
        roadY - carHeight * 0.96,
        carRight - w * 0.16,
        roadY - carHeight * 0.74,
      )
      ..cubicTo(
        carRight - w * 0.06,
        roadY - carHeight * 0.68,
        carRight - w * 0.02,
        roadY - carHeight * 0.52,
        carRight,
        roadY - carHeight * 0.42,
      )
      ..lineTo(carRight, roadY - carHeight * 0.18);

    canvas.drawPath(silhouette, body);

    // Wheels sit on the road line, so the vehicle reads as grounded.
    final double wheelRadius = carHeight * 0.12;
    for (final double cx in <double>[carLeft + w * 0.14, carRight - w * 0.14]) {
      canvas.drawCircle(Offset(cx, roadY - wheelRadius), wheelRadius, body);
    }

    // Headlight wash: grows and fades as the road scrolls, adding depth.
    final double beam = 0.16 + 0.2 * (0.5 + 0.5 * math.cos(progress * 2 * math.pi));
    final Paint beamPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[accent.withValues(alpha: 0), accent.withValues(alpha: beam)],
      ).createShader(
        Rect.fromLTWH(carRight - w * 0.02, roadY - carHeight * 0.44, w * 0.2, carHeight * 0.26),
      );
    canvas.drawOval(
      Rect.fromLTWH(carRight - w * 0.02, roadY - carHeight * 0.44, w * 0.2, carHeight * 0.26),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(_RoadMotionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track ||
      oldDelegate.vehicle != vehicle;
}
