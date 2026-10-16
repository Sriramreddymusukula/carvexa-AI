import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/view_state.dart';
import '../../../data/models/car_catalog_page.dart';
import '../../../data/models/car_preview.dart';
import '../../../data/repositories/car_catalog_repository.dart';
import '../../motion/drive_in_reveal.dart';
import '../../shell/app_shell.dart';
import '../../state/catalog_controller.dart';
import '../../state/compare_controller.dart';
import '../../widgets/car_card.dart';
import '../../widgets/favorite_action.dart';
import '../../widgets/automotive_loader.dart';
import '../../widgets/catalog_filter_bar.dart';
import '../../widgets/catalog_search_field.dart';
import '../../widgets/compare_tray.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/state_views.dart';

/// The live catalogue.
///
/// The screen follows provider capabilities and displays live results with
/// explicit loading, empty, and error states.
///
/// Every control is driven by [CatalogCapabilities], which the backend derives
/// from the catalogue's actual contract. Search appears only where the
/// catalogue can search, "load more" only where it pages, and only the filters
/// the current catalogue supports are offered.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.focusSearch = false, this.initialQuery});

  /// True when the user arrived here *to search* (the home screen's search
  /// entry). The catalogue then switches to a source that can search and
  /// focuses the box.
  final bool focusSearch;

  /// Optional query to pre-fill, for a shared or restored search link.
  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CatalogController>(
      create: (BuildContext context) {
        final CatalogController controller = CatalogController(
          // read, not watch: the controller outlives this build, and watching
          // here would rebuild the controller on every dependency change.
          repository: context.read<CarCatalogRepository>(),
        );

        if (focusSearch) controller.requestSearchFocus();
        if (initialQuery != null && initialQuery!.isNotEmpty) {
          controller.search(initialQuery!);
        }

        controller.start();
        return controller;
      },
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView();

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogController>(
      builder: (BuildContext context, CatalogController controller, _) {
        return AppShell(
          child: Column(
            children: <Widget>[
              _Header(controller: controller),
              Expanded(child: _Body(controller: controller)),
              // Above the navigation bar, not floating over the list, so it
              // never hides a card. It collapses to nothing while the shortlist
              // is empty.
              const CompareTray(),
            ],
          ),
        );
      },
    );
  }
}

/// Everything above the list: title, catalogue switch, search and filters.
///
/// Kept outside the scroll view deliberately — search and filters must stay
/// reachable while the user browses, which is the whole point of progressive
/// disclosure.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    final CatalogSourceSpec source = controller.activeSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ShellAppBar(
          overline: 'Browse',
          title: 'All vehicles',
          subtitle: source.description,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
          ),
          child: CatalogSourceSwitch(
            sources: controller.capabilities.sources,
            activeId: controller.query.source,
            onChanged: controller.setSource,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
          ),
          child: controller.supportsSearch
              ? CatalogSearchField(
                  value: controller.query.search,
                  onChanged: controller.search,
                  onCleared: controller.clearSearch,
                  autofocus: controller.shouldFocusSearch,
                  // `isRefreshing`, not `isLoading && hasData`: a refresh keeps
                  // the state at `data`, so the old condition could never be
                  // true and the field never showed that a search was running.
                  busy: controller.snapshot.isRefreshing,
                )
              : _NoSearchNotice(
                  searchable: controller.capabilities.sources
                      .where((CatalogSourceSpec source) => source.search)
                      .toList(growable: false),
                  onSwitch: controller.setSource,
                ),
        ),
        if (source.filters.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
            ),
            child: CatalogFilterBar(
              filters: source.filters,
              values: <String, String?>{
                for (final CatalogFilterSpec filter in source.filters)
                  filter.id: switch (filter.id) {
                    'city' => controller.query.city,
                    'brand' => controller.query.brand,
                    _ => null,
                  },
              },
              onApply: controller.applyFilter,
              onClearAll: controller.clearAllFilters,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Shown instead of a search box where the catalogue genuinely cannot search.
///
/// Rather than hiding the fact, it says so and offers the one action that does
/// work: switch to the catalogue that can be searched.
class _NoSearchNotice extends StatelessWidget {
  const _NoSearchNotice({required this.searchable, required this.onSwitch});

  /// Catalogues that really do support text search.
  final List<CatalogSourceSpec> searchable;
  final ValueChanged<String> onSwitch;

  @override
  Widget build(BuildContext context) {
    if (searchable.isEmpty) {
      return Text(
        'Browsing every vehicle in this catalogue.',
        style: context.text.bodySmall,
      );
    }
    final CatalogSourceSpec target = searchable.first;

    return Row(
      children: <Widget>[
        Icon(
          Icons.search_off_rounded,
          size: 16,
          color: context.brand.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'This catalogue cannot be searched. Try ${target.label.toLowerCase()}.',
            style: context.text.bodySmall,
          ),
        ),
        TextButton(
          onPressed: () => onSwitch(target.id),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Search ${target.label}',
            style: context.text.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// Switches between the four states every remote screen in this app has.
class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.snapshot.state) {
      case ViewState.initial:
      case ViewState.loading:
        return const _CatalogSkeleton();

      case ViewState.error:
        return ErrorState.fromFailure(
          title: 'Could not load vehicles',
          failure: controller.snapshot.failure!,
          onRetry: controller.retry,
        );

      case ViewState.empty:
        return _EmptyResults(controller: controller);

      case ViewState.data:
        return _CatalogGrid(
          controller: controller,
          page: controller.snapshot.data!,
        );
    }
  }
}

/// Nothing matched. Offers the action that actually helps: undo whatever
/// narrowed the list down.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    final bool searching = controller.isSearchActive;

    final String title = searching
        ? 'No vehicles match "${controller.query.search.trim()}"'
        : 'No vehicles here yet';

    final String message = searching
        ? 'Try a shorter search, or browse the other catalogue.'
        : 'This catalogue returned nothing for the current filters.';

    return EmptyState(
      title: title,
      message: message,
      icon: Icons.search_off_rounded,
      actionLabel: searching ? 'Clear search' : 'Try again',
      onAction: searching ? controller.clearSearch : controller.retry,
      secondaryActionLabel: !searching && controller.query.source == 'used'
          ? 'Browse live Hyderabad listings on OLX'
          : null,
      onSecondaryAction: !searching && controller.query.source == 'used'
          ? _openOlxHyderabadListings
          : null,
      secondaryActionIcon: Icons.open_in_new_rounded,
    );
  }
}

