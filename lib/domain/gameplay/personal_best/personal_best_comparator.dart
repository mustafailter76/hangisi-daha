class ClassicPersonalBest {
  const ClassicPersonalBest({
    required this.score,
    required this.totalAnswerTimeMs,
  });

  final int score;
  final int totalAnswerTimeMs;
}

class TimeAttackPersonalBest {
  const TimeAttackPersonalBest({required this.score, required this.wrongCount});

  final int score;
  final int wrongCount;
}

bool shouldReplaceClassicPersonalBest({
  required ClassicPersonalBest candidate,
  ClassicPersonalBest? current,
}) {
  if (candidate.score <= 0) return false;
  if (current == null) return true;
  return candidate.score > current.score ||
      (candidate.score == current.score &&
          candidate.totalAnswerTimeMs < current.totalAnswerTimeMs);
}

bool shouldReplaceTimeAttackPersonalBest({
  required TimeAttackPersonalBest candidate,
  TimeAttackPersonalBest? current,
}) {
  if (candidate.score <= 0) return false;
  if (current == null) return true;
  return candidate.score > current.score ||
      (candidate.score == current.score &&
          candidate.wrongCount < current.wrongCount);
}
