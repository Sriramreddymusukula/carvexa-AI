import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

/// Central place for the "does this device support a mouse/trackpad" question.
///
/// Hover affordances are desktop/web only. On a phone, a hover state would
/// either never fire or fire from a touch and look broken, so those effects
/// are gated behind this rather than being hidden per call site.
class PointerCapability {
  const PointerCapability._();

  /// True for platforms where a precise pointer is the primary input.
  ///
  /// Deliberately based on the platform rather than on live pointer events: a
  /// touchscreen laptop would otherwise enable hover effects on its trackpad
  /// and disable them on its screen, which is inconsistent.
  /// Build context is accepted for call-site consistency with other capability
  /// helpers; hover detection is platform-based, not context-based.
  // ignore: unused_element
  static bool supportsHover(BuildContext context) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
    };
  }
}
