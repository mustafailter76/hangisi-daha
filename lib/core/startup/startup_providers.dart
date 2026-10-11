import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';

enum StartupDestination { onboarding, home }

final startupDestinationProvider = FutureProvider<StartupDestination>((
  ref,
) async {
  final preferencesRepository = await ref.watch(
    localPreferencesRepositoryProvider.future,
  );
  return preferencesRepository.isOnboardingCompleted
      ? StartupDestination.home
      : StartupDestination.onboarding;
});
