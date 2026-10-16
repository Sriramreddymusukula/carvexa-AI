import 'package:flutter/widgets.dart';

import 'pointer_capability.dart';

/// Breakpoints for the responsive foundation.
///
/// Chosen from real Android device widths rather than round numbers:
///  * compact  < 600  — the overwhelming majority of phones
///  * medium   600-839 — large phones in landscape, small foldables
///  * expanded >= 840 — tablets and desktop/web
///
/// Layouts adapt on width only. Height is intentionally ignored except for the
/// explicit landscape check, because phone heights vary far more than widths
/// and reacting to them causes jumpy, unusable chrome.
enum ScreenSize {
  compact(width: 0, upTo: 600),
  medium(width: 600, upTo: 840),
  expanded(width: 840, upTo: double.infinity);

  const ScreenSize({required this.width, required this.upTo});

  final double width;
  final double upTo;

  bool contains(double value) => value >= width && value < upTo;

  /// Number of grid columns that reads comfortably at this size.
  int get gridColumns => switch (this) {
    ScreenSize.compact => 2,
    ScreenSize.medium => 3,
    ScreenSize.expanded => 4,
  };

  /// Maximum content width so text lines never become unreadably long on
  /// tablets/desktop. Beyond this the content is centred.
  double get maxContentWidth => switch (this) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 720,
    ScreenSize.expanded => 1080,
  };

  bool get isCompact => this == ScreenSize.compact;
  bool get isExpanded => this == ScreenSize.expanded;

  /// Phones held sideways. Used to switch a few layouts (not the whole app).
  static bool isLandscape(BuildContext context) =>
      MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
}

/// Responsive helpers resolved from a [BuildContext].
class Responsive {
  const Responsive._();

  static ScreenSize of(BuildContext context) =>
      _fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize _fromWidth(double width) {
    for (final size in ScreenSize.values) {
      if (size.contains(width)) return size;
    }
    return ScreenSize.compact;
  }

  static bool isCompact(BuildContext context) => of(context).isCompact;

  static bool isExpanded(BuildContext context) => of(context).isExpanded;

  static int gridColumns(BuildContext context) => of(context).gridColumns;

  /// Fraction of the viewport a horizontal card rail item should occupy.
  /// Wider screens show a larger share of the card, which keeps the rail
  /// feeling deliberate instead of stretched.
  static double railItemFlex(BuildContext context) => switch (of(context)) {
    ScreenSize.compact => 0.78,
    ScreenSize.medium => 0.5,
    ScreenSize.expanded => 0.34,
  };

  /// True when the platform has a precise pointer (desktop). Hover effects are
  /// gated on this so they never appear on touch devices.
  static bool supportsHover(BuildContext context) => PointerCapability.supportsHover(context);
}
