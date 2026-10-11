import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';

final soundEffectsControllerProvider =
    AsyncNotifierProvider<SoundEffectsController, bool>(
      SoundEffectsController.new,
    );

class SoundEffectsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repository = await ref.watch(
      localPreferencesRepositoryProvider.future,
    );
    return repository.areSoundEffectsEnabled;
  }

  Future<void> setEnabled(bool enabled) async {
    final previous = state.value ?? true;
    state = AsyncData(enabled);

    try {
      final repository = await ref.read(
        localPreferencesRepositoryProvider.future,
      );
      await repository.setSoundEffectsEnabled(enabled);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
