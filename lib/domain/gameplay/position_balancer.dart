import 'gameplay_models.dart';

class PositionBalanceState {
  const PositionBalanceState({
    this.lastCorrectPosition,
    this.correctPositionStreak = 0,
  }) : assert(
         (lastCorrectPosition == null && correctPositionStreak == 0) ||
             (lastCorrectPosition != null &&
                 correctPositionStreak >= 1 &&
                 correctPositionStreak <= 5),
       );

  final GameplayPosition? lastCorrectPosition;
  final int correctPositionStreak;
}

class PositionPresentationResult {
  const PositionPresentationResult({
    required this.presentation,
    required this.nextBalanceState,
  });

  final GameplayPresentation presentation;
  final PositionBalanceState nextBalanceState;
}

class PositionBalancer {
  const PositionBalancer(this.random);

  final GameplayRandom random;

  PositionPresentationResult present({
    required LocalGameplayQuestion question,
    required int number,
    required PositionBalanceState balanceState,
  }) {
    final correctPosition = balanceState.correctPositionStreak == 5
        ? _opposite(balanceState.lastCorrectPosition!)
        : _randomPosition();
    final nextStreak = correctPosition == balanceState.lastCorrectPosition
        ? balanceState.correctPositionStreak + 1
        : 1;
    final correctOption = question.correctOption;
    final topOption = correctPosition == GameplayPosition.top
        ? correctOption
        : _oppositeOption(correctOption);
    final presentation = GameplayPresentation(
      question: question,
      number: number,
      topOption: topOption,
      bottomOption: _oppositeOption(topOption),
      correctPosition: correctPosition,
    );
    return PositionPresentationResult(
      presentation: presentation,
      nextBalanceState: PositionBalanceState(
        lastCorrectPosition: correctPosition,
        correctPositionStreak: nextStreak,
      ),
    );
  }

  GameplayPosition _randomPosition() {
    final value = random.nextDouble();
    if (value < 0 || value >= 1) {
      throw ArgumentError.value(
        value,
        'random.nextDouble',
        'must be in [0, 1)',
      );
    }
    return value < .5 ? GameplayPosition.top : GameplayPosition.bottom;
  }

  GameplayPosition _opposite(GameplayPosition position) => switch (position) {
    GameplayPosition.top => GameplayPosition.bottom,
    GameplayPosition.bottom => GameplayPosition.top,
  };

  GameplayOption _oppositeOption(GameplayOption option) => switch (option) {
    GameplayOption.a => GameplayOption.b,
    GameplayOption.b => GameplayOption.a,
  };
}
