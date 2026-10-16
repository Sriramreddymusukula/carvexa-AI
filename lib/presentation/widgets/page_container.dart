import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

/// Standard page scaffold.
///
/// Centralises three things that are easy to get wrong screen by screen:
///  * the horizontal gutter, so content lines up across every destination
///  * the maximum content width, so text never becomes unreadably long on a
///    tablet or in landscape
///  * a bottom safe-area inset, so content is never hidden behind the
///    navigation bar
///
/// [scrollable] screens get a [CustomScrollView] with a [SliverToBoxAdapter];
/// non-scrollable screens get a centred [ConstrainedBox].
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.scrollable = true,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageGutter,
      0,
      AppSpacing.pageGutter,
      AppSpacing.xxl,
    ),
    this.slivers = const <Widget>[],
    this.bottomInset = true,
    this.refresh,
  });

  final Widget child;
  final bool scrollable;
  final ScrollController? controller;
  final EdgeInsets padding;

  /// Extra slivers appended after the main child (e.g. a pinned header).
  final List<Widget> slivers;

  final bool bottomInset;

  /// Enables pull-to-refresh without the caller reimplementing the gesture.
  final Future<void> Function()? refresh;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);

    if (!scrollable) {
      return SafeArea(
        bottom: bottomInset,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _maxWidth(context)),
            child: content,
          ),
        ),
      );
    }

    return SafeArea(
      bottom: bottomInset,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth(context)),
          child: RefreshIndicator.adaptive(
            onRefresh: refresh ?? () async {},
            edgeOffset: 0,
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: content),
                ...slivers,
                // Absorbs the system gesture bar so the last item is reachable.
                if (bottomInset)
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _maxWidth(BuildContext context) => Responsive.of(context).maxContentWidth;
}

/// Marks content that is illustrative rather than live.
///
