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
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'local 60 Seconds stays PREPARING until preload then tracks monotonic time',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);

      await harness.controller.startOrRecover();
      expect(harness.state.phase, TimeAttackPhase.preparing);
      harness.clock.advance(5000);
      harness.controller.refreshElapsed();
      expect(harness.state.displayedRemainingMs, 60000);

      await harness.controller.prepareQuestion((_) async {});
      expect(harness.state.phase, TimeAttackPhase.active);
      harness.clock.advance(2345);
      harness.controller.refreshElapsed();
      expect(harness.state.displayedRemainingMs, 57655);
      expect(harness.state.displayedRemainingSeconds, 58);
    },
  );

  test('local 60 Seconds correct feedback resolves only once', () async {
    final harness = _Harness(_questions);
    addTearDown(harness.dispose);
    await harness.startActive();

    final question = harness.state.question!;
    final correct = question.top.name == 'A'
        ? TimeAttackPosition.top
        : TimeAttackPosition.bottom;
    harness.controller.selectPosition(correct);
    harness.controller.selectPosition(correct);

    expect(harness.state.phase, TimeAttackPhase.feedbackCorrect);
    expect(harness.state.score, 1);
    expect(harness.state.feedbackAdjustmentMs, 0);
    expect(harness.state.reveal, isNotNull);
  });

  test(
    'local 60 Seconds timeout and wrong penalty have distinct terminals',
    () async {
      final timeout = _Harness(_questions);
      addTearDown(timeout.dispose);
      await timeout.startActive();
      timeout.clock.advance(60000);
      timeout.controller.refreshElapsed();
      timeout.controller.submitTimeoutIfExpired();

      expect(timeout.state.phase, TimeAttackPhase.feedbackTimeout);
      expect(timeout.state.finishReason, TimeAttackFinishReason.timeExpired);
      expect(timeout.state.displayedRemainingMs, 0);

      final penalty = _Harness(_questions);
      addTearDown(penalty.dispose);
      await penalty.startActive();
      penalty.clock.advance(59000);
      penalty.controller.refreshElapsed();
      final question = penalty.state.question!;
      final wrong = question.top.name == 'A'
          ? TimeAttackPosition.bottom
          : TimeAttackPosition.top;
      penalty.controller.selectPosition(wrong);

      expect(penalty.state.phase, TimeAttackPhase.feedbackIncorrect);
      expect(
        penalty.state.finishReason,
        TimeAttackFinishReason.wrongPenaltyExpired,
      );
      expect(penalty.state.wrongCount, 1);
      expect(penalty.state.feedbackAdjustmentMs, -1000);
    },
  );

  test(
    'local 60 Seconds pool completion preserves feedback and terminal reason',
    () async {
      final harness = _Harness([_questions.first]);
      addTearDown(harness.dispose);
      await harness.startActive();
      final question = harness.state.question!;
      final correct = question.top.name == 'A'
          ? TimeAttackPosition.top
          : TimeAttackPosition.bottom;

      harness.controller.selectPosition(correct);

      expect(harness.state.phase, TimeAttackPhase.feedbackCorrect);
      expect(
        harness.state.finishReason,
        TimeAttackFinishReason.questionPoolCompleted,
      );
      expect(harness.state.nextQuestion, isNull);
    },
  );

  test(
    'local 60 Seconds dispatches semantic sound and haptic feedback',
    () async {
      final sound = _RecordingSound();
      final haptics = _RecordingHaptics();
      final harness = _Harness(_questions, sound: sound, haptics: haptics);
      addTearDown(harness.dispose);
      await harness.startActive();

      final question = harness.state.question!;
      final correct = question.top.name == 'A'
          ? TimeAttackPosition.top
          : TimeAttackPosition.bottom;
      harness.controller.selectPosition(correct);
      await Future<void>.delayed(Duration.zero);

      expect(sound.correctCalls, 1);
      expect(sound.wrongCalls, 0);
      expect(haptics.selectionCalls, 1);
      expect(haptics.correctCalls, 1);
    },
  );
}

class _Harness {
  _Harness(
    List<LocalGameplayQuestion> questions, {
    SoundEffectService? sound,
    GameHapticService? haptics,
  }) {
    clock = _Clock();
    container = ProviderContainer(
      overrides: [
        localGameplayQuestionsProvider.overrideWith((ref) async => questions),
        localPreferencesRepositoryProvider.overrideWith(
          (ref) => _freshPreferences(),
        ),
        timeAttackClockFactoryProvider.overrideWithValue(() => clock),
        soundEffectServiceProvider.overrideWithValue(
          sound ?? const _NoopSound(),
        ),
        gameHapticServiceProvider.overrideWithValue(
          haptics ?? const _NoopHaptics(),
        ),
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

  Future<void> startActive() async {
    await controller.startOrRecover();
    await controller.prepareQuestion((_) async {});
  }

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
  @override
  void reset() => _elapsed = 0;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;

  void advance(int milliseconds) {
    if (_running) _elapsed += milliseconds;
  }
}

final _questions = [_question('a', 2, 1), _question('b', 2, 1)];

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

class _RecordingSound extends _NoopSound {
  var correctCalls = 0;
  var wrongCalls = 0;

  @override
  Future<void> playCorrect() async => correctCalls++;
  @override
  Future<void> playWrong() async => wrongCalls++;
}

class _RecordingHaptics extends _NoopHaptics {
  var selectionCalls = 0;
  var correctCalls = 0;

  @override
  Future<void> selection() async => selectionCalls++;
  @override
  Future<void> correct() async => correctCalls++;
}
