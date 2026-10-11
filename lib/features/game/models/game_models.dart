enum GameOption { a, b }

enum ClassicJokerType { extension, hint, shield }

class ClassicJokerInventory {
  const ClassicJokerInventory({
    required this.extensionUsed,
    required this.hintUsed,
    required this.shieldUsed,
    required this.currentQuestionJoker,
  });

  const ClassicJokerInventory.unused()
    : extensionUsed = false,
      hintUsed = false,
      shieldUsed = false,
      currentQuestionJoker = null;

  final bool extensionUsed;
  final bool hintUsed;
  final bool shieldUsed;
  final ClassicJokerType? currentQuestionJoker;

  bool isUsed(ClassicJokerType type) => switch (type) {
    ClassicJokerType.extension => extensionUsed,
    ClassicJokerType.hint => hintUsed,
    ClassicJokerType.shield => shieldUsed,
  };

  ClassicJokerInventory forNextQuestion() {
    return ClassicJokerInventory(
      extensionUsed: extensionUsed,
      hintUsed: hintUsed,
      shieldUsed: shieldUsed,
      currentQuestionJoker: null,
    );
  }

  ClassicJokerInventory withConsumedCurrent(ClassicJokerType type) {
    return ClassicJokerInventory(
      extensionUsed: extensionUsed || type == ClassicJokerType.extension,
      hintUsed: hintUsed || type == ClassicJokerType.hint,
      shieldUsed: shieldUsed || type == ClassicJokerType.shield,
      currentQuestionJoker: type,
    );
  }
}

class GameQuestion {
  const GameQuestion({
    required this.id,
    required this.questionText,
    required this.optionAName,
    required this.optionAImagePath,
    required this.optionBName,
    required this.optionBImagePath,
    required this.questionNumber,
    this.topOption = GameOption.a,
    this.bottomOption = GameOption.b,
  });

  final String id;
  final String questionText;
  final String optionAName;
  final String optionAImagePath;
  final String optionBName;
  final String optionBImagePath;
  final int questionNumber;
  final GameOption topOption;
  final GameOption bottomOption;

  String nameFor(GameOption option) => switch (option) {
    GameOption.a => optionAName,
    GameOption.b => optionBName,
  };

  String imagePathFor(GameOption option) => switch (option) {
    GameOption.a => optionAImagePath,
    GameOption.b => optionBImagePath,
  };
}

class AnsweredQuestion {
  const AnsweredQuestion({
    required this.correctOption,
    required this.displayValueA,
    required this.displayValueB,
  });

  final GameOption correctOption;
  final String displayValueA;
  final String displayValueB;

  String displayValueFor(GameOption option) => switch (option) {
    GameOption.a => displayValueA,
    GameOption.b => displayValueB,
  };
}

enum ClassicFinishReason { questionPoolCompleted }
