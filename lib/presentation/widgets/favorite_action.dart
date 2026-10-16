import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../data/models/car_preview.dart';
import '../state/account_controller.dart';
import '../state/favorites_controller.dart';

class FavoriteAction extends StatelessWidget {
  const FavoriteAction({super.key, required this.car});

  final CarPreview car;

  @override
  Widget build(BuildContext context) {
    final AccountController account = context.watch<AccountController>();
    final FavoritesController favorites = context.watch<FavoritesController>();
    final bool saved = favorites.contains(car.id);
    final bool busy = favorites.isMutating(car.id);

    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: !account.isAuthenticated
            ? 'Sign in to save this vehicle'
            : saved
                ? 'Remove from saved vehicles'
                : 'Save vehicle',
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        onPressed: busy
            ? null
            : () async {
                if (!account.isAuthenticated) {
                  context.go(AppRoutes.profile);
                  return;
                }
                final bool success = await favorites.toggle(car);
                if (!success && context.mounted && favorites.failure != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(favorites.failure!.message)),
                  );
                }
              },
        icon: busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: saved ? const Color(0xFFE37B61) : Colors.white,
                size: 21,
              ),
      ),
    );
  }
}
