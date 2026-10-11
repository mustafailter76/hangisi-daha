import '../gameplay_models.dart';
import '../position_balancer.dart';
import '../question_selector.dart';

enum ClassicJoker { extension, hint, shield }

enum ClassicTerminalReason {
  incorrect,
  timeout,
  questionPoolCompleted,
  noQuestionsAvailable,
}

class ClassicJokerState {
  const ClassicJokerState({
    this.extensionUsed = false,
    this.hintUsed = false,
    this.shieldUsed = false,
    this.currentQuestionJoker,
  });

  final bool extensionUsed;
  final bool hintUsed;
  final bool shieldUsed;
  final ClassicJoker? currentQuestionJoker;

  bool isUsed(ClassicJoker joker) => switch (joker) {
    ClassicJoker.extension => extensionUsed,
    ClassicJoker.hint => hintUsed,
    ClassicJoker.shield => shieldUsed,
  };

  ClassicJokerState activate(ClassicJoker joker) => ClassicJokerState(
    extensionUsed: extensionUsed || joker == ClassicJoker.extension,
    hintUsed: hintUsed || joker == ClassicJoker.hint,
    shieldUsed: shieldUsed || joker == ClassicJoker.shield,
    currentQuestionJoker: joker,
  );

  ClassicJokerState forNextQuestion() => ClassicJokerState(
    extensionUsed: extensionUsed,
    hintUsed: hintUsed,
    shieldUsed: shieldUsed,
  );
}

class ClassicGameState {
  const ClassicGameState({
    required this.score,
    required this.totalAnswerTimeMs,
    required this.presentation,
    required this.usedQuestionIds,
    required this.seenQuestionIds,
    required this.answeredCategories,
    required this.positionBalance,
    required this.jokers,
    this.terminalReason,
  });

  final int score;
  final int totalAnswerTimeMs;
  final GameplayPresentation presentation;
  final Set<String> usedQuestionIds;
  final Set<String> seenQuestionIds;
  final List<String> answeredCategories;
  final PositionBalanceState positionBalance;
  final ClassicJokerState jokers;
  final ClassicTerminalReason? terminalReason;

  bool get isTerminal => terminalReason != null;

  int get answerWindowMs => switch (jokers.currentQuestionJoker) {
    ClassicJoker.extension => 45000,
    ClassicJoker.hint => 30000,
    _ => 15000,
  };
}

class ClassicJokerActivation {
  const ClassicJokerActivation({
    required this.joker,
    required this.answerWindowMs,
    required this.hintText,
    required this.state,
  });

  final ClassicJoker joker;
  final int answerWindowMs;
  final String? hintText;
  final ClassicGameState state;
}

class ClassicAnswerOutcome {
  const ClassicAnswerOutcome({
    required this.result,
    required this.correctOption,
    required this.selectedOption,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.shieldAbsorbed,
    required this.state,
  });

  final GameplayAnswerResult result;
  final GameplayOption correctOption;
  final GameplayOption? selectedOption;
  final int scoreBefore;
  final int scoreAfter;
  final bool shieldAbsorbed;
  final ClassicGameState state;

  ClassicTerminalReason? get terminalReason => state.terminalReason;
  GameplayPresentation? get nextPresentation =>
      state.isTerminal ? null : state.presentation;
}

class ClassicGameEngine {
  ClassicGameEngine({
    required Iterable<LocalGameplayQuestion> questions,
    required GameplayRandom random,
  }) : _questions = List.unmodifiable(questions),
       _selector = QuestionSelector(random),
       _balancer = PositionBalancer(random);

  final List<LocalGameplayQuestion> _questions;
  final QuestionSelector _selector;
  final PositionBalancer _balancer;
  late ClassicGameState _state;

  ClassicGameState get state => _state;