void _openOlxHyderabadListings() {
  unawaited(
    launchUrl(
      Uri.parse('https://www.olx.in/cars_c84/q-hyderabad-cars'),
      mode: LaunchMode.externalApplication,
    ),
  );
}

/// The vehicle grid, with load-more only where the catalogue really pages.
///
/// A [GridView] is used rather than a list because vehicles are compared at a
/// glance: the image and the price need to be visible together for many cars
/// at once.
class _CatalogGrid extends StatefulWidget {
  const _CatalogGrid({required this.controller, required this.page});

  final CatalogController controller;
  final CarCatalogPage page;

  @override
  State<_CatalogGrid> createState() => _CatalogGridState();
}

class _CatalogGridState extends State<_CatalogGrid> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the next page while there is still room to see content, so the
  /// results usually arrive before the user reaches the end.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 400) {
      return;
    }
    widget.controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final List<CarPreview> cars = widget.page.cars;
    final int columns = Responsive.of(context).gridColumns;

    return GridView.builder(
      controller: _scroll,
      // Always scrollable so pull-to-refresh works on an over-full grid.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        0,
        AppSpacing.pageGutter,
        AppSpacing.huge,
      ),
      itemCount: cars.length + (widget.controller.canLoadMore ? 1 : 0),
      gridDelegate: _gridDelegate(columns),
      itemBuilder: (BuildContext context, int index) {
        if (index >= cars.length) {
          return _LoadMoreCell(controller: widget.controller);
        }

        final CarPreview car = cars[index];
        return DriveInReveal(
          // Sub-linear stagger: a long page must not take seconds to reveal.
          delay: Duration(milliseconds: 55 * index.clamp(0, 6)),
          // Its own widget, because a card has to watch *only* its own entry in
          // the shortlist. `context.select` cannot be called directly in a
          // sliver's itemBuilder, and watching the whole controller would rebuild
          // the whole grid on every toggle.
          child: _ComparableCard(car: car),
        );
      },
    );
  }

  /// Shared with the skeleton so loading causes no layout shift.
  static SliverGridDelegate _gridDelegate(int columns) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: switch (columns) {
          2 => 0.7,
          3 => 0.8,
          _ => 0.88,
        },
      );
}

/// One catalogue tile, aware of its own place on the comparison shortlist.
///
/// Split out of the grid's `itemBuilder` for two reasons: `context.select` is
/// illegal inside a sliver's builder, and only this widget needs to rebuild
/// when a single vehicle is added or removed.
class _ComparableCard extends StatelessWidget {
  const _ComparableCard({required this.car});

  final CarPreview car;

  @override
  Widget build(BuildContext context) {
    return CarCard(
      car: car,
      layout: CarCardLayout.stacked,
      showSpecs: false,
      favoriteAction: FavoriteAction(car: car),
      // Cards without an openable detail page are informational only, so they
      // must not look tappable.
      onTap: car.detailAvailable
          ? () => context.push(AppRoutes.carDetails(car.id))
          : null,
      onCompare: () => _toggle(context),
      comparing: context.select<CompareController, bool>(
        (CompareController compare) => compare.contains(car.id),
      ),
    );
  }

  /// Adds or removes this vehicle, explaining a refusal rather than leaving a
  /// tap with no visible effect.
  void _toggle(BuildContext context) {
    final bool accepted = context.read<CompareController>().toggle(car);
    if (accepted) return;

    // The shortlist is full. Say so and name the limit: a silent no-op looks
    // like a broken button.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'You can compare ${CompareController.maxVehicles} vehicles at a time. '
            'Remove one to add ${car.shortName}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// The last cell of the grid: a quiet progress row, or a retry when the next
/// page could not be fetched.
///
/// Keeping it inside the grid (rather than in a snackbar) means the failure
/// stays visible and the user keeps the results already on screen.
class _LoadMoreCell extends StatelessWidget {
  const _LoadMoreCell({required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadMoreFailure != null) {
      return Center(
        child: PremiumButton(
          label: 'Try again',
          variant: PremiumButtonVariant.secondary,
          size: PremiumButtonSize.small,
          onPressed: controller.loadMore,
        ),
      );
    }

    return Center(
      child: controller.isLoadingMore
          ? const AutomotiveLoader(size: 28, strokeWidth: 1.8)
          : PremiumButton(
              label: 'Load more',
              variant: PremiumButtonVariant.secondary,
              size: PremiumButtonSize.small,
              onPressed: controller.loadMore,
            ),
    );
  }
}

/// Loading state that matches the grid exactly, so nothing moves when the
/// vehicles arrive.
class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    final int columns = Responsive.of(context).gridColumns;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        0,
        AppSpacing.pageGutter,
        AppSpacing.xl,
      ),
      itemCount: columns * 2,
      gridDelegate: _CatalogGridState._gridDelegate(columns),
      itemBuilder: (BuildContext context, int index) =>
          const CarCardSkeleton(vertical: true),
    );
  }
}
