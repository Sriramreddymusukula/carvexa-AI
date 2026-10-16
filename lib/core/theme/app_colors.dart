import 'package:flutter/material.dart';

/// The single source of truth for colour in the application.
///
/// No screen, widget or component may use a raw `Color(0xFF...)` or a
/// material colour constant. Everything resolves through here so the brand can
/// be re-tuned in one place.
///
/// Palette rationale (premium automotive):
///  * A near-black graphite base reads as "showroom at night" and makes body
///    colour and photography do the talking.
///  * A single warm copper/amber accent evokes metal under street lighting
///    and reads as premium without the "toy/gaming" look that saturated
///    primaries produce.
///  * Light surfaces are a cool paper white, never pure #FFF, which keeps large
///    image areas from vibrating against the chrome.
abstract final class AppColors {
  // ---- Brand -------------------------------------------------------------
  /// Primary accent: brushed copper.
  static const Color accent = Color(0xFFC2762F);
  static const Color accentBright = Color(0xFFE39A54);
  static const Color accentDim = Color(0xFF8A5220);

  /// Secondary accent: cool titanium blue, used for informational states.
  static const Color info = Color(0xFF4C7A9E);
  static const Color infoBright = Color(0xFF6FA3C9);

  // ---- Semantic ----------------------------------------------------------
  static const Color success = Color(0xFF3F7D58);
  static const Color warning = Color(0xFFB07A2A);
  static const Color danger = Color(0xFFB04A3F);
  static const Color dangerBright = Color(0xFFD06B5F);

  // ---- Dark surfaces (the primary experience) ---------------------------
  static const Color darkBackground = Color(0xFF0B0C0E);
  static const Color darkSurface = Color(0xFF141619);
  static const Color darkSurfaceRaised = Color(0xFF1C1F23);
  static const Color darkSurfaceOverlay = Color(0xFF23272C);
  static const Color darkOutline = Color(0xFF2E3339);
  static const Color darkOutlineStrong = Color(0xFF3C434B);

  // ---- Light surfaces ----------------------------------------------------
  static const Color lightBackground = Color(0xFFF6F5F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEDEBE7);
  static const Color lightOutline = Color(0xFFDDD9D3);

  // ---- Text --------------------------------------------------------------
  static const Color darkTextPrimary = Color(0xFFF5F6F7);
  static const Color darkTextSecondary = Color(0xFFA8AEB6);
  static const Color darkTextTertiary = Color(0xFF6E757E);

  static const Color lightTextPrimary = Color(0xFF14161A);
  static const Color lightTextSecondary = Color(0xFF565C64);
  static const Color lightTextTertiary = Color(0xFF878D95);

  /// Scrim used behind hero imagery and over modals.
  static const Color scrim = Color(0xCC07080A);
  static const Color shimmerBase = Color(0xFF1A1D21);
  static const Color shimmerHighlight = Color(0xFF2A2F35);
}
