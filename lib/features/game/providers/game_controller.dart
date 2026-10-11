import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';
import 'package:hangisi_daha/core/haptics/game_haptic_service.dart';
import 'package:hangisi_daha/core/storage/local_preferences_providers.dart';
import 'package:hangisi_daha/core/storage/local_preferences_repository.dart';
import 'package:hangisi_daha/domain/gameplay/classic/classic_game_engine.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart';
import 'package:hangisi_daha/domain/gameplay/question_selector.dart';
import 'package:hangisi_daha/features/game/models/game_models.dart';
import 'package:hangisi_daha/features/game/models/game_state.dart';
import 'package:hangisi_daha/features/game/providers/game_providers.dart';
import 'package:hangisi_daha/features/local_content/local_content_providers.dart';

final gameControllerProvider =
    NotifierProvider.autoDispose<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  static const questionDurationSeconds = 15;
  static const resultDisplayDuration = Duration(seconds: 2);

  Timer? _questionTimer;
  Timer? _resultTimer;
  Stopwatch? _questionStopwatch;
  ClassicGameEngine? _engine;
  LocalPreferencesRepository? _preferences;
  ClassicPersonalBest? _personalBest;
  var _resolving = false;

  @override
  GameState build() {
    ref.onDispose(_cancelTimers);
    return const GameState();
  }

  Future<void> startGame({Set<String>? seenQuestionIds}) async {
    _cancelTimers();
    _resolving = false;
    _engine = null;
    _preferences = null;
    _personalBest = null;
    state = const GameState(phase: GamePhase.starting);
    try {
      final preferences = await ref.read(
        localPreferencesRepositoryProvider.future,
      );
      if (!ref.mounted) return;
      _preferences = preferences;
      _personalBest = preferences.classicPersonalBest;
      final persistedSeenQuestionIds =
          seenQuestionIds ?? preferences.seenQuestionIds;
      final questions = await ref.read(localGameplayQuestionsProvider.future);
      if (!ref.mounted) return;
      if (questions.where((question) => question.isActive).isEmpty) {
        state = const GameState(
          phase: GamePhase.error,
          errorMessage: 'Şu anda oynanabilir soru bulunmuyor.',
          retryAction: GameRetryAction.start,
        );
        return;
      }
      _engine = ClassicGameEngine(
        questions: questions,
        random: DefaultGameplayRandom(),
      );
      final local = _engine!.start(seenQuestionIds: persistedSeenQuestionIds);
      await _persistSeenQuestionIds(local.seenQuestionIds);
      state = GameState(
        phase: GamePhase.questionActive,
        sessionId: 'local',
        score: local.score,
        question: _question(local.presentation),
        remainingSeconds: questionDurationSeconds,
        questionAllowanceSeconds: questionDurationSeconds,
        jokers: _jokers(local.jokers),
        bestScore: _personalBest?.score ?? 0,
        bestScoreKnown: true,
      );
      _startQuestionTimer();
    } catch (error) {
      if (!ref.mounted) return;
      state = GameState(
        phase: GamePhase.error,
        errorMessage: 'Local içerik yüklenemedi: $error',
        retryAction: GameRetryAction.start,
      );
    }
  }

  void selectOption(GameOption option) {
    if (!state.acceptsAnswerInput || _resolving) return;
    final question = state.question;
    if (question == null) return;
    unawaited(ref.read(gameHapticServiceProvider).selection());
    _resolve(
      selectedPosition: question.topOption == option
          ? GameplayPosition.top
          : GameplayPosition.bottom,
    );
  }

  Future<void> activateJoker(ClassicJokerType type) async {
    if (!state.canActivateJoker(type) || _resolving) return;
    final engine = _engine;
    if (engine == null) return;
    try {
      final activation = engine.activateJoker(
        joker: _localJoker(type),
        decisionElapsedMs: _elapsedMs,
      );
      state = state.copyWith(
        jokers: _jokers(activation.state.jokers),
        hintText: activation.hintText,
        questionAllowanceSeconds: activation.answerWindowMs ~/ 1000,
        remainingSeconds: _remainingSeconds(activation.answerWindowMs),
        jokerRequestType: null,
        jokerRequestId: null,
        jokerRequestQuestionId: null,
        isJokerActivationPending: false,
        jokerErrorMessage: null,
      );
      unawaited(_playJokerActivation(type));
      unawaited(ref.read(gameHapticServiceProvider).jokerActivated());
      _startQuestionTimer();
    } catch (error) {
      state = state.copyWith(jokerErrorMessage: error.toString());
    }
  }

  Future<void> retry() => startGame();

  Set<String> get seenQuestionIds => _engine?.state.seenQuestionIds ?? const {};

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionStopwatch ??= Stopwatch();
    if (!_questionStopwatch!.isRunning) {
      _questionStopwatch!.start();
    }
    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!ref.mounted ||
          state.phase != GamePhase.questionActive ||
          _resolving) {
        return;
      }
      final remaining = _remainingSeconds(
        _engine?.state.answerWindowMs ?? 15000,
      );
      if (remaining == 0) {
        _resolve(selectedPosition: null);
      } else if (remaining != state.remainingSeconds) {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  void _resolve({required GameplayPosition? selectedPosition}) {
    if (_resolving || state.phase != GamePhase.questionActive) return;
    final engine = _engine;
    if (engine == null) return;
    _resolving = true;
    _questionTimer?.cancel();
    _questionStopwatch?.stop();
    final outcome = engine.answer(
      selectedPosition: selectedPosition,
      decisionElapsedMs: _elapsedMs,
    );
    final selected = selectedPosition == null
        ? null
        : (selectedPosition == GameplayPosition.top
              ? state.question!.topOption
              : state.question!.bottomOption);
    final reveal = AnsweredQuestion(
      correctOption: _gameOption(outcome.correctOption),
      displayValueA: outcome.state.presentation.question.displayValueA,
      displayValueB: outcome.state.presentation.question.displayValueB,
    );
    final phase = switch (outcome.result) {
      GameplayAnswerResult.correct => GamePhase.showingCorrectResult,
      GameplayAnswerResult.incorrect => GamePhase.showingIncorrectResult,
      GameplayAnswerResult.timeout => GamePhase.timeout,
    };
    state = state.copyWith(
      phase: phase,
      score: outcome.scoreAfter,
      selectedOption: selected,
      answeredQuestion: reveal,
      nextQuestion: outcome.state.isTerminal
          ? null
          : _question(outcome.state.presentation),
      shieldAbsorbed: outcome.shieldAbsorbed,
      jokers: _jokers(outcome.state.jokers),
      finishReason:
          outcome.terminalReason == ClassicTerminalReason.questionPoolCompleted
          ? ClassicFinishReason.questionPoolCompleted
          : null,
    );
    if (!outcome.state.isTerminal) {
      unawaited(_persistSeenQuestionIds(outcome.state.seenQuestionIds));
    }
    if (outcome.result == GameplayAnswerResult.correct) {
      unawaited(ref.read(soundEffectServiceProvider).playCorrect());
      unawaited(ref.read(gameHapticServiceProvider).correct());
    } else if (outcome.shieldAbsorbed) {
      unawaited(ref.read(soundEffectServiceProvider).playShieldImpact());
      unawaited(ref.read(gameHapticServiceProvider).shieldAbsorbed());
    } else {
      unawaited(ref.read(soundEffectServiceProvider).playGameOver());
      unawaited(ref.read(gameHapticServiceProvider).gameOver());
    }
    _resultTimer = Timer(resultDisplayDuration, () {
      unawaited(_afterFeedback(outcome));
    });
  }

  Future<void> _afterFeedback(ClassicAnswerOutcome outcome) async {
    if (!ref.mounted) return;
    _resolving = false;
    if (outcome.state.isTerminal) {
      await _finishPersonalBest(outcome.state);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: GamePhase.gameOver,
        bestScore: _personalBest?.score ?? 0,
        bestScoreKnown: true,
      );
      return;
    }
    state = state.copyWith(
      phase: GamePhase.questionActive,
      question: _question(outcome.state.presentation),
      remainingSeconds: questionDurationSeconds,
      questionAllowanceSeconds: questionDurationSeconds,
      jokers: _jokers(outcome.state.jokers),
      hintText: null,
      shieldAbsorbed: false,
      selectedOption: null,
      answeredQuestion: null,
      nextQuestion: null,
      finishReason: null,
    );
    _questionStopwatch = Stopwatch()..start();
    _startQuestionTimer();
  }

  int get _elapsedMs => _questionStopwatch?.elapsedMilliseconds ?? 0;

  int _remainingSeconds(int windowMs) {
    final remaining = windowMs - _elapsedMs;
    return remaining <= 0 ? 0 : (remaining + 999) ~/ 1000;
  }

  void _cancelTimers() {
    _questionTimer?.cancel();
    _resultTimer?.cancel();
    _questionStopwatch?.stop();
  }

  GameQuestion _question(GameplayPresentation presentation) => GameQuestion(
    id: presentation.question.id,
    questionText: presentation.question.questionText,
    optionAName: presentation.question.optionA,
    optionAImagePath: presentation.question.imageA,
    optionBName: presentation.question.optionB,
    optionBImagePath: presentation.question.imageB,
    questionNumber: presentation.number,
    topOption: _gameOption(presentation.topOption),
    bottomOption: _gameOption(presentation.bottomOption),
  );

  ClassicJokerInventory _jokers(ClassicJokerState value) =>
      ClassicJokerInventory(
        extensionUsed: value.extensionUsed,
        hintUsed: value.hintUsed,
        shieldUsed: value.shieldUsed,
        currentQuestionJoker: value.currentQuestionJoker == null
            ? null
            : ClassicJokerType.values.byName(value.currentQuestionJoker!.name),
      );

  ClassicJoker _localJoker(ClassicJokerType value) =>
      ClassicJoker.values.byName(value.name);

  GameOption _gameOption(GameplayOption value) =>
      GameOption.values.byName(value.name);

  Future<void> _playJokerActivation(ClassicJokerType type) => switch (type) {
    ClassicJokerType.extension =>
      ref.read(soundEffectServiceProvider).playExtension(),
    ClassicJokerType.hint => ref.read(soundEffectServiceProvider).playHint(),
    ClassicJokerType.shield =>
      ref.read(soundEffectServiceProvider).playShieldActivate(),
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

  Future<void> _finishPersonalBest(ClassicGameState finished) async {
    final candidate = ClassicPersonalBest(
      score: finished.score,
      totalAnswerTimeMs: finished.totalAnswerTimeMs,
    );
    if (!shouldReplaceClassicPersonalBest(
      candidate: candidate,
      current: _personalBest,
    )) {
      return;
    }

    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setClassicPersonalBest(candidate);
      _personalBest = candidate;
      if (ref.mounted) {
        state = state.copyWith(isNewRecord: true);
        ref.invalidate(personalBestsProvider);
      }
    } on Object {
      // Gameplay remains available if local PB storage is temporarily unable
      // to persist the result.
    }
  }
}
