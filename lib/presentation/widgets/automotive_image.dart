import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import 'vehicle_silhouette.dart';

/// The single image component for vehicles.
///
/// Why one component instead of `Image.network` at each call site:
///  * Cropping is consistent everywhere Ã¢â‚¬â€ `BoxFit.cover` inside a rounded,
///    aspect-ratio-locked container, so a photo is never stretched or squashed.
///  * Loading and failure both look designed rather than broken: the loading
///    state is a shimmer over the vehicle silhouette, and the failure state is
///    the silhouette with a small label.
///  * The reveal from placeholder to photo is handled once, here.
///
/// Catalog image URLs use this same component as the designed fallback, so
/// failed or unavailable photos do not break the card layout.
class AutomotiveImage extends StatelessWidget {
  const AutomotiveImage({
    super.key,
    this.imageUrl,
    this.aspectRatio = AutomotiveImageRatio.card,
    this.fillHeight = false,
    this.borderRadius = AppRadius.mediaRadius,
    this.silhouetteColor,
    this.semanticLabel,
    this.alignment = Alignment.center,
    this.overlay,
    this.showPlaceholderLabel = true,
    this.placeholderLabel = 'Image placeholder',
  });

  /// Remote catalog image, when the provider publishes one.
  final String? imageUrl;

  /// Aspect ratio for the media box. Ignored when [fillHeight] is true, in
  /// which case the image fills the height its parent gives it - used by
  /// constrained contexts such as grid tiles.
  final double aspectRatio;

  /// Fill the available height instead of locking an aspect ratio.
  final bool fillHeight;

  final BorderRadius borderRadius;
  final Color? silhouetteColor;
  final String? semanticLabel;

  /// Which part of the image to keep when cropping. Car photography is usually
  /// centre-weighted, so centre is the default.
  final Alignment alignment;

  /// Optional on-image chrome (badges, gradients).
  final Widget? overlay;

  /// The 'Image placeholder' caption. Suppressed automatically when [overlay]
  /// is present, because an overlay usually places text in the same corner.
  final bool showPlaceholderLabel;
  final String placeholderLabel;

  @override
  Widget build(BuildContext context) {
    final Color silhouette =
        silhouetteColor ?? context.brand.textTertiary.withValues(alpha: 0.55);

    // Never caption a box that already has content laid over it.
    final bool caption = showPlaceholderLabel && overlay == null;

    final Widget media = (imageUrl == null || imageUrl!.isEmpty)
        ? _Placeholder(
            silhouetteColor: silhouette,
            showLabel: caption,
            label: placeholderLabel,
          )
        : _NetworkImage(
            url: imageUrl!,
            fallbackSilhouette: silhouette,
            alignment: alignment,
          );

    Widget result = fillHeight
        ? ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[media, ?overlay],
            ),
          )
        : AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[media, ?overlay],
              ),
            ),
          );

    if (semanticLabel != null) {
      result = Semantics(
        image: true,
        label: semanticLabel,
        child: ExcludeSemantics(child: result),
      );
    }

    return result;
  }
}

/// Shimmer + silhouette shown while a photo decodes, and when there is none.
class _Placeholder extends StatefulWidget {
  const _Placeholder({
    required this.silhouetteColor,
    required this.label,
    this.showLabel = true,
  });

  final Color silhouetteColor;
  final String label;
  final bool showLabel;

  @override
  State<_Placeholder> createState() => _PlaceholderState();
}

class _PlaceholderState extends State<_Placeholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          // A single slow sweep. A fast or high-contrast shimmer reads as
          // cheap; this reads as light passing over a body panel.
          painter: _ShimmerPainter(
            position: _controller.value,
            base: isDark
                ? AppColors.darkSurfaceRaised
                : AppColors.lightSurfaceMuted,
            highlight: isDark ? AppColors.darkSurfaceOverlay : Colors.white,
          ),
          child: child,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Inset so the silhouette never touches the container edge.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: VehicleSilhouette(
                color: widget.silhouetteColor,
                opacity: 0.9,
              ),
            ),
            if (widget.showLabel)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    widget.label,
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 8.5,
                      letterSpacing: 1.2,
                      color: context.brand.textTertiary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Real photography, revealed smoothly from the designed placeholder.
///
/// All three states are handled in one place:
///  * **loading** Ã¢â‚¬â€ placeholder underneath, photo fades and settles in on the
///    first decoded frame (no grey box, no pop)
///  * **ready** Ã¢â‚¬â€ `BoxFit.cover`, so the crop is always correct
///  * **failed** Ã¢â‚¬â€ the placeholder stays, with a small explanatory label
class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.url,
    required this.fallbackSilhouette,
    required this.alignment,
  });

  final String url;
  final Color fallbackSilhouette;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int? cacheWidth = _decodedImageWidth(
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Always underneath, so a failure degrades gracefully.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: VehicleSilhouette(color: fallbackSilhouette, opacity: 0.9),
            ),
            Image.network(
              url,
              cacheWidth: cacheWidth,
              fit: BoxFit.cover,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              frameBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    int? frame,
                    bool wasSynchronouslyLoaded,
                  ) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: AppMotion.slow,
                      curve: AppMotion.standard,
                      child: AnimatedScale(
                        scale: frame == null ? 1.02 : 1.0,
                        duration: AppMotion.slow,
                        curve: AppMotion.standard,
                        child: child,
                      ),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Image unavailable',
                          style: context.text.labelSmall?.copyWith(
                            fontSize: 8.5,
                            letterSpacing: 1.2,
                            color: context.brand.textTertiary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
            ),
          ],
        );
      },
    );
  }
}

int? _decodedImageWidth(double logicalWidth, double devicePixelRatio) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
  final double physicalWidth = logicalWidth * devicePixelRatio;
  for (final int width in const <int>[320, 640, 960, 1280, 1920, 2560]) {
    if (physicalWidth <= width) return width;
  }
  return null;
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.position,
    required this.base,
    required this.highlight,
  });

  final double position;
  final Color base;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    // A narrow diagonal band travelling across, wrapping seamlessly.
    final double bandWidth = size.width * 0.55;
    final double travel = size.width + bandWidth * 2;
    final double x = -bandWidth + position * travel;

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[base, highlight.withValues(alpha: 0.14), base],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x, 0, bandWidth, size.height));

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight;
}
