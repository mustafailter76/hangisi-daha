import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:hangisi_daha/app/router/app_routes.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';
import 'package:hangisi_daha/features/time_attack/time_attack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('local 60 Seconds Game Over can start a fresh game', (
    tester,
  ) async {
    await _pumpRoutedScreen(tester);
    await _finishGame(tester);

    await tester.tap(find.byKey(const Key('time-attack-play-again')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TimeAttackScreen), findsOneWidget);
    expect(find.text('Oyun Bitti'), findsNothing);
  });

  testWidgets('local 60 Seconds Game Over Home returns to Home', (
    tester,
  ) async {
    await _pumpRoutedScreen(tester);
    await _finishGame(tester);

    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-route-destination')), findsOneWidget);
  });
}

Future<void> _pumpRoutedScreen(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: AppRoute.timeAttack.path,
    routes: [
      GoRoute(
        path: AppRoute.timeAttack.path,
        name: AppRoute.timeAttack.name,
        builder: (context, state) => const TimeAttackScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        name: AppRoute.home.name,
        builder: (context, state) =>
            const Scaffold(key: Key('home-route-destination')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localGameplayQuestionsProvider.overrideWith(
          (ref) async => [_question('only', 2, 1)],
        ),
        localPreferencesRepositoryProvider.overrideWith(
          (ref) => _freshPreferences(),
        ),
        timeAttackClockFactoryProvider.overrideWithValue(_Clock.new),
        timeAttackImagePreloaderProvider.overrideWithValue(
          (context, imagePaths) async {},
        ),
        soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
        gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<LocalPreferencesRepository> _freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return LocalPreferencesRepository(await SharedPreferences.getInstance());
}

Future<void> _finishGame(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TimeAttackScreen)),
  );
  final question = container.read(timeAttackControllerProvider).question!;
  final correct = question.top.name == 'A'
      ? TimeAttackPosition.top
      : TimeAttackPosition.bottom;

  await tester.tap(find.byKey(Key('time-attack-${correct.name}-card')));
  await tester.pump();
  await tester.pump(TimeAttackController.feedbackDuration);
  await tester.pump();
  expect(find.text('Oyun Bitti'), findsOneWidget);
}

LocalGameplayQuestion _question(String id, int valueA, int valueB) =>
    LocalGameplayQuestion(
      id: id,
      questionText: 'Question $id',
      optionA: 'A',
      optionB: 'B',
      valueA: valueA,
      valueB: valueB,
      displayValueA: '$valueA',
      displayValueB: '$valueB',
      comparisonMode: GameplayComparisonMode.higherWins,
      difficulty: GameplayDifficulty.easy,
      category: id,
      imageA: 'a.webp',
      imageB: 'b.webp',
    );

class _Clock implements TimeAttackMonotonicClock {
  var _running = false;
  @override
  int get elapsedMilliseconds => 0;
  @override
  bool get isRunning => _running;
  @override
  void reset() {}
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
}

class _NoopSound implements SoundEffectService {
  const _NoopSound();
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playGameOver() async {}
  @override
  Future<void> playExtension() async {}
  @override
  Future<void> playHint() async {}
  @override
  Future<void> playNewRecord() async {}
  @override
  Future<void> playShieldActivate() async {}
  @override
  Future<void> playShieldImpact() async {}
  @override
  Future<void> playWrong() async {}
  @override
  Future<void> playCriticalTime() async {}
}

class _NoopHaptics implements GameHapticService {
  const _NoopHaptics();
  @override
  Future<void> correct() async {}
  @override
  Future<void> gameOver() async {}
  @override
  Future<void> jokerActivated() async {}
  @override
  Future<void> selection() async {}
  @override
  Future<void> shieldAbsorbed() async {}
  @override
  Future<void> wrong() async {}
}
