import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';

/// Draws a stylised side-profile vehicle for the image placeholder.
///
/// Why a painted silhouette instead of a bundled photo:
///  * A placeholder must not look like competing "real" content or ship a
///    misleading stock car when a provider has no photo.
///  * It scales to any size with no asset cost and no network fetch.
///
/// Drawn rather than assembled from widgets so the whole thing is a single
/// `CustomPaint` repaint — important for scrolling performance.
class VehicleSilhouettePainter extends CustomPainter {
  const VehicleSilhouettePainter({
    required this.color,
    this.wheelColor = const Color(0xFF0B0C0E),
    this.opacity = 1.0,
  });

  final Color color;
  final Color wheelColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint body = Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..style = PaintingStyle.fill;

    final Paint trim = Paint()
      ..color = color.withValues(alpha: color.a * opacity * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.012
      ..strokeCap = StrokeCap.round;

    final Paint glass = Paint()
      ..color = (Colors.black).withValues(alpha: 0.28 * opacity)
      ..style = PaintingStyle.fill;

    final Paint tyre = Paint()
      ..color = wheelColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final Paint rim = Paint()
      ..color = color.withValues(alpha: color.a * 0.85 * opacity)
      ..style = PaintingStyle.fill;

    // Normalise to a 100 x 34 design box so the proportions hold at any size.
    final double sx = size.width / 100;
    final double sy = size.height / 34;
    final double unit = sx < sy ? sx : sy;

    canvas.save();
    canvas.translate(
      (size.width - 100 * unit) / 2,
      (size.height - 34 * unit) / 2,
    );
    canvas.scale(unit);

    // ---- Body: bonnet, raked windscreen, fastback roof, rear haunch ----
    final Path silhouette = Path()
      ..moveTo(3, 25)
      ..lineTo(3.5, 20.5)
      ..cubicTo(4, 19, 5.5, 18.2, 8, 17.8)
      ..lineTo(22, 15.6)
      ..cubicTo(25.5, 14.4, 30, 11.6, 35, 10.4)
      ..cubicTo(42, 8.8, 50, 8.4, 58, 9.2)
      ..cubicTo(66, 10, 72, 12.2, 78, 14.6)
      ..lineTo(90, 17.2)
      ..cubicTo(93.5, 18, 95.5, 19.2, 96.2, 21.2)
      ..lineTo(97, 25)
      ..lineTo(3, 25)
      ..close();
    canvas.drawPath(silhouette, body);

    // ---- Greenhouse: a single glasshouse, the classic automotive read ----
    final Path glasshouse = Path()
      ..moveTo(31, 15.2)
      ..cubicTo(35, 12.4, 40, 10.6, 45.5, 10)
      ..cubicTo(52, 9.3, 58, 9.4, 63.5, 10.2)
      ..lineTo(72, 12.6)
      ..lineTo(34, 15.2)
      ..close();
    canvas.drawPath(glasshouse, glass);

    // ---- Shoulder line along the flanks ----
    final Path shoulder = Path()
      ..moveTo(9, 21.2)
      ..cubicTo(28, 19.6, 62, 19.2, 92, 21)
      ..moveTo(28, 20.4)
      ..lineTo(28, 24.4)
      ..moveTo(72, 20.6)
      ..lineTo(72, 24.4);
    canvas.drawPath(shoulder, trim);

    // ---- Wheels ----
    for (final double cx in <double>[25, 75]) {
      canvas.drawCircle(Offset(cx, 25), 7.2, tyre);
      canvas.drawCircle(Offset(cx, 25), 3.4, rim);
    }

    // ---- Ground shadow, sells the weight of the car ----
    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 30.5, 88, 3.2),
        const Radius.circular(2),
      ),
      shadow,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(VehicleSilhouettePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.wheelColor != wheelColor ||
      oldDelegate.opacity != opacity;
}

/// Convenience wrapper that sizes itself to the available box.
class VehicleSilhouette extends StatelessWidget {
  const VehicleSilhouette({
    super.key,
    required this.color,
    this.wheelColor = const Color(0xFF0B0C0E),
    this.opacity = 1.0,
  });

  final Color color;
  final Color wheelColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // Guard against a zero-height box, which would divide by zero inside the
    // painter during a scroll/layout transition.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: VehicleSilhouettePainter(
            color: color,
            wheelColor: wheelColor,
            opacity: opacity,
          ),
        );
      },
    );
  }
}

/// Placeholder sizing helpers shared by every image slot.
class AutomotiveImageRatio {
  const AutomotiveImageRatio._();

  /// Hero / showcase.
  static const double hero = 16 / 9;

  /// Standard card in a rail.
  static const double card = 3 / 2;

  /// Grid tile.
  static const double tile = 4 / 3;

  /// Wide banner.
  static const double banner = 21 / 9;

  /// Small square thumbnail.
  static const double thumb = 1;

  /// Columns for a grid of cards at a given screen size.
  static int columnsFor(BuildContext context) => Responsive.of(context).gridColumns;
}
