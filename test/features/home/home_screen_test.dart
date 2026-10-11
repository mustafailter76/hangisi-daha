import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home omits the legacy brand mark and keeps primary actions', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.bySemanticsLabel('A ve B karşılaştırma simgesi'), findsNothing);
    expect(find.text('Hangisi Daha?'), findsOneWidget);
    expect(find.byKey(const Key('best-score-badge')), findsOneWidget);
    expect(find.byKey(const Key('start-game-button')), findsOneWidget);
  });

  testWidgets('Başla opens the two-option mode picker', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();

    expect(find.text('Oyun Modunu Seç'), findsOneWidget);
    expect(find.byKey(const Key('classic-mode-option')), findsOneWidget);
    expect(find.byKey(const Key('classic-mode-press-motion')), findsOneWidget);
    expect(find.text('Doğru bildikçe devam et.'), findsOneWidget);
    expect(find.byKey(const Key('time-attack-mode-option')), findsOneWidget);
    expect(
      find.byKey(const Key('time-attack-mode-press-motion')),
      findsOneWidget,
    );
    expect(
      find.text('Süre bitmeden olabildiğince yüksek skor yap.'),
      findsOneWidget,
    );
  });

  testWidgets('Classic selection opens the existing Classic route', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('classic-mode-option')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('classic-route-destination')), findsOneWidget);
  });

  testWidgets('60-second selection opens the Time Attack route', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('time-attack-mode-option')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('time-attack-route-destination')),
      findsOneWidget,
    );
  });

  testWidgets('Home renders canonical Classic and 60-second personal bests', (
    tester,
  ) async {
    await _pumpHome(tester, classicScore: 12, timeAttackScore: 21);

    expect(find.byKey(const Key('classic-best-score')), findsOneWidget);
    expect(find.byKey(const Key('time-attack-best-score')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('Henüz skor yok'), findsNothing);
  });

  testWidgets('zero 60-second personal best has a controlled empty state', (
    tester,
  ) async {
    await _pumpHome(tester, classicScore: 4);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Henüz skor yok'), findsOneWidget);
  });

  testWidgets('mode picker does not overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);
    await tester.tap(find.byKey(const Key('start-game-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('time-attack-mode-option')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  int classicScore = 0,
  int timeAttackScore = 0,
}) async {
  final initialValues = <String, Object>{};
  if (classicScore > 0) {
    initialValues[LocalPreferencesRepository.classicPersonalBestScoreKey] =
        classicScore;
    initialValues[LocalPreferencesRepository.classicPersonalBestTimeKey] = 1000;
  }
  if (timeAttackScore > 0) {
    initialValues[LocalPreferencesRepository.timeAttackPersonalBestScoreKey] =
        timeAttackScore;
    initialValues[LocalPreferencesRepository
            .timeAttackPersonalBestWrongCountKey] =
        2;
  }
  SharedPreferences.setMockInitialValues(initialValues);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: AppRoute.game.path,
        name: AppRoute.game.name,
        builder: (context, state) =>
            const Scaffold(key: Key('classic-route-destination')),
      ),
      GoRoute(
        path: AppRoute.timeAttack.path,
        name: AppRoute.timeAttack.name,
        builder: (context, state) =>
            const Scaffold(key: Key('time-attack-route-destination')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}
