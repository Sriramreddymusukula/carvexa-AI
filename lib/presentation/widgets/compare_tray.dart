import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/car_preview.dart';
import '../state/compare_controller.dart';
import 'premium_button.dart';

/// The comparison shortlist, shown above the navigation bar once the user has
/// picked a vehicle.
///
/// It only appears when there is something on the shortlist, so the common case
/// — browsing, not comparing — costs no screen space at all. The action stays
/// disabled below two vehicles because a one-column table is not a comparison,
/// and saying so is better than opening one.
class CompareTray extends StatelessWidget {
  const CompareTray({super.key});

  @override
  Widget build(BuildContext context) {
    final CompareController compare = context.watch<CompareController>();
    if (compare.isEmpty) return const SizedBox.shrink();

    final int count = compare.selected.length;

    return Material(
      color: context.brand.surfaceRaised,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.brand.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.sm,
          AppSpacing.pageGutter,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    compare.canCompare
                        ? 'Ready to compare $count vehicles'
                        // Counted against the two needed to make a comparison,
                        // not the three it can hold: at one pick the only
                        // useful message is "one more".
                        : 'Pick ${2 - count} more vehicle${2 - count == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    compare.selected
                        .map((CarPreview car) => car.shortName)
                        .join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.brand.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: compare.clear,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Clear', style: context.text.labelMedium),
            ),
            const SizedBox(width: AppSpacing.xs),
            PremiumButton(
              label: 'Compare',
              size: PremiumButtonSize.small,
              icon: Icons.compare_arrows_rounded,
              onPressed: compare.canCompare
                  ? () => context.push(AppRoutes.compare)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
