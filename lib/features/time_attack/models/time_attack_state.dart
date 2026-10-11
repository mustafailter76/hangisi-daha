import 'package:hangisi_daha/features/time_attack/models/time_attack_models.dart';

enum TimeAttackPhase {
  initial,
  starting,
  preparing,
  active,
  feedbackCorrect,
  feedbackIncorrect,
  feedbackTimeout,
  gameOver,
  error,
}

enum TimeAttackRetryAction { start, prepare }

const _notProvided = Object();

class TimeAttackState {
  const TimeAttackState({
    this.phase = TimeAttackPhase.initial,
    this.sessionId,
    this.score = 0,
    this.wrongCount = 0,
    this.serverBaseRemainingMs = 60000,
    this.displayedRemainingMs = 60000,
    this.question,
    this.selectedPosition,
    this.reveal,
    this.feedbackAdjustmentMs,
    this.nextQuestion,
    this.finishReason,
    this.personalBest,
    this.personalBestUpdated = false,
    this.errorMessage,
    this.retryAction,
  });

  final TimeAttackPhase phase;
  final String? sessionId;
  final int score;
  final int wrongCount;
  final int serverBaseRemainingMs;
  final int displayedRemainingMs;
  final TimeAttackQuestion? question;
  final TimeAttackPosition? selectedPosition;
  final TimeAttackReveal? reveal;
  final int? feedbackAdjustmentMs;
  final TimeAttackQuestion? nextQuestion;
  final TimeAttackFinishReason? finishReason;
  final TimeAttackPersonalBest? personalBest;
  final bool personalBestUpdated;
  final String? errorMessage;
  final TimeAttackRetryAction? retryAction;

  bool get acceptsAnswer => phase == TimeAttackPhase.active;

  bool get blocksBackNavigation => switch (phase) {
    TimeAttackPhase.starting ||
    TimeAttackPhase.preparing ||
    TimeAttackPhase.active ||
    TimeAttackPhase.feedbackCorrect ||
    TimeAttackPhase.feedbackIncorrect ||
    TimeAttackPhase.feedbackTimeout => true,
    _ => false,
  };

  int get displayedRemainingSeconds => (displayedRemainingMs + 999) ~/ 1000;

  TimeAttackState copyWith({
    TimeAttackPhase? phase,
    Object? sessionId = _notProvided,
    int? score,
    int? wrongCount,
    int? serverBaseRemainingMs,
    int? displayedRemainingMs,
    Object? question = _notProvided,
    Object? selectedPosition = _notProvided,
    Object? reveal = _notProvided,
    Object? feedbackAdjustmentMs = _notProvided,
    Object? nextQuestion = _notProvided,
    Object? finishReason = _notProvided,
    Object? personalBest = _notProvided,
    bool? personalBestUpdated,
    Object? errorMessage = _notProvided,
    Object? retryAction = _notProvided,
  }) {
    return TimeAttackState(
      phase: phase ?? this.phase,
      sessionId: identical(sessionId, _notProvided)
          ? this.sessionId
          : sessionId as String?,
      score: score ?? this.score,
      wrongCount: wrongCount ?? this.wrongCount,
      serverBaseRemainingMs:
          serverBaseRemainingMs ?? this.serverBaseRemainingMs,
      displayedRemainingMs: displayedRemainingMs ?? this.displayedRemainingMs,
      question: identical(question, _notProvided)
          ? this.question
          : question as TimeAttackQuestion?,
      selectedPosition: identical(selectedPosition, _notProvided)
          ? this.selectedPosition
          : selectedPosition as TimeAttackPosition?,
      reveal: identical(reveal, _notProvided)
          ? this.reveal
          : reveal as TimeAttackReveal?,
      feedbackAdjustmentMs: identical(feedbackAdjustmentMs, _notProvided)
          ? this.feedbackAdjustmentMs
          : feedbackAdjustmentMs as int?,
      nextQuestion: identical(nextQuestion, _notProvided)
          ? this.nextQuestion
          : nextQuestion as TimeAttackQuestion?,
      finishReason: identical(finishReason, _notProvided)
          ? this.finishReason
          : finishReason as TimeAttackFinishReason?,
      personalBest: identical(personalBest, _notProvided)
          ? this.personalBest
          : personalBest as TimeAttackPersonalBest?,
      personalBestUpdated: personalBestUpdated ?? this.personalBestUpdated,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      retryAction: identical(retryAction, _notProvided)
          ? this.retryAction
          : retryAction as TimeAttackRetryAction?,
    );
  }
}
