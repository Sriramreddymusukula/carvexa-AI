import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/view_state.dart';
import '../../../data/models/car_preview.dart';
import '../../motion/drive_in_reveal.dart';
import '../../motion/showcase_parallax.dart';
import '../../shell/app_shell.dart';
import '../../state/home_feed_controller.dart';
import '../../widgets/car_card.dart';
import '../../widgets/favorite_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/page_container.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import 'home_search_entry.dart';

/// The home screen.
///
/// The live new-car showroom combines a direct search entry, a responsive
/// featured grid, and explicit loading, empty, and error states.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeFeedController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    // Read (not watch) here: the screen is rebuilt by the Selector below, so
    // listening here would rebuild the whole tree on every state change.
    _controller = context.read<HomeFeedController>();
    _scrollController = ScrollController();

    if (_controller.snapshot.state == ViewState.initial) {
      // Deferred to after the first frame: `load()` calls notifyListeners()
      // synchronously, and doing that during the initial build would mark a
      // provider dirty while the framework is still building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.load();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Selector<HomeFeedController, ViewSnapshot<List<CarPreview>>>(
        selector: (_, HomeFeedController controller) => controller.snapshot,
        builder: (BuildContext context, ViewSnapshot<List<CarPreview>> snapshot, _) {
          return PageContainer(
            controller: _scrollController,
            refresh: _controller.refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShellAppBar(
                  overline: 'Carvexa AI',
                  title: 'Find your next car',
                  subtitle: '${_controller.sourceLabel} from the live catalogue',
                trailing: IconButton(
                  tooltip: 'Ask Carvexa AI',
                  onPressed: () => context.push(AppRoutes.ai),
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
                ),

                // Progressive disclosure: search is the primary action and sits
                // one tap from the top, with no intermediate menu.
                const HomeSearchEntry(),
                const SizedBox(height: AppSpacing.xl),

                _buildBody(context, snapshot),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ViewSnapshot<List<CarPreview>> snapshot) {
    switch (snapshot.state) {
      case ViewState.initial:
      case ViewState.loading:
        return const _HomeSkeleton();

      case ViewState.error:
        return SizedBox(
          height: 320,
          child: ErrorState.fromFailure(
            title: 'We could not load the showroom',
            failure: snapshot.failure!,
            onRetry: () => _controller.load(force: true),
          ),
        );

      case ViewState.empty:
        return SizedBox(
          height: 320,
          child: EmptyState(
            title: 'No vehicles right now',
            message: 'The catalogue returned nothing to show. Pull down to try again.',
            actionLabel: 'Try again',
            onAction: () => _controller.load(force: true),
          ),
        );

      case ViewState.data:
        return _HomeContent(
          cars: snapshot.data!,
          showcase: _controller.showcase,
          scrollController: _scrollController,
        );
    }
  }
}

/// Loaded home content.
class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.cars,
    required this.showcase,
    required this.scrollController,
  });

  final List<CarPreview> cars;
  final CarPreview? showcase;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showcase != null) ...<Widget>[
          DriveInReveal(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
              child: ShowcaseParallax(
                scrollController: scrollController,
                parallaxStrength: 0.1,
                child: CarShowcaseCard(
                  car: showcase!,
                  onTap: showcase!.detailAvailable
                      ? () => context.push(AppRoutes.carDetails(showcase!.id))
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        SectionHeader(
          title: 'Explore',
          subtitle: '${cars.length} vehicles available',
          action: SeeAllLink(
            label: 'All vehicles',
            onPressed: () => context.go(AppRoutes.catalog),
          ),
        ),
        _FeaturedGrid(cars: cars),
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}

/// Responsive vehicle grid.
///
/// Column count comes from the breakpoint, so the same code serves a small
/// phone, a large phone in landscape and a tablet.
class _FeaturedGrid extends StatelessWidget {
  const _FeaturedGrid({required this.cars});

  final List<CarPreview> cars;

  @override
  Widget build(BuildContext context) {
    final int columns = Responsive.of(context).gridColumns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: cars.length,
        gridDelegate: _gridDelegate(columns),
        itemBuilder: (BuildContext context, int index) {
          return DriveInReveal(
            // Sub-linear stagger: a long list must not take seconds to reveal.
            delay: Duration(milliseconds: 60 * index.clamp(0, 6)),
            child: CarCard(
              car: cars[index],
              layout: CarCardLayout.stacked,
              showSpecs: false,
              favoriteAction: FavoriteAction(car: cars[index]),
              onTap: cars[index].detailAvailable
                  ? () => context.push(AppRoutes.carDetails(cars[index].id))
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// Shared by the grid and its skeleton so loading causes no layout shift.
  static SliverGridDelegate _gridDelegate(int columns) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        // Derived from the column count so a 2-column phone and a 4-column
        // tablet both get a well-proportioned card.
        childAspectRatio: switch (columns) {
          2 => 0.7,
          3 => 0.8,
          _ => 0.88,
        },
      );
}

/// Skeleton that matches the real layout, so nothing shifts when data arrives.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final int columns = Responsive.of(context).gridColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const LoadingSkeleton(
          width: double.infinity,
          height: 200,
          borderRadius: AppRadius.lg,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const LoadingSkeleton(width: 180, height: 20),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: columns * 2,
          gridDelegate: _FeaturedGrid._gridDelegate(columns),
          itemBuilder: (BuildContext context, int index) =>
              const CarCardSkeleton(vertical: true),
        ),
      ],
    );
  }
}
