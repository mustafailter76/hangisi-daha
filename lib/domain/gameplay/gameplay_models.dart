enum GameplayOption { a, b }

enum GameplayPosition { top, bottom }

enum GameplayDifficulty { easy, medium, hard }

enum GameplayComparisonMode { higherWins, lowerWins }

enum GameplayAnswerResult { correct, incorrect, timeout }

class LocalGameplayQuestion {
  LocalGameplayQuestion({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.valueA,
    required this.valueB,
    required this.displayValueA,
    required this.displayValueB,
    required this.comparisonMode,
    required this.difficulty,
    required this.category,
    required this.imageA,
    required this.imageB,
    this.hint,
    this.isActive = true,
  }) {
    if (id.trim().isEmpty || questionText.trim().isEmpty) {
      throw ArgumentError('Question id and text are required.');
    }
    if (valueA == valueB) {
      throw ArgumentError('Comparison values must differ.');
    }
  }

  final String id;
  final String questionText;
  final String optionA;
  final String optionB;
  final num valueA;
  final num valueB;
  final String displayValueA;
  final String displayValueB;
  final GameplayComparisonMode comparisonMode;
  final GameplayDifficulty difficulty;
  final String category;
  final String? hint;
  final String imageA;
  final String imageB;
  final bool isActive;

  GameplayOption get correctOption => switch (comparisonMode) {
    GameplayComparisonMode.higherWins =>
      valueA > valueB ? GameplayOption.a : GameplayOption.b,
    GameplayComparisonMode.lowerWins =>
      valueA < valueB ? GameplayOption.a : GameplayOption.b,
  };

  String displayValueFor(GameplayOption option) => switch (option) {
    GameplayOption.a => displayValueA,
    GameplayOption.b => displayValueB,
  };
}

class GameplayPresentation {
  const GameplayPresentation({
    required this.question,
    required this.number,
    required this.topOption,
    required this.bottomOption,
    required this.correctPosition,
  }) : assert(topOption != bottomOption);

  final LocalGameplayQuestion question;
  final int number;
  final GameplayOption topOption;
  final GameplayOption bottomOption;
  final GameplayPosition correctPosition;

  GameplayOption optionAt(GameplayPosition position) => switch (position) {
    GameplayPosition.top => topOption,
    GameplayPosition.bottom => bottomOption,
  };
}

abstract interface class GameplayRandom {
  double nextDouble();
}
