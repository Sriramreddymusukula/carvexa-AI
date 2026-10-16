import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/app_shell.dart';
import '../../state/account_controller.dart';
import '../../state/favorites_controller.dart';
import '../../widgets/car_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/page_container.dart';
import '../../widgets/state_views.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PageContainer(
        child: Consumer<AccountController>(
          builder: (BuildContext context, AccountController account, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ShellAppBar(
                overline: 'Shortlist',
                title: 'Saved vehicles',
                subtitle: 'Your vehicles, saved to your account',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!account.isRestored)
                const Center(child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator(),
                ))
              else if (!account.isAuthenticated)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.48,
                  child: EmptyState(
                    title: 'Sign in to see saved vehicles',
                    message: 'Your favorites stay with your account when you return.',
                    icon: Icons.lock_outline_rounded,
                    actionLabel: 'Sign in',
                    onAction: () => context.go(AppRoutes.profile),
                  ),
                )
              else
                _FavoritesList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final FavoritesController favorites = context.watch<FavoritesController>();
    if (favorites.isLoading && favorites.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        child: Column(
          children: <Widget>[
            CarCardSkeleton(vertical: false),
            SizedBox(height: AppSpacing.md),
            CarCardSkeleton(vertical: false),
          ],
        ),
      );
    }
    if (favorites.failure != null && favorites.items.isEmpty) {
      return SizedBox(
        height: 340,
        child: ErrorState.fromFailure(
          title: 'Saved vehicles are unavailable',
          failure: favorites.failure!,
          onRetry: () => favorites.load(retry: true),
        ),
      );
    }
    if (favorites.items.isEmpty) {
      return SizedBox(
        height: 340,
        child: EmptyState(
          title: 'No saved vehicles yet',
          message: 'Tap the heart on a vehicle to keep it here.',
          icon: Icons.favorite_border_rounded,
          actionLabel: 'Browse vehicles',
          onAction: () => context.go(AppRoutes.catalog),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Column(
        children: <Widget>[
          for (final FavoriteEntry item in favorites.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: CarCard(
                car: item.car,
                layout: CarCardLayout.horizontal,
                onTap: () => context.push(AppRoutes.carDetails(item.car.id)),
                trailing: IconButton(
                  tooltip: 'Remove from saved vehicles',
                  onPressed: favorites.isMutating(item.car.id)
                      ? null
                      : () async {
                          final bool success = await favorites.toggle(item.car);
                          if (!success && context.mounted && favorites.failure != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(favorites.failure!.message)),
                            );
                          }
                        },
                  icon: const Icon(Icons.favorite_rounded),
                ),
              ),
            ),
          if (favorites.failure != null)
            Text(favorites.failure!.message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
