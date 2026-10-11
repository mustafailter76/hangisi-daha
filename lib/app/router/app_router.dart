import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:hangisi_daha/features/game/game_screen.dart';
import 'package:hangisi_daha/features/home/home_screen.dart';
import 'package:hangisi_daha/features/how_to_play/how_to_play_screen.dart';
import 'package:hangisi_daha/features/onboarding/onboarding_screen.dart';
import 'package:hangisi_daha/features/time_attack/time_attack_screen.dart';

final appRouterProvider = FutureProvider<GoRouter>((ref) async {
  final startupDestination = await ref.watch(startupDestinationProvider.future);
  final initialLocation = switch (startupDestination) {
    StartupDestination.onboarding => AppRoute.onboarding.path,
    StartupDestination.home => AppRoute.home.path,
  };

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.name,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        name: AppRoute.home.name,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.game.path,
        name: AppRoute.game.name,
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: AppRoute.timeAttack.path,
        name: AppRoute.timeAttack.name,
        builder: (context, state) => const TimeAttackScreen(),
      ),
      GoRoute(
        path: AppRoute.howToPlay.path,
        name: AppRoute.howToPlay.name,
        builder: (context, state) => const HowToPlayScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
