import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../motion/pressable_scale.dart';

/// The home screen's search entry point.
///
/// One tap opens the catalogue with its search field focused on a source that
/// actually supports search.
///
/// It is still rendered as a field rather than a button because that is what
/// the user expects at the top of a shopping screen, and because a field that
/// looks real invites a tap that now does something.
class HomeSearchEntry extends StatelessWidget {
  const HomeSearchEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Semantics(
        textField: true,
        readOnly: true,
        label: 'Search vehicles',
        hint: 'Opens vehicle search',
        child: PressableScale(
          onTap: () => context.go(AppRoutes.catalogSearching()),
          pressedScale: 0.99,
          excludedFromSemantics: true,
          child: AbsorbPointer(
            child: TextField(
              readOnly: true,
              showCursor: false,
              style: context.text.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search make or model',
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: context.brand.textTertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.brand.textSecondary,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'SEARCH',
                      style: context.text.labelSmall?.copyWith(
                        fontSize: 8.5,
                        color: context.brand.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

