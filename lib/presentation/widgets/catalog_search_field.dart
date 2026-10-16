import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';

/// The catalogue's search box.
///
/// Rendered **only** when the active source really supports text search, so the
/// app never offers a box that cannot change the result set.
///
/// It owns nothing but the text: keystrokes go straight to the controller,
/// which debounces the request. That keeps one timer in the app rather than one
/// per widget, and makes the behaviour testable without a widget tree.
class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCleared,
    this.hintText = 'Search make or model',
    this.busy = false,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final String hintText;

  /// True when the screen was opened specifically to be searched, so the
  /// keyboard should already be up.
  final bool autofocus;

  /// True while a search request is in flight; shows a quiet inline indicator
  /// instead of blocking the field.
  final bool busy;

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  late final TextEditingController _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(CatalogSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect programmatic changes (e.g. switching source clears the query)
    // without disturbing what the user is currently typing.
    if (widget.value != _text.text && !_isTyping) {
      _text.text = widget.value;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    }
  }

  bool _isTyping = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _text.text.isNotEmpty;

    return Semantics(
      textField: true,
      label: 'Search vehicles',
      child: TextField(
        controller: _text,
        autofocus: widget.autofocus,
        onChanged: (String value) {
          setState(() {
            _isTyping = true;
            _text.text = value;
          });
          widget.onChanged(value);
          _isTyping = false;
        },
        textInputAction: TextInputAction.search,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: context.text.bodyMedium?.copyWith(color: context.brand.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, color: context.brand.textSecondary),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.busy)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: context.brand.accent,
                    ),
                  ),
                ),
              if (hasText)
                IconButton(
                  onPressed: () {
                    _text.clear();
                    widget.onCleared();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.brand.textSecondary,
                  tooltip: 'Clear search',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
