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
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_controller.dart';
import 'package:hangisi_daha/features/time_attack/time_attack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('local 60 Seconds screen waits for preload and shows feedback', (
    tester,
  ) async {
    await _pumpScreen(tester, _questions);
    expect(find.byKey(const Key('time-attack-status')), findsOneWidget);
    expect(find.byKey(const Key('time-attack-top-card')), findsOneWidget);
    expect(find.byKey(const Key('time-attack-bottom-card')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimeAttackScreen)),
    );
    final question = container.read(timeAttackControllerProvider).question!;
    final correct = question.top.name == 'A'
        ? TimeAttackPosition.top
        : TimeAttackPosition.bottom;
    await tester.tap(find.byKey(Key('time-attack-${correct.name}-card')));
    await tester.pump();

    expect(find.byKey(const Key('time-attack-feedback')), findsOneWidget);
    expect(
      find.byKey(const Key('time-attack-correct-indicator')),
      findsOneWidget,
    );
    expect(find.text('Doğru!'), findsOneWidget);

    await tester.pump(TimeAttackController.feedbackDuration);
    await tester.pump();
    expect(find.byKey(const Key('time-attack-status')), findsOneWidget);
    expect(find.byKey(const Key('time-attack-top-card')), findsOneWidget);
  });

  testWidgets(
    'local 60 Seconds screen explains completed pool and remaining time',
    (tester) async {
      await _pumpScreen(tester, [_questions.first]);
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
      expect(find.text('Soru havuzu tamamlandı'), findsOneWidget);
      expect(find.text('1 sorunun tamamını yanıtladın'), findsOneWidget);
      expect(find.text('Kalan süre: 60 sn'), findsOneWidget);
      expect(find.text('Süre doldu'), findsNothing);
    },
  );
}

Future<void> _pumpScreen(
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
        timeAttackClockFactoryProvider.overrideWithValue(_Clock.new),
        timeAttackImagePreloaderProvider.overrideWithValue(
          (context, imagePaths) async {},
        ),
        soundEffectServiceProvider.overrideWithValue(const _NoopSound()),
        gameHapticServiceProvider.overrideWithValue(const _NoopHaptics()),
      ],
      child: const MaterialApp(home: TimeAttackScreen()),
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
