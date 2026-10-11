import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onboarding is incomplete by default', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    expect(repository.isOnboardingCompleted, isFalse);
  });

  test('stores onboarding completion', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    await repository.setOnboardingCompleted();

    expect(repository.isOnboardingCompleted, isTrue);
    expect(
      preferences.getBool(LocalPreferencesRepository.onboardingCompletedKey),
      isTrue,
    );
  });

  test(
    'Classic Joker hint is unseen by default and persists once shown',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalPreferencesRepository(preferences);

      expect(repository.hasSeenClassicJokerHint, isFalse);

      await repository.setClassicJokerHintSeen();

      expect(repository.hasSeenClassicJokerHint, isTrue);
      expect(
        preferences.getBool(LocalPreferencesRepository.classicJokerHintSeenKey),
        isTrue,
      );
    },
  );

  test('sound effects are enabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    expect(repository.areSoundEffectsEnabled, isTrue);
  });

  test('stores a disabled sound effects preference', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    await repository.setSoundEffectsEnabled(false);

    expect(repository.areSoundEffectsEnabled, isFalse);
    expect(
      preferences.getBool(LocalPreferencesRepository.soundEffectsEnabledKey),
      isFalse,
    );
  });

  test('a new repository reads the stored sound effects preference', () async {
    SharedPreferences.setMockInitialValues({
      LocalPreferencesRepository.soundEffectsEnabledKey: false,
    });
    final preferences = await SharedPreferences.getInstance();

    expect(
      LocalPreferencesRepository(preferences).areSoundEffectsEnabled,
      isFalse,
    );
  });

  test('empty preferences return safe PB and seen defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    expect(repository.classicPersonalBest, isNull);
    expect(repository.timeAttackPersonalBest, isNull);
    expect(repository.seenQuestionIds, isEmpty);
  });

  test('stores and reads Classic personal best', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);
    const expected = ClassicPersonalBest(score: 7, totalAnswerTimeMs: 42000);

    await repository.setClassicPersonalBest(expected);

    expect(repository.classicPersonalBest?.score, expected.score);
    expect(
      repository.classicPersonalBest?.totalAnswerTimeMs,
      expected.totalAnswerTimeMs,
    );
  });

  test('stores and reads 60 Seconds personal best', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);
    const expected = TimeAttackPersonalBest(score: 12, wrongCount: 3);

    await repository.setTimeAttackPersonalBest(expected);

    expect(repository.timeAttackPersonalBest?.score, expected.score);
    expect(repository.timeAttackPersonalBest?.wrongCount, expected.wrongCount);
  });

  test('stores shared seen question IDs for both gameplay modes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    await repository.setSeenQuestionIds({'question-b', 'question-a'});

    expect(repository.seenQuestionIds, {'question-a', 'question-b'});
    expect(LocalPreferencesRepository(preferences).seenQuestionIds, {
      'question-a',
      'question-b',
    });
  });

  test('does not allow a score of zero to create a personal best', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalPreferencesRepository(preferences);

    await expectLater(
      repository.setClassicPersonalBest(
        const ClassicPersonalBest(score: 0, totalAnswerTimeMs: 1000),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.setTimeAttackPersonalBest(
        const TimeAttackPersonalBest(score: 0, wrongCount: 0),
      ),
      throwsArgumentError,
    );

    expect(repository.classicPersonalBest, isNull);
    expect(repository.timeAttackPersonalBest, isNull);
  });
}
