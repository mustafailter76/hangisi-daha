import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final localPreferencesRepositoryProvider =
    FutureProvider<LocalPreferencesRepository>((ref) async {
      final preferences = await ref.watch(sharedPreferencesProvider.future);
      return LocalPreferencesRepository(preferences);
    });
