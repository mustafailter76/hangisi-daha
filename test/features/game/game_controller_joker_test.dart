import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/models/game_state.dart';
import 'package:hangisi_daha/features/game/providers/game_controller.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'local Classic exposes one-use jokers and preserves elapsed extension',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);

      await harness.controller.startGame();
      expect(
        ClassicJokerType.values.every(harness.state.canActivateJoker),
        isTrue,
      );

      await harness.controller.activateJoker(ClassicJokerType.extension);

      expect(harness.state.questionAllowanceSeconds, 45);
      expect(harness.state.jokers.extensionUsed, isTrue);
      expect(
        harness.state.jokers.currentQuestionJoker,
        ClassicJokerType.extension,
      );
      expect(harness.state.canActivateJoker(ClassicJokerType.hint), isFalse);
      expect(harness.state.canActivateJoker(ClassicJokerType.shield), isFalse);
    },
  );

  test(
    'local Classic correct feedback reveals the answer and increments score',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);

      await harness.controller.startGame();
      harness.controller.selectOption(GameOption.a);

      expect(harness.state.phase, GamePhase.showingCorrectResult);
      expect(harness.state.score, 1);
      expect(harness.state.selectedOption, GameOption.a);
      expect(harness.state.answeredQuestion?.correctOption, GameOption.a);
      expect(harness.state.nextQuestion, isNotNull);
    },
  );

  test('Shield absorbs a local wrong answer without changing score', () async {
    final harness = _Harness(_questions);
    addTearDown(harness.dispose);

    await harness.controller.startGame();
    await harness.controller.activateJoker(ClassicJokerType.shield);
    final question = harness.state.question!;
    final wrong = GameOption.a == question.topOption
        ? question.bottomOption
        : question.topOption;

    harness.controller.selectOption(wrong);

    expect(harness.state.phase, GamePhase.showingIncorrectResult);
    expect(harness.state.score, 0);
    expect(harness.state.shieldAbsorbed, isTrue);
    expect(harness.state.nextQuestion, isNotNull);
  });

  test('local Classic dispatches correct sound and semantic haptics', () async {
    final sound = _RecordingSound();
    final haptics = _RecordingHaptics();
    final harness = _Harness(_questions, sound: sound, haptics: haptics);
    addTearDown(harness.dispose);

    await harness.controller.startGame();
    harness.controller.selectOption(GameOption.a);
    await Future<void>.delayed(Duration.zero);

    expect(sound.correctCalls, 1);
    expect(sound.gameOverCalls, 0);
    expect(haptics.selectionCalls, 1);
    expect(haptics.correctCalls, 1);
  });
}

class _Harness {
  _Harness(
    List<LocalGameplayQuestion> questions, {
    SoundEffectService? sound,
    GameHapticService? haptics,
  }) : container = ProviderContainer(
         overrides: [
           localGameplayQuestionsProvider.overrideWith(
             (ref) async => questions,
           ),
           localPreferencesRepositoryProvider.overrideWith(
             (ref) => _freshPreferences(),
           ),
           soundEffectServiceProvider.overrideWithValue(
             sound ?? const _NoopSound(),
           ),
           gameHapticServiceProvider.overrideWithValue(
             haptics ?? const _NoopHaptics(),
           ),
         ],
       ) {
    subscription = container.listen(gameControllerProvider, (_, _) {});
  }

  final ProviderContainer container;
  late final ProviderSubscription<GameState> subscription;

  GameController get controller =>
      container.read(gameControllerProvider.notifier);
  GameState get state => container.read(gameControllerProvider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

Future<LocalPreferencesRepository> _freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return LocalPreferencesRepository(await SharedPreferences.getInstance());
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
      hint: 'Hint $id',
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
  var gameOverCalls = 0;

  @override
  Future<void> playCorrect() async => correctCalls++;
  @override
  Future<void> playGameOver() async => gameOverCalls++;
}

class _RecordingHaptics extends _NoopHaptics {
  var selectionCalls = 0;
  var correctCalls = 0;

  @override
  Future<void> selection() async => selectionCalls++;
  @override
  Future<void> correct() async => correctCalls++;
}
