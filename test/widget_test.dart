import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/app/app.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:hangisi_daha/features/game/providers/game_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding completes and opens home', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDestinationProvider.overrideWith(
            (ref) async => StartupDestination.onboarding,
          ),
          personalBestsProvider.overrideWith((ref) async => _personalBests()),
        ],
        child: const HangisiDahaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hangisi Daha?'), findsOneWidget);
    expect(find.text('İki seçenekten doğru olanı seç.'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Klasik'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('60 Saniye'), findsOneWidget);

    await tester.tap(find.text('Oyuna Hazırım'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(LocalPreferencesRepository.onboardingCompletedKey),
      isTrue,
    );
    expect(find.text('Başla'), findsOneWidget);
    expect(find.byKey(const Key('classic-best-score')), findsOneWidget);
    expect(find.text('Nickname'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('completed onboarding starts on home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDestinationProvider.overrideWith(
            (ref) async => StartupDestination.home,
          ),
          personalBestsProvider.overrideWith((ref) async => _personalBests()),
        ],
        child: const HangisiDahaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsOneWidget);
    expect(find.byKey(const Key('classic-best-score')), findsOneWidget);
    expect(find.text('Henüz skor yok'), findsOneWidget);
    expect(find.text('Liderlik Tablosu'), findsNothing);
    expect(find.text('Nickname'), findsNothing);
    expect(find.text('Nasıl Oynanır'), findsOneWidget);
    expect(find.byKey(const Key('sound-effects-button')), findsOneWidget);
    expect(find.text('Hakkında ve Lisanslar'), findsNothing);
    expect(find.byKey(const Key('about-licenses-button')), findsNothing);
    expect(find.text('Ayarlar'), findsNothing);
  });

  testWidgets('home secondary routes open their screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDestinationProvider.overrideWith(
            (ref) async => StartupDestination.home,
          ),
          personalBestsProvider.overrideWith((ref) async => _personalBests()),
        ],
        child: const HangisiDahaApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (final destination in {
      'Nasıl Oynanır': 'Her soru için 15 saniyen var.',
    }.entries) {
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('home sound button toggles and persists the preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDestinationProvider.overrideWith(
            (ref) async => StartupDestination.home,
          ),
          personalBestsProvider.overrideWith((ref) async => _personalBests()),
        ],
        child: const HangisiDahaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ses efektlerini kapat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound-effects-button')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(LocalPreferencesRepository.soundEffectsEnabledKey),
      isFalse,
    );
    expect(find.byTooltip('Ses efektlerini aç'), findsOneWidget);
  });
}

LocalPersonalBests _personalBests({int classic = 0, int timeAttack = 0}) {
  return LocalPersonalBests(classicScore: classic, timeAttackScore: timeAttack);
}
