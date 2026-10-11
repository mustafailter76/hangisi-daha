import 'package:hangisi_daha/features/game/models/game_models.dart';

enum GamePhase {
  initial,
  starting,
  questionActive,
  submitting,
  showingCorrectResult,
  showingIncorrectResult,
  timeout,
  gameOver,
  error,
}

enum GameRetryAction { start, submit }

const _notProvided = Object();

class GameState {
  const GameState({
    this.phase = GamePhase.initial,
    this.sessionId,
    this.score = 0,
    this.question,
    this.remainingSeconds = 15,
    this.questionAllowanceSeconds = 15,
    this.jokers = const ClassicJokerInventory.unused(),
    this.hintText,
    this.shieldAbsorbed = false,
    this.jokerRequestType,
    this.jokerRequestId,
    this.jokerRequestQuestionId,
    this.isJokerActivationPending = false,
    this.jokerErrorMessage,
    this.selectedOption,
    this.answeredQuestion,
    this.nextQuestion,
    this.bestScore = 0,
    this.bestScoreKnown = false,
    this.isNewRecord = false,
    this.finishReason,
    this.errorMessage,
    this.retryAction,
  });

  final GamePhase phase;
  final String? sessionId;
  final int score;
  final GameQuestion? question;
  final int remainingSeconds;
  final int questionAllowanceSeconds;
  final ClassicJokerInventory jokers;
  final String? hintText;
  final bool shieldAbsorbed;
  final ClassicJokerType? jokerRequestType;
  final String? jokerRequestId;
  final String? jokerRequestQuestionId;
  final bool isJokerActivationPending;
  final String? jokerErrorMessage;
  final GameOption? selectedOption;
  final AnsweredQuestion? answeredQuestion;
  final GameQuestion? nextQuestion;
  final int bestScore;
  final bool bestScoreKnown;
  final bool isNewRecord;
  final ClassicFinishReason? finishReason;
  final String? errorMessage;
  final GameRetryAction? retryAction;

  bool get acceptsAnswerInput =>
      phase == GamePhase.questionActive &&
      !isJokerActivationPending &&
      jokerRequestId == null;

  bool canActivateJoker(ClassicJokerType type) {
    if (phase != GamePhase.questionActive || isJokerActivationPending) {
      return false;
    }
    if (jokers.currentQuestionJoker != null || jokers.isUsed(type)) {
      return false;
    }
    if (jokerRequestId != null) {
      return jokerRequestType == type && jokerRequestQuestionId == question?.id;
    }
    return true;
  }

  bool get blocksBackNavigation => switch (phase) {
    GamePhase.starting ||
    GamePhase.questionActive ||
    GamePhase.submitting ||
    GamePhase.showingCorrectResult ||
    GamePhase.showingIncorrectResult ||
    GamePhase.timeout => true,
    _ => false,
  };

  GameState copyWith({
    GamePhase? phase,
    Object? sessionId = _notProvided,
    int? score,
    Object? question = _notProvided,
    int? remainingSeconds,
    int? questionAllowanceSeconds,
    ClassicJokerInventory? jokers,
    Object? hintText = _notProvided,
    bool? shieldAbsorbed,
    Object? jokerRequestType = _notProvided,
    Object? jokerRequestId = _notProvided,
    Object? jokerRequestQuestionId = _notProvided,
    bool? isJokerActivationPending,
    Object? jokerErrorMessage = _notProvided,
    Object? selectedOption = _notProvided,
    Object? answeredQuestion = _notProvided,
    Object? nextQuestion = _notProvided,
    int? bestScore,
    bool? bestScoreKnown,
    bool? isNewRecord,
    Object? finishReason = _notProvided,
    Object? errorMessage = _notProvided,
    Object? retryAction = _notProvided,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      sessionId: identical(sessionId, _notProvided)
          ? this.sessionId
          : sessionId as String?,
      score: score ?? this.score,
      question: identical(question, _notProvided)
          ? this.question
          : question as GameQuestion?,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      questionAllowanceSeconds:
          questionAllowanceSeconds ?? this.questionAllowanceSeconds,
      jokers: jokers ?? this.jokers,
      hintText: identical(hintText, _notProvided)
          ? this.hintText
          : hintText as String?,
      shieldAbsorbed: shieldAbsorbed ?? this.shieldAbsorbed,
      jokerRequestType: identical(jokerRequestType, _notProvided)
          ? this.jokerRequestType
          : jokerRequestType as ClassicJokerType?,
      jokerRequestId: identical(jokerRequestId, _notProvided)
          ? this.jokerRequestId
          : jokerRequestId as String?,
      jokerRequestQuestionId: identical(jokerRequestQuestionId, _notProvided)
          ? this.jokerRequestQuestionId
          : jokerRequestQuestionId as String?,
      isJokerActivationPending:
          isJokerActivationPending ?? this.isJokerActivationPending,
      jokerErrorMessage: identical(jokerErrorMessage, _notProvided)
          ? this.jokerErrorMessage
          : jokerErrorMessage as String?,
      selectedOption: identical(selectedOption, _notProvided)
          ? this.selectedOption
          : selectedOption as GameOption?,
      answeredQuestion: identical(answeredQuestion, _notProvided)
          ? this.answeredQuestion
          : answeredQuestion as AnsweredQuestion?,
      nextQuestion: identical(nextQuestion, _notProvided)
          ? this.nextQuestion
          : nextQuestion as GameQuestion?,
      bestScore: bestScore ?? this.bestScore,
      bestScoreKnown: bestScoreKnown ?? this.bestScoreKnown,
      isNewRecord: isNewRecord ?? this.isNewRecord,
      finishReason: identical(finishReason, _notProvided)
          ? this.finishReason
          : finishReason as ClassicFinishReason?,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      retryAction: identical(retryAction, _notProvided)
          ? this.retryAction
          : retryAction as GameRetryAction?,
    );
  }
}
