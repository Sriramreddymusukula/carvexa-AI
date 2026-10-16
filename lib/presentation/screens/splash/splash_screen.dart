import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/automotive_loader.dart';
import '../../widgets/vehicle_silhouette.dart';

/// Branded launch screen.
///
/// Deliberately short: it exists to cover the first frame while the theme and
/// route tree warm up, not to entertain. A launch screen that lingers is a
/// launch screen that costs the user time, so it advances on a short timer and
/// can be skipped by tapping.
///
/// It also demonstrates the drive-in reveal: the mark settles into frame the
/// way a vehicle pulls away from a line.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.minimumDuration = const Duration(milliseconds: 1100)});

  final Duration minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _advanced = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: AppMotion.enter);
    _timer = Timer(widget.minimumDuration, _advance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Read here, not in initState: an inherited widget may not be depended on
    // before the element has been mounted.
    final bool reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reducedMotion) {
      _controller.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_advanced || !mounted) return;
    _advanced = true;
    context.go(AppRoutes.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Soft studio-light gradient behind the mark.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.1,
                  colors: <Color>[
                    context.brand.accent.withValues(alpha: 0.14),
                    context.brand.scaffoldBackground,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      final double t = Curves.easeOutQuart.transform(_controller.value);
                      return Opacity(
                        opacity: t,
                        child: FractionalTranslation(
                          translation: Offset(0, 0.12 * (1 - t)),
                          child: Transform.scale(
                            scale: 0.94 + 0.06 * t,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: const SizedBox(
                      width: 220,
                      height: 92,
                      child: VehicleSilhouette(color: Color(0xFFC2762F)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) => Opacity(
                      // Text trails the mark slightly, so the eye follows the
                      // entrance instead of arriving at both at once.
                      opacity: ((_controller.value - 0.35) / 0.65).clamp(0.0, 1.0),
                      child: child,
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'CARVEXA',
                          style: context.text.headlineLarge?.copyWith(
                            fontSize: 34,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'AI  ·  AUTOMOTIVE DISCOVERY',
                          style: context.text.labelSmall?.copyWith(
                            color: context.brand.accent,
                            letterSpacing: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.huge),
              child: Column(
                children: <Widget>[
                  const AutomotiveLoader(size: 40, strokeWidth: 1.8),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Preparing your showroom',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          // Tapping anywhere skips straight to the app.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: Semantics(
                button: true,
                label: 'Skip intro',
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