  ClassicGameState start({Set<String> seenQuestionIds = const {}}) {
    final selected = _select(
      preferredDifficulty: _difficultyForScore(0),
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
    return _state = ClassicGameState(
      score: 0,
      totalAnswerTimeMs: 0,
      presentation: presented.presentation,
      usedQuestionIds: {selected.question!.id},
      seenQuestionIds: selected.seenQuestionIds,
      answeredCategories: const [],
      positionBalance: presented.nextBalanceState,
      jokers: const ClassicJokerState(),
    );
  }

  ClassicJokerActivation activateJoker({
    required ClassicJoker joker,
    required int decisionElapsedMs,
  }) {
    _requireActive();
    if (decisionElapsedMs < 0 || decisionElapsedMs >= 15000) {
      throw StateError('The unresolved question has expired.');
    }
    if (_state.jokers.currentQuestionJoker != null ||
        _state.jokers.isUsed(joker)) {
      throw StateError('This joker cannot be activated.');
    }
    final hint = _state.presentation.question.hint;
    if (joker == ClassicJoker.hint && (hint == null || hint.trim().isEmpty)) {
      throw StateError('This question has no hint.');
    }
    _state = _with(jokers: _state.jokers.activate(joker));
    return ClassicJokerActivation(
      joker: joker,
      answerWindowMs: _state.answerWindowMs,
      hintText: joker == ClassicJoker.hint ? hint : null,
      state: _state,
    );
  }

  ClassicAnswerOutcome answer({
    required GameplayPosition? selectedPosition,
    required int decisionElapsedMs,
  }) {
    _requireActive();
    if (decisionElapsedMs < 0) {
      throw ArgumentError.value(decisionElapsedMs);
    }
    final current = _state.presentation;
    final selectedOption = selectedPosition == null
        ? null
        : current.optionAt(selectedPosition);
    final timedOut = decisionElapsedMs >= _state.answerWindowMs;
    if (selectedPosition == null && !timedOut) {
      throw StateError(
        'A timeout cannot resolve before the answer window ends.',
      );
    }
    final result = timedOut
        ? GameplayAnswerResult.timeout
        : selectedOption == current.question.correctOption
        ? GameplayAnswerResult.correct
        : GameplayAnswerResult.incorrect;
    final shieldAbsorbed =
        _state.jokers.currentQuestionJoker == ClassicJoker.shield &&
        result != GameplayAnswerResult.correct;
    final scoreBefore = _state.score;
    final scoreAfter =
        scoreBefore + (result == GameplayAnswerResult.correct ? 1 : 0);
    final answeredCategories = [
      ..._state.answeredCategories,
      current.question.category,
    ];
    final answerTime = decisionElapsedMs.clamp(0, _state.answerWindowMs);

    if (result != GameplayAnswerResult.correct && !shieldAbsorbed) {
      _state = _with(
        totalAnswerTimeMs: _state.totalAnswerTimeMs + answerTime,
        answeredCategories: answeredCategories,
        terminalReason: result == GameplayAnswerResult.timeout
            ? ClassicTerminalReason.timeout
            : ClassicTerminalReason.incorrect,
      );
      return _outcome(result, selectedOption, scoreBefore, shieldAbsorbed);
    }

    final selected = _select(
      preferredDifficulty: _difficultyForScore(scoreAfter),
      usedQuestionIds: _state.usedQuestionIds,
      seenQuestionIds: _state.seenQuestionIds,
      answeredCategories: answeredCategories,
    );
    if (selected.question == null) {
      _state = _with(
        score: scoreAfter,
        totalAnswerTimeMs: _state.totalAnswerTimeMs + answerTime,
        seenQuestionIds: selected.seenQuestionIds,
        answeredCategories: answeredCategories,
        terminalReason: result == GameplayAnswerResult.correct
            ? ClassicTerminalReason.questionPoolCompleted
            : ClassicTerminalReason.noQuestionsAvailable,
      );
      return _outcome(result, selectedOption, scoreBefore, shieldAbsorbed);
    }

    final next = _balancer.present(
      question: selected.question!,
      number: scoreAfter + 1,
      balanceState: _state.positionBalance,
    );
    _state = ClassicGameState(
      score: scoreAfter,
      totalAnswerTimeMs: _state.totalAnswerTimeMs + answerTime,
      presentation: next.presentation,
      usedQuestionIds: {..._state.usedQuestionIds, selected.question!.id},
      seenQuestionIds: selected.seenQuestionIds,
      answeredCategories: List.unmodifiable(answeredCategories),
      positionBalance: next.nextBalanceState,
      jokers: _state.jokers.forNextQuestion(),
    );
    return _outcome(result, selectedOption, scoreBefore, shieldAbsorbed);
  }

  QuestionSelectionResult _select({
    required GameplayDifficulty preferredDifficulty,
    required Set<String> usedQuestionIds,
    required Set<String> seenQuestionIds,
    required List<String> answeredCategories,
  }) => _selector.select(
    QuestionSelectionRequest(
      questions: _questions,
      preferredDifficulty: preferredDifficulty,
      usedQuestionIds: usedQuestionIds,
      seenQuestionIds: seenQuestionIds,
      recentAnsweredCategories: answeredCategories,
    ),
  );

  ClassicAnswerOutcome _outcome(
    GameplayAnswerResult result,
    GameplayOption? selectedOption,
    int scoreBefore,
    bool shieldAbsorbed,
  ) => ClassicAnswerOutcome(
    result: result,
    correctOption: _state.presentation.question.correctOption,
    selectedOption: selectedOption,
    scoreBefore: scoreBefore,
    scoreAfter: _state.score,
    shieldAbsorbed: shieldAbsorbed,
    state: _state,
  );

  ClassicGameState _with({
    int? score,
    int? totalAnswerTimeMs,
    Set<String>? seenQuestionIds,
    List<String>? answeredCategories,
    ClassicJokerState? jokers,
    ClassicTerminalReason? terminalReason,
  }) => ClassicGameState(
    score: score ?? _state.score,
    totalAnswerTimeMs: totalAnswerTimeMs ?? _state.totalAnswerTimeMs,
    presentation: _state.presentation,
    usedQuestionIds: _state.usedQuestionIds,
    seenQuestionIds: seenQuestionIds ?? _state.seenQuestionIds,
    answeredCategories: answeredCategories ?? _state.answeredCategories,
    positionBalance: _state.positionBalance,
    jokers: jokers ?? _state.jokers,
    terminalReason: terminalReason,
  );

  void _requireActive() {
    if (_state.isTerminal) {
      throw StateError('The game has already ended.');
    }
  }

  GameplayDifficulty _difficultyForScore(int score) {
    final number = score + 1;
    if (number <= 10) return GameplayDifficulty.easy;
    if (number <= 20) return GameplayDifficulty.medium;
    return GameplayDifficulty.hard;
  }
}
