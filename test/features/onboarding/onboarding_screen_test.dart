import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/app/app.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'three-page onboarding explains both modes without resetting completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        LocalPreferencesRepository.onboardingCompletedKey: true,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupDestinationProvider.overrideWith(
              (ref) async => StartupDestination.onboarding,
            ),
          ],
          child: const HangisiDahaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-indicator-3')), findsOneWidget);
      expect(find.byKey(const Key('onboarding-indicator-4')), findsNothing);
      expect(find.text('İki seçenekten doğru olanı seç.'), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding-illustration-1')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('A ve B karşılaştırma simgesi'),
        findsNothing,
      );

      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('Klasik'), findsOneWidget);
      expect(find.textContaining('jokerler'), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding-illustration-2')),
        findsOneWidget,
      );

      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('60 Saniye'), findsOneWidget);
      expect(find.textContaining('+1'), findsOneWidget);
      expect(find.textContaining('süre değişmez'), findsOneWidget);
      expect(find.textContaining('1 saniyeden 4 saniyeye'), findsOneWidget);
      expect(
        find.textContaining('doğru cevap cezayı sıfırlar'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('onboarding-illustration-3')),
        findsOneWidget,
      );

      await tester.tap(find.text('Oyuna Hazırım'));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(LocalPreferencesRepository.onboardingCompletedKey),
        isTrue,
      );
    },
  );
}
