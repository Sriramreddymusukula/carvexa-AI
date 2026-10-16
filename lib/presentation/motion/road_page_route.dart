import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';

/// A restrained, road-inspired page transition.
///
/// The outgoing page drifts slightly one way while the incoming page arrives
/// from the opposite side, as if the camera panned along a road. It is short
/// (260 ms) and small (~4% of the page), so navigation stays fast — the
/// animation must never be the reason a tap feels slow.
///
/// Used for top-level destination changes and detail pushes. Not used for
/// sheets, dialogs or anything that should feel immediate.
class RoadPageRoute<T> extends PageRouteBuilder<T> {
  RoadPageRoute({
    required WidgetBuilder builder,
    super.settings,
    bool reverseDirection = false,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: AppMotion.medium,
         reverseTransitionDuration: AppMotion.fast,
         opaque: true,
         pageBuilder:
             (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
                 builder(context),
         transitionsBuilder: roadTransitions(reverseDirection),
       );
}

/// Builds the transition. Taken as a top-level function so the direction is
/// captured as a plain value — `this` is not available in an initializer list.
RouteTransitionsBuilder roadTransitions(bool reverseDirection) {
  return (
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.prefersReducedMotion) return child;

    final double sign = reverseDirection ? 1.0 : -1.0;

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0.04 * sign, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: AppMotion.emphasis)),
      child: FadeTransition(
        // The fade stays ahead of the slide so the page is legible for most of
        // the transition.
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: AppMotion.standard),
        ),
        child: child,
      ),
    );
  };
}

/// Fades the previous page while the new one slides in. Used for the initial
/// route only, so the app "arrives" rather than appearing.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.medium,
        opaque: false,
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => builder(context),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: AppMotion.standard),
              child: child,
            ),
      );
}
