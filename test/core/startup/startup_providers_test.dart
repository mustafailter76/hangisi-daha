import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('empty local preferences open onboarding', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final destination = await container.read(startupDestinationProvider.future);

    expect(destination, StartupDestination.onboarding);
  });

  test('completed local onboarding opens home', () async {
    SharedPreferences.setMockInitialValues({
      LocalPreferencesRepository.onboardingCompletedKey: true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final destination = await container.read(startupDestinationProvider.future);

    expect(destination, StartupDestination.home);
  });
}
