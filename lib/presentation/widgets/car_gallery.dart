import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/car_detail.dart';
import 'automotive_image.dart';

/// A swipeable gallery of a vehicle's real photographs.
///
/// Reuses [AutomotiveImage] for every frame, so loading, cropping, broken URLs
/// and the "no photograph" case are all handled by the one component that
/// already owns them — the gallery adds no image logic of its own.
///
/// With a single photograph it renders a still hero and shows no dots, because
/// one dot is chrome that communicates nothing.
class CarGallery extends StatefulWidget {
  const CarGallery({
    super.key,
    required this.images,
    this.aspectRatio = 16 / 9,
    this.heroUrl,
  });

  final List<CarImage> images;
  final double aspectRatio;

  /// Used as the semantic label for the whole set, e.g. "Tata Nexon".
  final String? heroUrl;

  @override
  State<CarGallery> createState() => _CarGalleryState();
}

class _CarGalleryState extends State<CarGallery> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No photograph published: the shared placeholder is the whole gallery, so
    // the page still has its height and never collapses.
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: const AutomotiveImage(
          imageUrl: null,
          aspectRatio: 16 / 9,
          placeholderLabel: 'Vehicle photos unavailable',
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            itemCount: widget.images.length,
            onPageChanged: (int index) => setState(() => _index = index),
            itemBuilder: (BuildContext context, int index) {
              final CarImage image = widget.images[index];
              return AutomotiveImage(
                key: ValueKey<String>(image.url),
                imageUrl: image.url,
                // Frames have different subjects, so each gets its own label
                // rather than the vehicle name repeated.
                semanticLabel: image.alt ?? image.category,
              );
            },
          ),
          if (widget.images.length > 1) ...<Widget>[
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: _Counter(current: _index + 1, total: widget.images.length),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.md,
              child: Center(
                child: _Dots(count: widget.images.length, index: _index),
              ),
            ),
          ],
          if (widget.images[_index].category != null)
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: _CategoryPill(label: widget.images[_index].category!),
            ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        '$current / $total',
        style: context.text.labelSmall?.copyWith(
          fontSize: 9.5,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          fontSize: 8.5,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// One indicator per frame. Animated so the change reads as travel along the
/// car rather than a jump.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? context.brand.accentBright
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.pill),
              ),
            ),
          ),
      ],
    );
  }
}
