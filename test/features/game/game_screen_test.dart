import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/game/game_screen.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/providers/game_controller.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('local Classic screen renders feedback and terminal pool state', (
    tester,
  ) async {
    await _pumpGame(tester, [_question('only', 2, 1)]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final question = container.read(gameControllerProvider).question!;

    final correctPhysical = question.topOption == GameOption.a
        ? question.topOption
        : question.bottomOption;
    await tester.tap(find.byKey(Key('option-${correctPhysical.name}-card')));
    await tester.pump();
    expect(find.text('Doğru seçim'), findsOneWidget);
    expect(find.byKey(const Key('correct-answer-motion')), findsOneWidget);

    await tester.pump(GameController.resultDisplayDuration);
    await tester.pump();
    expect(
      find.byKey(const Key('classic-question-pool-completed-message')),
      findsOneWidget,
    );
  });

  testWidgets('local Classic screen keeps the terminal wrong path', (
    tester,
  ) async {
    await _pumpGame(tester, [_question('only', 2, 1)]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final question = container.read(gameControllerProvider).question!;
    final wrong = question.topOption == GameOption.a
        ? question.bottomOption
        : question.topOption;

    await tester.tap(find.byKey(Key('option-${wrong.name}-card')));
    await tester.pump();
    expect(find.text('Yanlış seçim'), findsOneWidget);
    await tester.pump(GameController.resultDisplayDuration);
    await tester.pump();
    expect(find.text('Oyun Bitti'), findsOneWidget);
  });
}

Future<void> _pumpGame(
  WidgetTester tester,
  List<LocalGameplayQuestion> questions,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localGameplayQuestionsProvider.overrideWith((ref) async => questions),
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
}

Future<LocalPreferencesRepository> _freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return LocalPreferencesRepository(await SharedPreferences.getInstance());
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
