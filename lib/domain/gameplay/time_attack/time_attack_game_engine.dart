import '../gameplay_models.dart';
import '../position_balancer.dart';
import '../question_selector.dart';

enum TimeAttackQuestionPhase { preparing, active }

enum TimeAttackTerminalReason {
  timeExpired,
  wrongPenaltyExpired,
  questionPoolCompleted,
}

class TimeAttackGameState {
  const TimeAttackGameState({
    required this.score,
    required this.wrongCount,
    required this.consecutiveWrongCount,
    required this.remainingActiveBudgetMs,
    required this.presentation,
    required this.questionPhase,
    required this.usedQuestionIds,
    required this.seenQuestionIds,
    required this.answeredCategories,
    required this.positionBalance,
    this.terminalReason,
  });

  final int score;
  final int wrongCount;
  final int consecutiveWrongCount;
  final int remainingActiveBudgetMs;
  final GameplayPresentation presentation;
  final TimeAttackQuestionPhase questionPhase;
  final Set<String> usedQuestionIds;
  final Set<String> seenQuestionIds;
  final List<String> answeredCategories;
  final PositionBalanceState positionBalance;
  final TimeAttackTerminalReason? terminalReason;

  bool get isTerminal => terminalReason != null;
}

class TimeAttackAnswerOutcome {
  const TimeAttackAnswerOutcome({
    required this.result,
    required this.correctOption,
    required this.selectedOption,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.adjustmentMs,
    required this.remainingBeforeMs,
    required this.remainingAfterMs,
    required this.state,
  });

  final GameplayAnswerResult result;
  final GameplayOption correctOption;
  final GameplayOption? selectedOption;
  final int scoreBefore;
  final int scoreAfter;
  final int adjustmentMs;
  final int remainingBeforeMs;
  final int remainingAfterMs;
  final TimeAttackGameState state;

  TimeAttackTerminalReason? get terminalReason => state.terminalReason;
  GameplayPresentation? get nextPresentation =>
      state.isTerminal ? null : state.presentation;
}

class TimeAttackGameEngine {
  TimeAttackGameEngine({
    required Iterable<LocalGameplayQuestion> questions,
    required GameplayRandom random,
  }) : _questions = List.unmodifiable(questions),
       _selector = QuestionSelector(random),
       _balancer = PositionBalancer(random);

  static const initialActiveBudgetMs = 60000;

  final List<LocalGameplayQuestion> _questions;
  final QuestionSelector _selector;
  final PositionBalancer _balancer;
  late TimeAttackGameState _state;

  TimeAttackGameState get state => _state;

  TimeAttackGameState start({Set<String> seenQuestionIds = const {}}) {
    final selected = _select(
      sequenceNumber: 1,
      usedQuestionIds: const {},
      seenQuestionIds: seenQuestionIds,
      answeredCategories: const [],
    );
    if (selected.question == null) {
      throw StateError('No active questions are available.');
    }
    final presented = _balancer.present(
      question: selected.question!,
      number: 1,
      balanceState: const PositionBalanceState(),
    );
    return _state = TimeAttackGameState(
      score: 0,
      wrongCount: 0,
      consecutiveWrongCount: 0,
      remainingActiveBudgetMs: initialActiveBudgetMs,
      presentation: presented.presentation,
      questionPhase: TimeAttackQuestionPhase.preparing,
      usedQuestionIds: {selected.question!.id},
      seenQuestionIds: selected.seenQuestionIds,
      answeredCategories: const [],
      positionBalance: presented.nextBalanceState,
    );
  }

  TimeAttackGameState activateQuestion() {
    _requireActive();
    if (_state.questionPhase != TimeAttackQuestionPhase.preparing) {
      throw StateError('Only a preparing question can be activated.');
    }
    return _state = _with(questionPhase: TimeAttackQuestionPhase.active);
  }

