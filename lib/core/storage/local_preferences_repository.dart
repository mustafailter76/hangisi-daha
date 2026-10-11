import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart';

class LocalPreferencesRepository {
  LocalPreferencesRepository(this._preferences);

  static const onboardingCompletedKey = 'onboarding_completed';
  static const soundEffectsEnabledKey = 'sound_effects_enabled';
  static const classicJokerHintSeenKey = 'classic_joker_hint_seen';
  static const classicPersonalBestScoreKey = 'classic_personal_best_score';
  static const classicPersonalBestTimeKey =
      'classic_personal_best_total_answer_time_ms';
  static const timeAttackPersonalBestScoreKey =
      'time_attack_personal_best_score';
  static const timeAttackPersonalBestWrongCountKey =
      'time_attack_personal_best_wrong_count';
  static const seenQuestionIdsKey = 'seen_question_ids';

  final SharedPreferences _preferences;

  bool get isOnboardingCompleted {
    return _preferences.getBool(onboardingCompletedKey) ?? false;
  }

  bool get areSoundEffectsEnabled {
    return _preferences.getBool(soundEffectsEnabledKey) ?? true;
  }

  bool get hasSeenClassicJokerHint {
    return _preferences.getBool(classicJokerHintSeenKey) ?? false;
  }

  ClassicPersonalBest? get classicPersonalBest {
    final score = _preferences.getInt(classicPersonalBestScoreKey);
    final totalAnswerTimeMs = _preferences.getInt(classicPersonalBestTimeKey);
    if (score == null || score <= 0 || totalAnswerTimeMs == null) return null;
    if (totalAnswerTimeMs < 0) return null;
    return ClassicPersonalBest(
      score: score,
      totalAnswerTimeMs: totalAnswerTimeMs,
    );
  }

  TimeAttackPersonalBest? get timeAttackPersonalBest {
    final score = _preferences.getInt(timeAttackPersonalBestScoreKey);
    final wrongCount = _preferences.getInt(timeAttackPersonalBestWrongCountKey);
    if (score == null || score <= 0 || wrongCount == null) return null;
    if (wrongCount < 0) return null;
    return TimeAttackPersonalBest(score: score, wrongCount: wrongCount);
  }

  Set<String> get seenQuestionIds {
    final values = _preferences.getStringList(seenQuestionIdsKey);
    if (values == null) return <String>{};
    return values.where((value) => value.trim().isNotEmpty).toSet();
  }

  Future<void> setOnboardingCompleted() async {
    final didSave = await _preferences.setBool(onboardingCompletedKey, true);
    if (!didSave) {
      throw StateError('Onboarding completion could not be saved.');
    }
  }

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    final didSave = await _preferences.setBool(soundEffectsEnabledKey, enabled);
    if (!didSave) {
      throw StateError('Sound effects preference could not be saved.');
    }
  }

  Future<void> setClassicJokerHintSeen() async {
    final didSave = await _preferences.setBool(classicJokerHintSeenKey, true);
    if (!didSave) {
      throw StateError('Classic Joker hint preference could not be saved.');
    }
  }

  Future<void> setClassicPersonalBest(ClassicPersonalBest value) async {
    if (value.score <= 0 || value.totalAnswerTimeMs < 0) {
      throw ArgumentError('Classic personal best is invalid.');
    }
    await _enqueueWrite(() async {
      final scoreSaved = await _preferences.setInt(
        classicPersonalBestScoreKey,
        value.score,
      );
      final timeSaved = await _preferences.setInt(
        classicPersonalBestTimeKey,
        value.totalAnswerTimeMs,
      );
      return scoreSaved && timeSaved;
    }, 'Classic personal best could not be saved.');
  }

  Future<void> setTimeAttackPersonalBest(TimeAttackPersonalBest value) async {
    if (value.score <= 0 || value.wrongCount < 0) {
      throw ArgumentError('60 Seconds personal best is invalid.');
    }
    await _enqueueWrite(() async {
      final scoreSaved = await _preferences.setInt(
        timeAttackPersonalBestScoreKey,
        value.score,
      );
      final wrongCountSaved = await _preferences.setInt(
        timeAttackPersonalBestWrongCountKey,
        value.wrongCount,
      );
      return scoreSaved && wrongCountSaved;
    }, '60 Seconds personal best could not be saved.');
  }

  Future<void> setSeenQuestionIds(Iterable<String> values) async {
    final ids = values.where((value) => value.trim().isNotEmpty).toSet()
      ..removeWhere((value) => value.trim().isEmpty);
    final sortedIds = ids.toList()..sort();
    await _enqueueWrite(
      () => _preferences.setStringList(seenQuestionIdsKey, sortedIds),
      'Seen question IDs could not be saved.',
    );
  }

  Future<void> _enqueueWrite(
    Future<bool> Function() write,
    String errorMessage,
  ) async {
    final operation = _pendingWrite.then((_) async {
      final didSave = await write();
      if (!didSave) throw StateError(errorMessage);
    });
    _pendingWrite = operation.catchError((_) {});
    await operation;
  }

  Future<void> _pendingWrite = Future<void>.value();
}
