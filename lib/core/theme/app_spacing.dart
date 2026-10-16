import 'package:flutter/material.dart';

/// 4pt spacing scale.
///
/// Layout must use these values (via [AppSpacing] / `context.gaps`) instead of
/// ad-hoc numbers, so rhythm stays consistent and future density changes are a
/// single edit.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Standard horizontal page gutter.
  static const double pageGutter = 20;

  /// Vertical rhythm between major sections.
  static const double sectionGap = 28;

  /// Minimum interactive target. Keeps every control thumb-friendly.
  static const double minTouchTarget = 48;
}

/// Corner radius scale. Cars are not sharp rectangles, but the UI should not be
/// bubbly either, so the scale stays tight and automotive.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius mediaRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

/// Elevation is expressed as soft, low-contrast shadows (a hard shadow reads as
/// Material, a soft wide one reads as "lit from above" in a showroom).
abstract final class AppElevation {
  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x2E000000), blurRadius: 32, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), blurRadius: 48, offset: Offset(0, 24)),
  ];

  /// Light-mode shadows need less opacity than dark-mode ones.
  static const List<BoxShadow> lightCard = <BoxShadow>[
    BoxShadow(color: Color(0x0F101418), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x08101418), blurRadius: 3, offset: Offset(0, 1)),
  ];
}
