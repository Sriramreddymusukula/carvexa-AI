import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/car_catalog_page.dart';
import '../motion/pressable_scale.dart';
import 'catalog_filter_sheet.dart';

/// Switches between the catalogues the backend offers.
///
/// Built from [CatalogCapabilities.sources] rather than a hard-coded list, so a
/// source the catalogue does not publish can never appear, and one it later
/// publishes appears without a code change.
class CatalogSourceSwitch extends StatelessWidget {
  const CatalogSourceSwitch({
    super.key,
    required this.sources,
    required this.activeId,
    required this.onChanged,
  });

  final List<CatalogSourceSpec> sources;
  final String activeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (sources.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.brand.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(color: context.brand.outline),
      ),
      child: Row(
        children: <Widget>[
          for (final CatalogSourceSpec source in sources)
            Expanded(
              child: _Segment(
                label: source.label,
                selected: source.id == activeId,
                onTap: () => onChanged(source.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: label,
      semanticHint: selected ? 'Selected catalogue' : 'Switches catalogue',
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.brand.accent : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium?.copyWith(
            color: selected
                ? (context.isDarkMode ? const Color(0xFF1A1005) : Colors.white)
                : context.brand.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One filter chip per supported filter, plus the "clear all" escape hatch.
///
/// Only the filters the active source declares are rendered — used listings get
/// a city, new models get a brand, and nothing else is offered because nothing
/// else would change the request.
class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({
    super.key,
    required this.filters,
    required this.values,
    required this.onApply,
    required this.onClearAll,
  });

  final List<CatalogFilterSpec> filters;
  final Map<String, String?> values;
  final void Function(String id, String? value) onApply;
  final VoidCallback onClearAll;

  bool get _hasActive => values.values.any((String? value) => value != null);

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final CatalogFilterSpec filter in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _FilterChip(
                spec: filter,
                value: values[filter.id],
                onApply: (String? value) => onApply(filter.id, value),
              ),
            ),
          if (_hasActive)
            PressableScale(
              onTap: onClearAll,
              semanticLabel: 'Clear all filters',
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.filter_alt_off_outlined,
                      size: 15,
                      color: context.brand.danger,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Clear all',
                      style: context.text.labelMedium?.copyWith(
                        color: context.brand.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.spec, required this.value, required this.onApply});

  final CatalogFilterSpec spec;
  final String? value;
  final ValueChanged<String?> onApply;

  @override
  Widget build(BuildContext context) {
    final bool active = value != null;

    return PressableScale(
      onTap: () => _open(context),
      semanticLabel: '${spec.label} filter',
      semanticHint: active ? 'Currently $value' : 'Not set',
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active
              ? context.brand.accent.withValues(alpha: 0.14)
              : context.brand.surface,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(
            color: active ? context.brand.accent.withValues(alpha: 0.55) : context.brand.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${spec.label}: ${value ?? 'any'}',
              style: context.text.labelMedium?.copyWith(
                color: active ? context.brand.accent : context.brand.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              active ? Icons.check_rounded : Icons.expand_more_rounded,
              size: 15,
              color: active ? context.brand.accent : context.brand.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// A bottom sheet rather than a dialog: filters are a mode you step through,
  /// and on a phone a sheet is reachable with one thumb.
  Future<void> _open(BuildContext context) async {
    final String? result = await showCatalogFilterSheet(
      context: context,
      spec: spec,
      current: value,
    );

    if (result == null) return;
    onApply(result.isEmpty ? null : result);
  }
}
