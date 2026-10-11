import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/domain/gameplay/classic/classic_game_engine.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart';
import 'package:hangisi_daha/domain/gameplay/position_balancer.dart';
import 'package:hangisi_daha/domain/gameplay/question_selector.dart';
import 'package:hangisi_daha/domain/gameplay/time_attack/time_attack_game_engine.dart';

void main() {
  group('question selection and seen cycle', () {
    test(
      'prefers preferred difficulty, then falls back without session repeats',
      () {
        final selector = QuestionSelector(_FixedRandom([0]));
        final result = selector.select(
          QuestionSelectionRequest(
            questions: [
              _question('easy', GameplayDifficulty.easy),
              _question('hard', GameplayDifficulty.hard),
            ],
            preferredDifficulty: GameplayDifficulty.medium,
            usedQuestionIds: const {'hard'},
            seenQuestionIds: const {},
            recentAnsweredCategories: const [],
          ),
        );
        expect(result.question?.id, 'easy');
      },
    );

    test(
      'prioritizes global unseen questions and resets only the global cycle',
      () {
        final questions = [
          _question('used', GameplayDifficulty.easy),
          _question('next', GameplayDifficulty.easy),
        ];
        final selector = QuestionSelector(_FixedRandom([0]));
        final result = selector.select(
          QuestionSelectionRequest(
            questions: questions,
            preferredDifficulty: GameplayDifficulty.easy,
            usedQuestionIds: const {'used'},
            seenQuestionIds: const {'used', 'next'},
            recentAnsweredCategories: const [],
          ),
        );
        expect(result.didResetSeenCycle, isTrue);
        expect(result.question?.id, 'next');
        expect(result.seenQuestionIds, {'next'});
      },
    );

    test('prevents a third same category only when an alternative exists', () {
      final selector = QuestionSelector(_FixedRandom([0]));
      final result = selector.select(
        QuestionSelectionRequest(
          questions: [
            _question('sport', GameplayDifficulty.easy, category: 'spor'),
            _question('science', GameplayDifficulty.easy, category: 'bilim'),
          ],
          preferredDifficulty: GameplayDifficulty.easy,
          usedQuestionIds: const {},
          seenQuestionIds: const {},
          recentAnsweredCategories: const ['spor', 'spor'],
        ),
      );
      expect(result.question?.id, 'science');
    });

    test(
      'returns pool completion only after every active question is used',
      () {
        final selector = QuestionSelector(_FixedRandom([0]));
        final result = selector.select(
          QuestionSelectionRequest(
            questions: [_question('one', GameplayDifficulty.easy)],
            preferredDifficulty: GameplayDifficulty.easy,
            usedQuestionIds: const {'one'},
            seenQuestionIds: const {},
            recentAnsweredCategories: const [],
          ),
        );
        expect(result.isPoolCompleted, isTrue);
      },
    );

    test(
      'ignores inactive input and derives the canonical answer from values',
      () {
        final selector = QuestionSelector(_FixedRandom([0]));
        final result = selector.select(
          QuestionSelectionRequest(
            questions: [
              _question('inactive', GameplayDifficulty.easy, isActive: false),
              _question('lower', GameplayDifficulty.easy, aIsCorrect: false),
            ],
            preferredDifficulty: GameplayDifficulty.easy,
            usedQuestionIds: const {},
            seenQuestionIds: const {},
            recentAnsweredCategories: const [],
          ),
        );
        expect(result.question?.id, 'lower');
        expect(result.question?.correctOption, GameplayOption.b);
      },
    );
  });

  group('physical position balancing', () {
    test('maps canonical A/B independently from physical top/bottom', () {
      final result = PositionBalancer(_FixedRandom([.9])).present(
        question: _question(
          'a-is-correct',
          GameplayDifficulty.easy,
          aIsCorrect: true,
        ),
        number: 1,
        balanceState: const PositionBalanceState(),
      );
      expect(result.presentation.correctPosition, GameplayPosition.bottom);
      expect(result.presentation.topOption, GameplayOption.b);
      expect(result.presentation.bottomOption, GameplayOption.a);
    });

    test('allows a fifth streak and forces a flip after it', () {
      final question = _question('q', GameplayDifficulty.easy);
      final balancer = PositionBalancer(_FixedRandom([.1]));
      final fifth = balancer.present(
        question: question,
        number: 5,
        balanceState: const PositionBalanceState(
          lastCorrectPosition: GameplayPosition.top,
          correctPositionStreak: 4,
        ),
      );
      expect(fifth.nextBalanceState.correctPositionStreak, 5);
      final forced = balancer.present(
        question: question,
        number: 6,
        balanceState: fifth.nextBalanceState,
      );
      expect(forced.presentation.correctPosition, GameplayPosition.bottom);
      expect(forced.nextBalanceState.correctPositionStreak, 1);
    });
  });

  group('Classic engine', () {
    test(
      'starts at 15 seconds and follows score-based difficulty thresholds',
      () {
        final engine = ClassicGameEngine(
          questions: _classicPool(),
          random: _FixedRandom(List.filled(100, .1)),
        );
        engine.start();
        expect(engine.state.answerWindowMs, 15000);
        expect(
          engine.state.presentation.question.difficulty,
          GameplayDifficulty.easy,
        );
        for (var index = 0; index < 10; index++) {
          engine.answer(
            selectedPosition: engine.state.presentation.correctPosition,
            decisionElapsedMs: 1,
          );
        }
        expect(engine.state.score, 10);
        expect(engine.state.presentation.number, 11);
        expect(
          engine.state.presentation.question.difficulty,
          GameplayDifficulty.medium,
        );
      },
    );

    test(
      'extension and hint preserve elapsed time while each joker is single-use',
      () {
        final engine = ClassicGameEngine(
          questions: [
            _question('one', GameplayDifficulty.easy, hint: 'İpucu'),
            _question('two', GameplayDifficulty.easy, hint: 'İpucu iki'),
          ],
          random: _FixedRandom(List.filled(20, .1)),
        );
        engine.start();
        final extension = engine.activateJoker(
          joker: ClassicJoker.extension,
          decisionElapsedMs: 8000,
        );
        expect(extension.answerWindowMs, 45000);
        expect(
          () => engine.activateJoker(
            joker: ClassicJoker.hint,
            decisionElapsedMs: 8001,
          ),
          throwsStateError,
        );
        final outcome = engine.answer(
          selectedPosition: engine.state.presentation.correctPosition,
          decisionElapsedMs: 44000,
        );
        expect(outcome.state.totalAnswerTimeMs, 44000);
        expect(
          () => engine.activateJoker(
            joker: ClassicJoker.extension,
            decisionElapsedMs: 1,
          ),
          throwsStateError,
        );
        final hint = engine.activateJoker(
          joker: ClassicJoker.hint,
          decisionElapsedMs: 4000,
        );
        expect(hint.answerWindowMs, 30000);
        expect(hint.hintText, 'İpucu iki');
      },
    );

    test('wrong and timeout end a Classic game unless shield absorbs them', () {
      final wrong = ClassicGameEngine(
        questions: [_question('wrong', GameplayDifficulty.easy)],
        random: _FixedRandom([.1, .1]),
      )..start();
      final wrongResult = wrong.answer(
        selectedPosition: GameplayPosition.bottom,
        decisionElapsedMs: 1,
      );
      expect(wrongResult.terminalReason, ClassicTerminalReason.incorrect);

      final timeout = ClassicGameEngine(
        questions: [_question('timeout', GameplayDifficulty.easy)],
        random: _FixedRandom([.1, .1]),
      )..start();
      final timeoutResult = timeout.answer(
        selectedPosition: null,
        decisionElapsedMs: 15000,
      );
      expect(timeoutResult.terminalReason, ClassicTerminalReason.timeout);

      final shield = ClassicGameEngine(
        questions: [
          _question('shield-a', GameplayDifficulty.easy),
          _question('shield-b', GameplayDifficulty.easy),
        ],
        random: _FixedRandom(List.filled(10, .1)),
      )..start();
      shield.activateJoker(joker: ClassicJoker.shield, decisionElapsedMs: 1);
      final shieldResult = shield.answer(
        selectedPosition: GameplayPosition.bottom,
        decisionElapsedMs: 15000,
      );
      expect(shieldResult.result, GameplayAnswerResult.timeout);
      expect(shieldResult.shieldAbsorbed, isTrue);
      expect(shieldResult.state.isTerminal, isFalse);
      expect(shieldResult.state.score, 0);

      final shieldCorrect = ClassicGameEngine(
        questions: [
          _question('shield-correct-a', GameplayDifficulty.easy),
          _question('shield-correct-b', GameplayDifficulty.easy),
        ],
        random: _FixedRandom(List.filled(10, .1)),
      )..start();
      shieldCorrect.activateJoker(
        joker: ClassicJoker.shield,
        decisionElapsedMs: 1,
      );
      final shieldCorrectResult = shieldCorrect.answer(
        selectedPosition: shieldCorrect.state.presentation.correctPosition,
        decisionElapsedMs: 1,
      );
      expect(shieldCorrectResult.shieldAbsorbed, isFalse);
      expect(shieldCorrectResult.state.score, 1);
    });

    test(
      'last correct question is pool completed; shielded last failure is no-questions terminal',
      () {
        final correct = ClassicGameEngine(
          questions: [_question('last', GameplayDifficulty.easy)],
          random: _FixedRandom([.1, .1]),
        )..start();
        final correctResult = correct.answer(
          selectedPosition: correct.state.presentation.correctPosition,
          decisionElapsedMs: 1,
        );
        expect(
          correctResult.terminalReason,
          ClassicTerminalReason.questionPoolCompleted,
        );
        expect(correctResult.state.score, 1);

        final shield = ClassicGameEngine(
          questions: [_question('last-shield', GameplayDifficulty.easy)],
          random: _FixedRandom([.1, .1]),
        )..start();
        shield.activateJoker(joker: ClassicJoker.shield, decisionElapsedMs: 1);
        final shieldResult = shield.answer(
          selectedPosition: GameplayPosition.bottom,
          decisionElapsedMs: 1,
        );
        expect(
          shieldResult.terminalReason,
          ClassicTerminalReason.noQuestionsAvailable,
        );
      },
    );
  });

  group('60 Seconds engine', () {
    test(
      'starts preparing with 60,000 ms and only active decisions consume budget',
      () {
        final engine = TimeAttackGameEngine(
          questions: [
            _question('one', GameplayDifficulty.easy),
            _question('two', GameplayDifficulty.medium),
          ],
          random: _FixedRandom(List.filled(10, .1)),
        );
        engine.start();
        expect(engine.state.questionPhase, TimeAttackQuestionPhase.preparing);
        expect(engine.state.remainingActiveBudgetMs, 60000);
        engine.activateQuestion();
        final result = engine.answer(
          selectedPosition: engine.state.presentation.correctPosition,
          decisionElapsedMs: 1234,
        );
        expect(result.result, GameplayAnswerResult.correct);
        expect(result.adjustmentMs, 0);
        expect(result.remainingAfterMs, 58766);
        expect(result.state.questionPhase, TimeAttackQuestionPhase.preparing);
      },
    );

    test(
      'wrong penalties escalate, correct resets only the consecutive streak',
      () {
        final engine = TimeAttackGameEngine(
          questions: _timePool(7),
          random: _FixedRandom(List.filled(100, .1)),
        )..start();
        for (final expectedPenalty in [-1000, -2000, -3000, -4000, -4000]) {
          engine.activateQuestion();
          final result = engine.answer(
            selectedPosition: GameplayPosition.bottom,
            decisionElapsedMs: 0,
          );
          expect(result.adjustmentMs, expectedPenalty);
        }
        engine.activateQuestion();
        final correct = engine.answer(
          selectedPosition: engine.state.presentation.correctPosition,
          decisionElapsedMs: 0,
        );
        expect(correct.state.consecutiveWrongCount, 0);
        expect(correct.state.wrongCount, 5);
        expect(correct.state.score, 1);
      },
    );

    test(
      'elapsed expiry resolves before correctness and penalty expiry is distinct',
      () {
        final expired = TimeAttackGameEngine(
          questions: [_question('time', GameplayDifficulty.easy)],
          random: _FixedRandom([.1, .1]),
        )..start();
        expired.activateQuestion();
        final timeResult = expired.answer(
          selectedPosition: expired.state.presentation.correctPosition,
          decisionElapsedMs: 60000,
        );
        expect(timeResult.result, GameplayAnswerResult.timeout);
        expect(timeResult.terminalReason, TimeAttackTerminalReason.timeExpired);
        expect(timeResult.state.score, 0);

        final penalty = TimeAttackGameEngine(
          questions: [
            _question('penalty', GameplayDifficulty.easy),
            _question('next', GameplayDifficulty.medium),
          ],
          random: _FixedRandom(List.filled(10, .1)),
        )..start();
        penalty.activateQuestion();
        final penaltyResult = penalty.answer(
          selectedPosition: GameplayPosition.bottom,
          decisionElapsedMs: 59000,
        );
        expect(
          penaltyResult.terminalReason,
          TimeAttackTerminalReason.wrongPenaltyExpired,
        );
        expect(penaltyResult.remainingAfterMs, 0);
      },
    );

    test(
      'uses E-M-H sequence, fallback, no repeats, and preserves remaining budget on pool completion',
      () {
        final engine = TimeAttackGameEngine(
          questions: [
            _question('easy-1', GameplayDifficulty.easy),
            _question('medium-1', GameplayDifficulty.medium),
            _question('hard-1', GameplayDifficulty.hard),
            _question('easy-2', GameplayDifficulty.easy),
          ],
          random: _FixedRandom(List.filled(100, .1)),
        )..start();
        final difficulties = <GameplayDifficulty>[
          engine.state.presentation.question.difficulty,
        ];
        final ids = <String>{engine.state.presentation.question.id};
        while (!engine.state.isTerminal) {
          engine.activateQuestion();
          engine.answer(
            selectedPosition: engine.state.presentation.correctPosition,
            decisionElapsedMs: 1,
          );
          if (!engine.state.isTerminal) {
            difficulties.add(engine.state.presentation.question.difficulty);
            ids.add(engine.state.presentation.question.id);
          }
        }
        expect(difficulties, [
          GameplayDifficulty.easy,
          GameplayDifficulty.medium,
          GameplayDifficulty.hard,
          GameplayDifficulty.easy,
        ]);
        expect(ids.length, 4);
        expect(
          engine.state.terminalReason,
          TimeAttackTerminalReason.questionPoolCompleted,
        );
        expect(engine.state.remainingActiveBudgetMs, greaterThan(0));
      },
    );
  });

  group('personal best comparators', () {
    test(
      'Classic uses score then lower total answer time and rejects score zero',
      () {
        expect(
          shouldReplaceClassicPersonalBest(
            candidate: const ClassicPersonalBest(
              score: 0,
              totalAnswerTimeMs: 1,
            ),
            current: null,
          ),
          isFalse,
        );
        expect(
          shouldReplaceClassicPersonalBest(
            candidate: const ClassicPersonalBest(
              score: 5,
              totalAnswerTimeMs: 900,
            ),
            current: const ClassicPersonalBest(
              score: 5,
              totalAnswerTimeMs: 1000,
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '60 Seconds uses score then lower wrong count and rejects score zero',
      () {
        expect(
          shouldReplaceTimeAttackPersonalBest(
            candidate: const TimeAttackPersonalBest(score: 0, wrongCount: 0),
            current: null,
          ),
          isFalse,
        );
        expect(
          shouldReplaceTimeAttackPersonalBest(
            candidate: const TimeAttackPersonalBest(score: 5, wrongCount: 2),
            current: const TimeAttackPersonalBest(score: 5, wrongCount: 3),
          ),
          isTrue,
        );
      },
    );
  });
}

class _FixedRandom implements GameplayRandom {
  _FixedRandom(this.values);

  final List<double> values;
  var _index = 0;

  @override
  double nextDouble() {
    if (_index >= values.length) {
      throw StateError('Test random values exhausted.');
    }
    return values[_index++];
  }
}

LocalGameplayQuestion _question(
  String id,
  GameplayDifficulty difficulty, {
  String category = 'genel',
  bool aIsCorrect = true,
  String? hint,
  bool isActive = true,
}) => LocalGameplayQuestion(
  id: id,
  questionText: '$id?',
  optionA: 'A',
  optionB: 'B',
  valueA: aIsCorrect ? 2 : 1,
  valueB: aIsCorrect ? 1 : 2,
  displayValueA: 'A',
  displayValueB: 'B',
  comparisonMode: GameplayComparisonMode.higherWins,
  difficulty: difficulty,
  category: category,
  hint: hint,
  imageA: 'a.webp',
  imageB: 'b.webp',
  isActive: isActive,
);

List<LocalGameplayQuestion> _classicPool() => [
  for (var index = 0; index < 10; index++)
    _question('easy-$index', GameplayDifficulty.easy, category: 'easy-$index'),
  for (var index = 0; index < 11; index++)
    _question(
      'medium-$index',
      GameplayDifficulty.medium,
      category: 'medium-$index',
    ),
  _question('hard-0', GameplayDifficulty.hard),
];

List<LocalGameplayQuestion> _timePool(int count) => [
  for (var index = 0; index < count; index++)
    _question(
      'time-$index',
      GameplayDifficulty.values[index % GameplayDifficulty.values.length],
      category: 'time-$index',
    ),
];
