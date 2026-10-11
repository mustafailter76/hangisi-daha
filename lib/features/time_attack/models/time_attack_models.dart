import 'package:hangisi_daha/features/game/models/game_models.dart';

enum TimeAttackPosition { top, bottom }

enum TimeAttackDifficulty { easy, medium, hard }

enum TimeAttackQuestionPhase { preparing, active }

enum TimeAttackFinishReason {
  timeExpired,
  wrongPenaltyExpired,
  questionPoolCompleted,
}

class TimeAttackOption {
  const TimeAttackOption({
    required this.position,
    required this.name,
    required this.imagePath,
  });

  final TimeAttackPosition position;
  final String name;
  final String imagePath;
}

class TimeAttackQuestion {
  const TimeAttackQuestion({
    required this.instanceId,
    required this.questionText,
    required this.sequenceNumber,
    required this.difficulty,
    required this.phase,
    required this.top,
    required this.bottom,
  });

  final String instanceId;
  final String questionText;
  final int sequenceNumber;
  final TimeAttackDifficulty difficulty;
  final TimeAttackQuestionPhase phase;
  final TimeAttackOption top;
  final TimeAttackOption bottom;

  TimeAttackOption optionAt(TimeAttackPosition position) => switch (position) {
    TimeAttackPosition.top => top,
    TimeAttackPosition.bottom => bottom,
  };
}

class TimeAttackReveal {
  const TimeAttackReveal({required this.answer, required this.correctPosition});

  final AnsweredQuestion answer;
  final TimeAttackPosition correctPosition;

  String displayValueAt(TimeAttackPosition position) {
    final topIsCanonicalA =
        (answer.correctOption == GameOption.a &&
            correctPosition == TimeAttackPosition.top) ||
        (answer.correctOption == GameOption.b &&
            correctPosition == TimeAttackPosition.bottom);
    final canonicalOption = switch (position) {
      TimeAttackPosition.top => topIsCanonicalA ? GameOption.a : GameOption.b,
      TimeAttackPosition.bottom =>
        topIsCanonicalA ? GameOption.b : GameOption.a,
    };
    return answer.displayValueFor(canonicalOption);
  }
}

class TimeAttackPersonalBest {
  const TimeAttackPersonalBest({
    required this.score,
    required this.wrongCount,
    required this.achievedAt,
  });

  final int score;
  final int? wrongCount;
  final DateTime? achievedAt;
}
