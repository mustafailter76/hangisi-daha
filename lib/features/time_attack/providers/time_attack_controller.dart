import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart'
    as personal_best;
import 'package:hangisi_daha/domain/gameplay/question_selector.dart';
import 'package:hangisi_daha/domain/gameplay/time_attack/time_attack_game_engine.dart'
    as domain;
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/providers/game_providers.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';
import 'package:hangisi_daha/features/time_attack/models/time_attack_state.dart';
import 'package:hangisi_daha/features/time_attack/providers/time_attack_clock.dart';

typedef TimeAttackQuestionPreload =
    Future<void> Function(TimeAttackQuestion question);

final timeAttackClockFactoryProvider =
    Provider<TimeAttackMonotonicClock Function()>((ref) {
      return StopwatchTimeAttackClock.new;
    });

final timeAttackControllerProvider =
    NotifierProvider.autoDispose<TimeAttackController, TimeAttackState>(
      TimeAttackController.new,
    );

class TimeAttackController extends Notifier<TimeAttackState> {
  static const feedbackDuration = Duration(milliseconds: 400);

  late TimeAttackMonotonicClock _clock;
  Timer? _feedbackTimer;
  domain.TimeAttackGameEngine? _engine;
  LocalPreferencesRepository? _preferences;
  personal_best.TimeAttackPersonalBest? _personalBest;
  var _resolving = false;

  @override
  TimeAttackState build() {
    _clock = ref.read(timeAttackClockFactoryProvider)();
    ref.onDispose(() {
      _clock.stop();
      _feedbackTimer?.cancel();
    });
    return const TimeAttackState();
  }

  Future<void> startOrRecover({Set<String>? seenQuestionIds}) async {
    _clock
      ..stop()
      ..reset();
    _feedbackTimer?.cancel();
    _resolving = false;
    _engine = null;
    _preferences = null;
    _personalBest = null;
    state = const TimeAttackState(phase: TimeAttackPhase.starting);
    try {
      final preferences = await ref.read(
        localPreferencesRepositoryProvider.future,
      );
      if (!ref.mounted) return;
      _preferences = preferences;
      _personalBest = preferences.timeAttackPersonalBest;
      final persistedSeenQuestionIds =
          seenQuestionIds ?? preferences.seenQuestionIds;
      final questions = await ref.read(localGameplayQuestionsProvider.future);
      if (!ref.mounted) return;
      if (questions.where((question) => question.isActive).isEmpty) {
        state = const TimeAttackState(
          phase: TimeAttackPhase.error,
          errorMessage: 'Şu anda oynanabilir soru bulunmuyor.',
          retryAction: TimeAttackRetryAction.start,
        );
        return;
      }
      _engine = domain.TimeAttackGameEngine(
        questions: questions,
        random: DefaultGameplayRandom(),
      );
      final local = _engine!.start(seenQuestionIds: persistedSeenQuestionIds);
      await _persistSeenQuestionIds(local.seenQuestionIds);
      state = TimeAttackState(
        phase: TimeAttackPhase.preparing,
        sessionId: 'local',
        score: local.score,
        wrongCount: local.wrongCount,
        serverBaseRemainingMs: local.remainingActiveBudgetMs,
        displayedRemainingMs: local.remainingActiveBudgetMs,
        question: _question(local.presentation),
        personalBest: _statePersonalBest(_personalBest),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = TimeAttackState(
        phase: TimeAttackPhase.error,
        errorMessage: 'Local içerik yüklenemedi: $error',
        retryAction: TimeAttackRetryAction.start,
      );
    }
  }

  Future<void> prepareQuestion(TimeAttackQuestionPreload preload) async {
    if (state.phase != TimeAttackPhase.preparing || _resolving) return;
    final question = state.question;
    final engine = _engine;
    if (question == null || engine == null) return;
    try {
      await preload(question);
      if (!ref.mounted || state.question?.instanceId != question.instanceId) {
        return;
      }
      final local = engine.activateQuestion();
      state = state.copyWith(
        phase: TimeAttackPhase.active,
        score: local.score,
        wrongCount: local.wrongCount,
        serverBaseRemainingMs: local.remainingActiveBudgetMs,
        displayedRemainingMs: local.remainingActiveBudgetMs,
        errorMessage: null,
        retryAction: null,
      );
      _clock
        ..reset()
        ..start();
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: TimeAttackPhase.error,
        errorMessage: 'Soru hazırlanamadı: $error',
        retryAction: TimeAttackRetryAction.prepare,
      );
    }
  }

