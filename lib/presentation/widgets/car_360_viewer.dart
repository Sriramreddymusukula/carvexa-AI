import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/car_detail.dart';
import 'automotive_image.dart';

/// A swipeable sequence of provider-published exterior spin frames.
///
/// Two or more ordered frames are required before presenting a rotation
/// control. Ordinary gallery photos are never used as a substitute.
class Car360Viewer extends StatefulWidget {
  const Car360Viewer({super.key, required this.frames});

  final List<CarImage> frames;

  @override
  State<Car360Viewer> createState() => _Car360ViewerState();
}

class _Car360ViewerState extends State<Car360Viewer> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final bool available = widget.frames.length >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.lg,
        AppSpacing.pageGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('360° exterior view', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          if (!available)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.brand.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.brand.outline),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.rotate_right_rounded,
                    color: context.brand.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '360° unavailable for this vehicle',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.brand.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    PageView.builder(
                      itemCount: widget.frames.length,
                      onPageChanged: (int index) =>
                          setState(() => _index = index),
                      itemBuilder: (BuildContext context, int index) =>
                          AutomotiveImage(
                            key: ValueKey<String>(
                              '360-${widget.frames[index].url}',
                            ),
                            imageUrl: widget.frames[index].url,
                            semanticLabel:
                                widget.frames[index].alt ?? '360 degree view',
                          ),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            '${_index + 1} / ${widget.frames.length}',
                            style: context.text.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Swipe to rotate', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}
