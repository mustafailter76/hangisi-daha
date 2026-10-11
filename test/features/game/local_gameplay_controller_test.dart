import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/models/game_state.dart';
import 'package:hangisi_daha/features/game/game_screen.dart';
import 'package:hangisi_daha/features/game/providers/game_controller.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'empty bundled content produces a controlled unavailable state',
    () async {
      final harness = _Harness(const []);
      addTearDown(harness.dispose);

      await harness.controller.startGame();

      expect(harness.state.phase, GamePhase.error);
      expect(
        harness.state.errorMessage,
        'Şu anda oynanabilir soru bulunmuyor.',
      );
    },
  );

  testWidgets('Classic screen renders an empty-content state', (tester) async {
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
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Şu anda oynanabilir soru bulunmuyor.'), findsOneWidget);
  });

  test(
    'local presentation maps physical cards and resolves only once',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);
      await harness.controller.startGame();
      final first = harness.state.question!;

      expect(
        {first.topOption, first.bottomOption},
        {GameOption.a, GameOption.b},
      );
      final correct = first.id == 'a' ? GameOption.b : GameOption.a;
      harness.controller.selectOption(
        first.topOption == correct ? first.topOption : first.bottomOption,
      );
      harness.controller.selectOption(first.topOption);

      expect(harness.state.phase, GamePhase.showingCorrectResult);
      expect(harness.state.score, 1);
    },
  );

  test(
    'local joker state preserves elapsed windows and shield absorbs a wrong answer',
    () async {
      final harness = _Harness(_questions);
      addTearDown(harness.dispose);
      await harness.controller.startGame();

      await harness.controller.activateJoker(ClassicJokerType.extension);
      expect(harness.state.questionAllowanceSeconds, 45);
      expect(harness.state.jokers.extensionUsed, isTrue);

      await harness.controller.startGame();
      await harness.controller.activateJoker(ClassicJokerType.shield);
      final question = harness.state.question!;
      final correct = question.id == 'a' ? GameOption.b : GameOption.a;
      final wrong = question.topOption == correct
          ? question.bottomOption
          : question.topOption;
      harness.controller.selectOption(wrong);

      expect(harness.state.phase, GamePhase.showingIncorrectResult);
      expect(harness.state.shieldAbsorbed, isTrue);
    },
  );

  test(
    'hydrates shared seen IDs and persists Classic PB at game end',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalPreferencesRepository.seenQuestionIdsKey: ['a'],
      });
      final preferences = LocalPreferencesRepository(
        await SharedPreferences.getInstance(),
      );
      final harness = _Harness([_questions.first], preferences: preferences);
      addTearDown(harness.dispose);

      await harness.controller.startGame();

      expect(harness.state.question?.id, 'a');
      expect(harness.controller.seenQuestionIds, contains('a'));
      expect(harness.state.bestScore, 0);
      expect(harness.state.bestScoreKnown, isTrue);

      final question = harness.state.question!;
      final correct = question.topOption == GameOption.b
          ? question.topOption
          : question.bottomOption;
      harness.controller.selectOption(correct);
      await Future<void>.delayed(
        GameController.resultDisplayDuration + const Duration(milliseconds: 50),
      );

      expect(harness.state.phase, GamePhase.gameOver);
      expect(harness.state.bestScore, 1);
      expect(harness.state.isNewRecord, isTrue);
      expect(preferences.classicPersonalBest?.score, 1);
      expect(preferences.seenQuestionIds, {'a'});
    },
  );

  test('a zero-score Classic game does not create a personal best', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = LocalPreferencesRepository(
      await SharedPreferences.getInstance(),
    );
    final harness = _Harness([_questions.first], preferences: preferences);
    addTearDown(harness.dispose);

    await harness.controller.startGame();
    final question = harness.state.question!;
    final wrong = question.topOption == GameOption.b
        ? question.bottomOption
        : question.topOption;
    harness.controller.selectOption(wrong);
    await Future<void>.delayed(
      GameController.resultDisplayDuration + const Duration(milliseconds: 50),
    );

    expect(harness.state.phase, GamePhase.gameOver);
    expect(harness.state.bestScore, 0);
    expect(harness.state.isNewRecord, isFalse);
    expect(preferences.classicPersonalBest, isNull);
  });
}

class _Harness {
  _Harness(
    List<LocalGameplayQuestion> questions, {
    LocalPreferencesRepository? preferences,
  }) : container = ProviderContainer(
         overrides: [
           localGameplayQuestionsProvider.overrideWith(
             (ref) async => questions,
           ),
           localPreferencesRepositoryProvider.overrideWith(
             (ref) => preferences == null
                 ? _freshPreferences()
                 : Future.value(preferences),
           ),
           soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
           gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
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

final _questions = [
  LocalGameplayQuestion(
    id: 'a',
    questionText: 'Q1',
    optionA: 'A',
    optionB: 'B',
    valueA: 1,
    valueB: 2,
    displayValueA: '1',
    displayValueB: '2',
    comparisonMode: GameplayComparisonMode.higherWins,
    difficulty: GameplayDifficulty.easy,
    category: 'one',
    hint: 'h',
    imageA: 'assets/content/images/a/a.webp',
    imageB: 'assets/content/images/a/b.webp',
  ),
  LocalGameplayQuestion(
    id: 'b',
    questionText: 'Q2',
    optionA: 'A',
    optionB: 'B',
    valueA: 3,
    valueB: 1,
    displayValueA: '3',
    displayValueB: '1',
    comparisonMode: GameplayComparisonMode.higherWins,
    difficulty: GameplayDifficulty.easy,
    category: 'two',
    hint: 'h',
    imageA: 'assets/content/images/b/a.webp',
    imageB: 'assets/content/images/b/b.webp',
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