  void selectPosition(TimeAttackPosition position) {
    if (!state.acceptsAnswer || _resolving) return;
    unawaited(ref.read(gameHapticServiceProvider).selection());
    _resolve(position);
  }

  void refreshElapsed() {
    if (state.phase != TimeAttackPhase.active ||
        !_clock.isRunning ||
        _resolving) {
      return;
    }
    final remaining = (state.serverBaseRemainingMs - _clock.elapsedMilliseconds)
        .clamp(0, state.serverBaseRemainingMs);
    if (remaining != state.displayedRemainingMs) {
      state = state.copyWith(displayedRemainingMs: remaining);
    }
  }

  void submitTimeoutIfExpired() {
    if (state.phase != TimeAttackPhase.active ||
        state.displayedRemainingMs != 0 ||
        _resolving) {
      return;
    }
    _resolve(null);
  }

  Future<void> retry() => startOrRecover();

  Set<String> get seenQuestionIds => _engine?.state.seenQuestionIds ?? const {};

  void _resolve(TimeAttackPosition? position) {
    if (_resolving || state.phase != TimeAttackPhase.active) return;
    final engine = _engine;
    if (engine == null) return;
    _resolving = true;
    _clock.stop();
    final outcome = engine.answer(
      selectedPosition: position == null
          ? null
          : (position == TimeAttackPosition.top
                ? GameplayPosition.top
                : GameplayPosition.bottom),
      decisionElapsedMs: _clock.elapsedMilliseconds,
    );
    final reveal = TimeAttackReveal(
      answer: AnsweredQuestion(
        correctOption: GameOption.values.byName(outcome.correctOption.name),
        displayValueA: outcome.state.presentation.question.displayValueA,
        displayValueB: outcome.state.presentation.question.displayValueB,
      ),
      correctPosition: TimeAttackPosition.values.byName(
        outcome.state.presentation.correctPosition.name,
      ),
    );
    final phase = switch (outcome.result) {
      GameplayAnswerResult.correct => TimeAttackPhase.feedbackCorrect,
      GameplayAnswerResult.incorrect => TimeAttackPhase.feedbackIncorrect,
      GameplayAnswerResult.timeout => TimeAttackPhase.feedbackTimeout,
    };
    state = state.copyWith(
      phase: phase,
      score: outcome.scoreAfter,
      wrongCount: outcome.state.wrongCount,
      serverBaseRemainingMs: outcome.remainingAfterMs,
      displayedRemainingMs: outcome.remainingAfterMs,
      selectedPosition: position,
      reveal: reveal,
      feedbackAdjustmentMs: outcome.adjustmentMs,
      nextQuestion: outcome.state.isTerminal
          ? null
          : _question(outcome.state.presentation),
      finishReason: _finishReason(outcome.terminalReason),
    );
    if (!outcome.state.isTerminal) {
      unawaited(_persistSeenQuestionIds(outcome.state.seenQuestionIds));
    }
    if (outcome.result == GameplayAnswerResult.correct) {
      unawaited(ref.read(soundEffectServiceProvider).playCorrect());
      unawaited(ref.read(gameHapticServiceProvider).correct());
    } else if (!outcome.state.isTerminal) {
      unawaited(ref.read(soundEffectServiceProvider).playWrong());
      unawaited(ref.read(gameHapticServiceProvider).wrong());
    }
    _feedbackTimer = Timer(feedbackDuration, () {
      unawaited(_afterFeedback(outcome));
    });
  }