  TimeAttackAnswerOutcome answer({
    required GameplayPosition? selectedPosition,
    required int decisionElapsedMs,
  }) {
    _requireActive();
    if (_state.questionPhase != TimeAttackQuestionPhase.active) {
      throw StateError('Only an active question can receive an answer.');
    }
    if (decisionElapsedMs < 0) {
      throw ArgumentError.value(decisionElapsedMs);
    }

    final current = _state.presentation;
    final remainingBefore = _state.remainingActiveBudgetMs;
    final selectedOption = selectedPosition == null
        ? null
        : current.optionAt(selectedPosition);
    if (decisionElapsedMs >= remainingBefore) {
      _state = _with(
        remainingActiveBudgetMs: 0,
        terminalReason: TimeAttackTerminalReason.timeExpired,
      );
      return _outcome(
        result: GameplayAnswerResult.timeout,
        selectedOption: selectedOption,
        scoreBefore: _state.score,
        adjustmentMs: 0,
        remainingBeforeMs: remainingBefore,
      );
    }
    if (selectedPosition == null) {
      throw StateError('A timeout cannot resolve before active budget ends.');
    }

    final isCorrect = selectedOption == current.question.correctOption;
    final result = isCorrect
        ? GameplayAnswerResult.correct
        : GameplayAnswerResult.incorrect;
    final scoreBefore = _state.score;
    final scoreAfter = scoreBefore + (isCorrect ? 1 : 0);
    final consecutiveWrongCount = isCorrect
        ? 0
        : _state.consecutiveWrongCount + 1;
    final wrongCount = _state.wrongCount + (isCorrect ? 0 : 1);
    final adjustmentMs = isCorrect
        ? 0
        : -_wrongPenaltyMs(consecutiveWrongCount);
    final remainingAfter = (remainingBefore - decisionElapsedMs + adjustmentMs)
        .clamp(0, initialActiveBudgetMs);
    final answeredCategories = [
      ..._state.answeredCategories,
      current.question.category,
    ];

    if (remainingAfter == 0 && !isCorrect) {
      _state = _with(
        score: scoreAfter,
        wrongCount: wrongCount,
        consecutiveWrongCount: consecutiveWrongCount,
        remainingActiveBudgetMs: 0,
        answeredCategories: answeredCategories,
        terminalReason: TimeAttackTerminalReason.wrongPenaltyExpired,
      );
      return _outcome(
        result: result,
        selectedOption: selectedOption,
        scoreBefore: scoreBefore,
        adjustmentMs: adjustmentMs,
        remainingBeforeMs: remainingBefore,
      );
    }

    final nextSequence = current.number + 1;
    final selected = _select(
      sequenceNumber: nextSequence,
      usedQuestionIds: _state.usedQuestionIds,
      seenQuestionIds: _state.seenQuestionIds,
      answeredCategories: answeredCategories,
    );
    if (selected.question == null) {
      _state = _with(
        score: scoreAfter,
        wrongCount: wrongCount,
        consecutiveWrongCount: consecutiveWrongCount,
        remainingActiveBudgetMs: remainingAfter,
        seenQuestionIds: selected.seenQuestionIds,
        answeredCategories: answeredCategories,
        terminalReason: TimeAttackTerminalReason.questionPoolCompleted,
      );
      return _outcome(
        result: result,
        selectedOption: selectedOption,
        scoreBefore: scoreBefore,
        adjustmentMs: adjustmentMs,
        remainingBeforeMs: remainingBefore,
      );
    }

    final next = _balancer.present(
      question: selected.question!,
      number: nextSequence,
      balanceState: _state.positionBalance,
    );
    _state = TimeAttackGameState(
      score: scoreAfter,
      wrongCount: wrongCount,
      consecutiveWrongCount: consecutiveWrongCount,
      remainingActiveBudgetMs: remainingAfter,
      presentation: next.presentation,
      questionPhase: TimeAttackQuestionPhase.preparing,
      usedQuestionIds: {..._state.usedQuestionIds, selected.question!.id},
      seenQuestionIds: selected.seenQuestionIds,
      answeredCategories: List.unmodifiable(answeredCategories),
      positionBalance: next.nextBalanceState,
    );
    return _outcome(
      result: result,
      selectedOption: selectedOption,
      scoreBefore: scoreBefore,
      adjustmentMs: adjustmentMs,
      remainingBeforeMs: remainingBefore,
    );
  }

  QuestionSelectionResult _select({
    required int sequenceNumber,
    required Set<String> usedQuestionIds,
    required Set<String> seenQuestionIds,
    required List<String> answeredCategories,
  }) => _selector.select(
    QuestionSelectionRequest(
      questions: _questions,
      preferredDifficulty: _difficultyForSequence(sequenceNumber),
      usedQuestionIds: usedQuestionIds,
      seenQuestionIds: seenQuestionIds,
      recentAnsweredCategories: answeredCategories,
    ),
  );

  TimeAttackAnswerOutcome _outcome({
    required GameplayAnswerResult result,
    required GameplayOption? selectedOption,
    required int scoreBefore,
    required int adjustmentMs,
    required int remainingBeforeMs,
  }) => TimeAttackAnswerOutcome(
    result: result,
    correctOption: _state.presentation.question.correctOption,
    selectedOption: selectedOption,
    scoreBefore: scoreBefore,
    scoreAfter: _state.score,
    adjustmentMs: adjustmentMs,
    remainingBeforeMs: remainingBeforeMs,
    remainingAfterMs: _state.remainingActiveBudgetMs,
    state: _state,
  );

  TimeAttackGameState _with({
    int? score,
    int? wrongCount,
    int? consecutiveWrongCount,
    int? remainingActiveBudgetMs,
    TimeAttackQuestionPhase? questionPhase,
    Set<String>? seenQuestionIds,
    List<String>? answeredCategories,
    TimeAttackTerminalReason? terminalReason,
  }) => TimeAttackGameState(
    score: score ?? _state.score,
    wrongCount: wrongCount ?? _state.wrongCount,
    consecutiveWrongCount:
        consecutiveWrongCount ?? _state.consecutiveWrongCount,
    remainingActiveBudgetMs:
        remainingActiveBudgetMs ?? _state.remainingActiveBudgetMs,
    presentation: _state.presentation,
    questionPhase: questionPhase ?? _state.questionPhase,
    usedQuestionIds: _state.usedQuestionIds,
    seenQuestionIds: seenQuestionIds ?? _state.seenQuestionIds,
    answeredCategories: answeredCategories ?? _state.answeredCategories,
    positionBalance: _state.positionBalance,
    terminalReason: terminalReason,
  );

  void _requireActive() {
    if (_state.isTerminal) {
      throw StateError('The game has already ended.');
    }
  }

  GameplayDifficulty _difficultyForSequence(int sequence) =>
      switch ((sequence - 1) % 3) {
        0 => GameplayDifficulty.easy,
        1 => GameplayDifficulty.medium,
        _ => GameplayDifficulty.hard,
      };

  int _wrongPenaltyMs(int consecutiveWrongCount) =>
      1000 * (consecutiveWrongCount > 4 ? 4 : consecutiveWrongCount);
}
