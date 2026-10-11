import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_state.dart';
import 'package:hangisi_daha/features/time_attack/time_attack_screen.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'empty bundled content produces a controlled unavailable state',
    () async {
      final harness = _Harness(const []);
      addTearDown(harness.dispose);

      await harness.controller.startOrRecover();

      expect(harness.state.phase, TimeAttackPhase.error);
      expect(
        harness.state.errorMessage,
        'Şu anda oynanabilir soru bulunmuyor.',
      );
    },
  );

  testWidgets('60 Seconds screen renders an empty-content state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localGameplayQuestionsProvider.overrideWith((ref) async => const []),
          localPreferencesRepositoryProvider.overrideWith(
            (ref) => _freshPreferences(),
          ),
          soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
          gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
        ],
        child: const MaterialApp(home: TimeAttackScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Şu anda oynanabilir soru bulunmuyor.'), findsOneWidget);
  });

  test(
    'preparing does not consume ACTIVE budget and physical mapping is local',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);
      await harness.controller.startOrRecover();
      harness.clock.advance(5000);
      expect(harness.state.displayedRemainingMs, 60000);

      await harness.controller.prepareQuestion((_) async {});
      harness.clock.advance(1200);
      harness.controller.refreshElapsed();
      final question = harness.state.question!;
      final correct = _correctPosition(question);
      harness.controller.selectPosition(correct);

      expect(harness.state.phase, TimeAttackPhase.feedbackCorrect);
      expect(harness.state.score, 1);
      expect(harness.state.displayedRemainingMs, 58800);
    },
  );

  test('wrong penalties are produced locally and keep wrong count', () async {
    final harness = _Harness(_questions);
    addTearDown(harness.dispose);
    await harness.controller.startOrRecover();
    await harness.controller.prepareQuestion((_) async {});
    final question = harness.state.question!;
    final wrong = _correctPosition(question) == TimeAttackPosition.top
        ? TimeAttackPosition.bottom
        : TimeAttackPosition.top;
    harness.controller.selectPosition(wrong);

    expect(harness.state.phase, TimeAttackPhase.feedbackIncorrect);
    expect(harness.state.feedbackAdjustmentMs, -1000);
    expect(harness.state.wrongCount, 1);
    expect(harness.state.displayedRemainingMs, 59000);
  });

  test('hydrates shared seen IDs and persists the 60 Seconds PB', () async {
    SharedPreferences.setMockInitialValues({
      LocalPreferencesRepository.seenQuestionIdsKey: ['ta-a'],
    });
    final preferences = LocalPreferencesRepository(
      await SharedPreferences.getInstance(),
    );
    final harness = _Harness([_questions.first], preferences: preferences);
    addTearDown(harness.dispose);

    await harness.controller.startOrRecover();

    expect(harness.state.question?.instanceId, 'ta-a');
    expect(harness.controller.seenQuestionIds, contains('ta-a'));
    expect(harness.state.personalBest, isNull);

    await harness.controller.prepareQuestion((_) async {});
    final question = harness.state.question!;
    harness.controller.selectPosition(_correctPosition(question));
    await Future<void>.delayed(
      TimeAttackController.feedbackDuration + const Duration(milliseconds: 100),
    );

    expect(harness.state.phase, TimeAttackPhase.gameOver);
    expect(harness.state.personalBestUpdated, isTrue);
    expect(harness.state.personalBest?.score, 1);
    expect(harness.state.personalBest?.wrongCount, 0);
    expect(preferences.timeAttackPersonalBest?.score, 1);
    expect(preferences.seenQuestionIds, {'ta-a'});
  });

  test(
    'a zero-score 60 Seconds game does not create a personal best',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = LocalPreferencesRepository(
        await SharedPreferences.getInstance(),
      );
      final harness = _Harness([_questions.first], preferences: preferences);
      addTearDown(harness.dispose);

      await harness.controller.startOrRecover();
      await harness.controller.prepareQuestion((_) async {});
      harness.clock.advance(60000);
      harness.controller.refreshElapsed();
      harness.controller.submitTimeoutIfExpired();
      await Future<void>.delayed(
        TimeAttackController.feedbackDuration +
            const Duration(milliseconds: 100),
      );

      expect(harness.state.phase, TimeAttackPhase.gameOver);
      expect(harness.state.personalBestUpdated, isFalse);
      expect(preferences.timeAttackPersonalBest, isNull);
    },
  );
}

TimeAttackPosition _correctPosition(TimeAttackQuestion question) {
  final canonicalCorrectName = question.instanceId == 'ta-a' ? 'A' : 'B';
  return question.top.name == canonicalCorrectName
      ? TimeAttackPosition.top
      : TimeAttackPosition.bottom;
}

class _Harness {
  _Harness(
    List<LocalGameplayQuestion> questions, {
    LocalPreferencesRepository? preferences,
  }) {
    clock = _Clock();
    container = ProviderContainer(
      overrides: [
        localGameplayQuestionsProvider.overrideWith((ref) async => questions),
        localPreferencesRepositoryProvider.overrideWith(
          (ref) => preferences == null
              ? _freshPreferences()
              : Future.value(preferences),
        ),
        timeAttackClockFactoryProvider.overrideWithValue(() => clock),
        soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
        gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
      ],
    );
    subscription = container.listen(timeAttackControllerProvider, (_, _) {});
  }

  late final _Clock clock;
  late final ProviderContainer container;
  late final ProviderSubscription<TimeAttackState> subscription;

  TimeAttackController get controller =>
      container.read(timeAttackControllerProvider.notifier);
  TimeAttackState get state => container.read(timeAttackControllerProvider);
  void dispose() {
    subscription.close();
    container.dispose();
  }
}

Future<LocalPreferencesRepository> _freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return LocalPreferencesRepository(await SharedPreferences.getInstance());
}

class _Clock implements TimeAttackMonotonicClock {
  var _elapsed = 0;
  var _running = false;
  @override
  int get elapsedMilliseconds => _elapsed;
  @override
  bool get isRunning => _running;
  void advance(int ms) {
    if (_running) _elapsed += ms;
  }

  @override
  void reset() => _elapsed = 0;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
}

final _questions = [
  LocalGameplayQuestion(
    id: 'ta-a',
    questionText: 'Q1',
    optionA: 'A',
    optionB: 'B',
    valueA: 2,
    valueB: 1,
    displayValueA: '2',
    displayValueB: '1',
    comparisonMode: GameplayComparisonMode.higherWins,
    difficulty: GameplayDifficulty.easy,
    category: 'one',
    imageA: 'assets/content/images/ta-a/a.webp',
    imageB: 'assets/content/images/ta-a/b.webp',
  ),
  LocalGameplayQuestion(
    id: 'ta-b',
    questionText: 'Q2',
    optionA: 'A',
    optionB: 'B',
    valueA: 1,
    valueB: 2,
    displayValueA: '1',
    displayValueB: '2',
    comparisonMode: GameplayComparisonMode.higherWins,
    difficulty: GameplayDifficulty.medium,
    category: 'two',
    imageA: 'assets/content/images/ta-b/a.webp',
    imageB: 'assets/content/images/ta-b/b.webp',
  ),
];

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
