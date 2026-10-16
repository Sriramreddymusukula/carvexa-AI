import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/car_catalog_page.dart';
import '../motion/pressable_scale.dart';

/// Opens the filter sheet and returns the chosen value.
///
/// Returns `null` when dismissed (leave everything as it is), an empty string
/// when the filter should be removed, and the value otherwise. Keeping
/// "dismissed" and "cleared" distinct is what lets a tap outside the sheet be a
/// true cancel rather than an accidental reset.
Future<String?> showCatalogFilterSheet({
  required BuildContext context,
  required CatalogFilterSpec spec,
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => _FilterSheet(spec: spec, current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.spec, required this.current});

  final CatalogFilterSpec spec;
  final String? current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.current ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pop(String value) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard so the field stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.brand.surface,
          borderRadius: AppRadius.sheetRadius,
          border: Border(top: BorderSide(color: context.brand.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.spec.label, style: context.text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.current == null
                    ? 'Leave empty to include every ${widget.spec.label.toLowerCase()}.'
                    : 'Currently ${widget.current}.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _pop,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.spec.placeholder,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              if (widget.spec.examples.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text('Examples', style: context.text.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String example in widget.spec.examples)
                      _ExampleChip(
                        label: example,
                        selected: example == widget.current,
                        onTap: () => _pop(example),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  if (widget.current != null) ...<Widget>[
                    Expanded(
                      child: _SheetButton(label: 'Remove', onTap: () => _pop('')),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _SheetButton(
                      label: 'Apply',
                      primary: true,
                      onTap: () => _pop(_text.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? context.brand.accent.withValues(alpha: 0.16)
              : context.brand.surfaceRaised,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(color: selected ? context.brand.accent : context.brand.outline),
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? context.brand.accent : context.brand.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        height: AppSpacing.minTouchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? context.brand.accent : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(color: primary ? Colors.transparent : context.brand.outline),
        ),
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(
            color: primary
                ? (context.isDarkMode ? const Color(0xFF1A1005) : Colors.white)
                : context.brand.textPrimary,
          ),
        ),
      ),
    );
  }
}
