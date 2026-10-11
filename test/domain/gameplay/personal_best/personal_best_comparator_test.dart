import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/domain/gameplay/personal_best/personal_best_comparator.dart';

void main() {
  test('Classic tie-break prefers the lower total answer time', () {
    const current = ClassicPersonalBest(score: 5, totalAnswerTimeMs: 12000);

    expect(
      shouldReplaceClassicPersonalBest(
        candidate: const ClassicPersonalBest(
          score: 5,
          totalAnswerTimeMs: 11000,
        ),
        current: current,
      ),
      isTrue,
    );
    expect(
      shouldReplaceClassicPersonalBest(
        candidate: const ClassicPersonalBest(
          score: 5,
          totalAnswerTimeMs: 13000,
        ),
        current: current,
      ),
      isFalse,
    );
  });

  test('60 Seconds tie-break prefers fewer wrong answers', () {
    const current = TimeAttackPersonalBest(score: 8, wrongCount: 2);

    expect(
      shouldReplaceTimeAttackPersonalBest(
        candidate: const TimeAttackPersonalBest(score: 8, wrongCount: 1),
        current: current,
      ),
      isTrue,
    );
    expect(
      shouldReplaceTimeAttackPersonalBest(
        candidate: const TimeAttackPersonalBest(score: 8, wrongCount: 3),
        current: current,
      ),
      isFalse,
    );
  });

  test('a zero score never becomes a personal best', () {
    expect(
      shouldReplaceClassicPersonalBest(
        candidate: const ClassicPersonalBest(score: 0, totalAnswerTimeMs: 1000),
      ),
      isFalse,
    );
    expect(
      shouldReplaceTimeAttackPersonalBest(
        candidate: const TimeAttackPersonalBest(score: 0, wrongCount: 0),
      ),
      isFalse,
    );
  });
}
