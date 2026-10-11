import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';

class LocalPersonalBests {
  const LocalPersonalBests({
    required this.classicScore,
    required this.timeAttackScore,
  });

  final int classicScore;
  final int timeAttackScore;
}

final personalBestsProvider = FutureProvider.autoDispose<LocalPersonalBests>((
  ref,
) async {
  final preferences = await ref.watch(
    localPreferencesRepositoryProvider.future,
  );
  return LocalPersonalBests(
    classicScore: preferences.classicPersonalBest?.score ?? 0,
    timeAttackScore: preferences.timeAttackPersonalBest?.score ?? 0,
  );
});
