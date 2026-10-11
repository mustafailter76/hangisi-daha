import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/app/app.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/startup/startup_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/models/game_state.dart';
import 'package:hangisi_daha/features/game/providers/game_controller.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_state.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';
import 'package:hangisi_daha/features/time_attack/time_attack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'a new Classic record refreshes Home and survives a fresh provider container',
    (tester) async {
      await _recordAndVerifyHome(tester, _GameMode.classic);
    },
  );

  testWidgets(
    'a new 60 Seconds record refreshes Home and survives a fresh provider container',
    (tester) async {
      await _recordAndVerifyHome(tester, _GameMode.timeAttack);
    },
  );
}

Future<void> _recordAndVerifyHome(WidgetTester tester, _GameMode mode) async {
  SharedPreferences.setMockInitialValues({});
  final clock = _FrozenClock();
  final containers = <ProviderContainer>[];
  addTearDown(() {
    for (final container in containers) {
      container.dispose();
    }
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        startupDestinationProvider.overrideWith(
          (ref) async => StartupDestination.home,
        ),
        localGameplayQuestionsProvider.overrideWith((ref) async => _questions),
        timeAttackClockFactoryProvider.overrideWithValue(() => clock),
        timeAttackImagePreloaderProvider.overrideWithValue(
          (context, imagePaths) async {},
        ),
        soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
        gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
      ],
    );
    containers.add(container);
    return container;
  }

  var container = createContainer();
  final initialRepository = await container.read(
    localPreferencesRepositoryProvider.future,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HangisiDahaApp(),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Henüz skor yok'), findsOneWidget);
  await tester.tap(find.byKey(const Key('start-game-button')));
  await tester.pumpAndSettle();
  final modeKey = mode == _GameMode.classic
      ? const Key('classic-mode-option')
      : const Key('time-attack-mode-option');
  await tester.tap(find.byKey(modeKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  if (mode == _GameMode.classic) {
    await _pumpUntil(
      tester,
      () =>
          container.read(gameControllerProvider).phase ==
          GamePhase.questionActive,
    );
    await tester.pump();
    final question = container.read(gameControllerProvider).question!;
    expect(question.id, 'pb-navigation');
    await tester.tap(find.byKey(Key('option-${GameOption.b.name}-card')));
    await tester.pump();
    await tester.pump(
      GameController.resultDisplayDuration + const Duration(milliseconds: 50),
    );
    await tester.pump();
    expect(find.byKey(const Key('game-home-button')), findsOneWidget);
  } else {
    await _pumpUntil(
      tester,
      () =>
          container.read(timeAttackControllerProvider).phase ==
          TimeAttackPhase.active,
    );
    await tester.pump();
    final question = container.read(timeAttackControllerProvider).question!;
    final correctPosition = question.top.name == 'B'
        ? TimeAttackPosition.top
        : TimeAttackPosition.bottom;
    await tester.tap(
      find.byKey(Key('time-attack-${correctPosition.name}-card')),
    );
    await tester.pump();
    await tester.pump(
      TimeAttackController.feedbackDuration + const Duration(milliseconds: 50),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('time-attack-game-over-score')),
      findsOneWidget,
    );
  }

  final stored = await SharedPreferences.getInstance();
  if (mode == _GameMode.classic) {
    expect(
      stored.getInt(LocalPreferencesRepository.classicPersonalBestScoreKey),
      1,
    );
  } else {
    expect(
      stored.getInt(LocalPreferencesRepository.timeAttackPersonalBestScoreKey),
      1,
    );
  }

  await tester.tap(find.text('Ana Sayfa'));
  await tester.pumpAndSettle();
  expect(find.text('1'), findsOneWidget);

  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  containers.remove(container);

  container = createContainer();
  final restoredRepository = await container.read(
    localPreferencesRepositoryProvider.future,
  );
  expect(restoredRepository, isNot(same(initialRepository)));
  if (mode == _GameMode.classic) {
    expect(restoredRepository.classicPersonalBest?.score, 1);
  } else {
    expect(restoredRepository.timeAttackPersonalBest?.score, 1);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HangisiDahaApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('1'), findsOneWidget);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 80 && !predicate(); attempt++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(predicate(), isTrue);
}

enum _GameMode { classic, timeAttack }

final _questions = [
  LocalGameplayQuestion(
    id: 'pb-navigation',
    questionText: 'A record test question',
    optionA: 'A',
    optionB: 'B',
    valueA: 1,
    valueB: 2,
    displayValueA: '1',
    displayValueB: '2',
    comparisonMode: GameplayComparisonMode.higherWins,
    difficulty: GameplayDifficulty.easy,
    category: 'test',
    hint: 'test',
    imageA: 'assets/content/images/0693a83c-b8f8-8f0c-9f97-9293a2b9b08f/a.webp',
    imageB: 'assets/content/images/0693a83c-b8f8-8f0c-9f97-9293a2b9b08f/b.webp',
  ),
];

class _FrozenClock implements TimeAttackMonotonicClock {
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
  Future<void> playCriticalTime() async {}

  @override
  Future<void> playExtension() async {}

  @override
  Future<void> playGameOver() async {}

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