  Future<void> _afterFeedback(domain.TimeAttackAnswerOutcome outcome) async {
    if (!ref.mounted) return;
    _resolving = false;
    if (outcome.state.isTerminal) {
      await _finishPersonalBest(outcome.state);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: TimeAttackPhase.gameOver,
        personalBest: _statePersonalBest(_personalBest),
      );
      unawaited(ref.read(soundEffectServiceProvider).playGameOver());
      unawaited(ref.read(gameHapticServiceProvider).gameOver());
      return;
    }
    state = state.copyWith(
      phase: TimeAttackPhase.preparing,
      question: _question(outcome.state.presentation),
      selectedPosition: null,
      reveal: null,
      feedbackAdjustmentMs: null,
      nextQuestion: null,
      finishReason: null,
    );
  }

  TimeAttackQuestion _question(GameplayPresentation presentation) =>
      TimeAttackQuestion(
        instanceId: presentation.question.id,
        questionText: presentation.question.questionText,
        sequenceNumber: presentation.number,
        difficulty: TimeAttackDifficulty.values.byName(
          presentation.question.difficulty.name,
        ),
        phase: TimeAttackQuestionPhase.preparing,
        top: _option(
          presentation,
          GameplayPosition.top,
          TimeAttackPosition.top,
        ),
        bottom: _option(
          presentation,
          GameplayPosition.bottom,
          TimeAttackPosition.bottom,
        ),
      );

  TimeAttackOption _option(
    GameplayPresentation presentation,
    GameplayPosition physical,
    TimeAttackPosition position,
  ) {
    final option = presentation.optionAt(physical);
    return TimeAttackOption(
      position: position,
      name: option == GameplayOption.a
          ? presentation.question.optionA
          : presentation.question.optionB,
      imagePath: option == GameplayOption.a
          ? presentation.question.imageA
          : presentation.question.imageB,
    );
  }

  TimeAttackFinishReason? _finishReason(
    domain.TimeAttackTerminalReason? reason,
  ) => switch (reason) {
    domain.TimeAttackTerminalReason.timeExpired =>
      TimeAttackFinishReason.timeExpired,
    domain.TimeAttackTerminalReason.wrongPenaltyExpired =>
      TimeAttackFinishReason.wrongPenaltyExpired,
    domain.TimeAttackTerminalReason.questionPoolCompleted =>
      TimeAttackFinishReason.questionPoolCompleted,
    null => null,
  };

  Future<void> _persistSeenQuestionIds(Set<String> seenQuestionIds) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setSeenQuestionIds(seenQuestionIds);
    } on Object {
      // Gameplay remains available if local seen-state storage is temporarily
      // unable to persist the result.
    }
  }

  Future<void> _finishPersonalBest(domain.TimeAttackGameState finished) async {
    final candidate = personal_best.TimeAttackPersonalBest(
      score: finished.score,
      wrongCount: finished.wrongCount,
    );
    if (!personal_best.shouldReplaceTimeAttackPersonalBest(
      candidate: candidate,
      current: _personalBest,
    )) {
      return;
    }

    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setTimeAttackPersonalBest(candidate);
      _personalBest = candidate;
      if (ref.mounted) {
        state = state.copyWith(
          personalBest: _statePersonalBest(candidate),
          personalBestUpdated: true,
        );
        ref.invalidate(personalBestsProvider);
      }
    } on Object {
      // Gameplay remains available if local PB storage is temporarily unable
      // to persist the result.
    }
  }

  TimeAttackPersonalBest? _statePersonalBest(
    personal_best.TimeAttackPersonalBest? value,
  ) => value == null
      ? null
      : TimeAttackPersonalBest(
          score: value.score,
          wrongCount: value.wrongCount,
          achievedAt: null,
        );
}
