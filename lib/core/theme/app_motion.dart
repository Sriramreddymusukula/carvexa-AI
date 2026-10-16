import 'package:flutter/material.dart';

/// Central motion language.
///
/// Rules encoded here:
///  * Durations are short. Premium motion is quick to start and quick to
///    finish; anything above ~500ms on a tap feels sluggish on mobile.
///  * Curves are standard, not bouncy/elastic — a car does not wobble.
///  * Long-running (looping) motion is opt-in via [ambient] and is reserved for
///    genuine loaders, never decorative idling.
abstract final class AppMotion {
  // ---- Durations ---------------------------------------------------------
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  /// Entrance/reveal choreography for a list of items.
  static const Duration enter = Duration(milliseconds: 520);

  /// One full cycle of the road loader.
  static const Duration roadCycle = Duration(milliseconds: 1500);

  /// One full cycle of the hero "breathing" showcase motion.
  static const Duration showcaseCycle = Duration(milliseconds: 9000);

  // ---- Curves ------------------------------------------------------------
  /// Default for anything entering or changing state.
  static const Curve standard = Curves.easeOutCubic;

  /// Decelerating curve for a car pulling into frame: starts with intent,
  /// settles gently.
  static const Curve driveIn = Curves.easeOutQuart;

  /// For symmetrical interactions (press scale down and back).
  static const Curve press = Curves.easeOut;

  /// For layout-ish changes such as hero expansion.
  static const Curve emphasis = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Linear only for continuously scrolling motion (the road loader), where
  /// easing would visibly repeat.
  static const Curve continuous = Curves.linear;

  // ---- Motion constants --------------------------------------------------
  /// How far a vehicle slides in from the edge on entrance.
  static const double driveInOffset = 0.18;

  /// Scale applied to a card while pressed.
  static const double pressScale = 0.965;

  /// Image zoom on a hovered card (desktop / web only).
  static const double hoverZoom = 1.06;

  /// Peak extra scale for the hero showcase breathing motion.
  static const double showcaseScale = 1.035;
}
