import 'dart:math';

import 'gameplay_models.dart';

class DefaultGameplayRandom implements GameplayRandom {
  DefaultGameplayRandom([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  double nextDouble() => _random.nextDouble();
}

class QuestionSelectionRequest {
  const QuestionSelectionRequest({
    required this.questions,
    required this.preferredDifficulty,
    required this.usedQuestionIds,
    required this.seenQuestionIds,
    required this.recentAnsweredCategories,
  });

  final Iterable<LocalGameplayQuestion> questions;
  final GameplayDifficulty preferredDifficulty;
  final Set<String> usedQuestionIds;
  final Set<String> seenQuestionIds;
  final List<String> recentAnsweredCategories;
}

class QuestionSelectionResult {
  const QuestionSelectionResult({
    required this.question,
    required this.seenQuestionIds,
    required this.didResetSeenCycle,
  });

  final LocalGameplayQuestion? question;
  final Set<String> seenQuestionIds;
  final bool didResetSeenCycle;

  bool get isPoolCompleted => question == null;
}

/// Mirrors the database selector's priority: preferred difficulty first,
/// then unused other difficulties; within that candidate set, unseen questions
/// win over seen questions and an optional third same-category question loses.
class QuestionSelector {
  const QuestionSelector(this.random);

  final GameplayRandom random;

  QuestionSelectionResult select(QuestionSelectionRequest request) {
    final active = request.questions
        .where((question) => question.isActive)
        .toList();
    final activeIds = active.map((question) => question.id).toSet();
    var seen = request.seenQuestionIds.intersection(activeIds);
    final didResetSeenCycle =
        activeIds.isNotEmpty && activeIds.every(seen.contains);
    if (didResetSeenCycle) seen = <String>{};

    final unused = active
        .where((question) => !request.usedQuestionIds.contains(question.id))
        .toList();
    if (unused.isEmpty) {
      return QuestionSelectionResult(
        question: null,
        seenQuestionIds: seen,
        didResetSeenCycle: didResetSeenCycle,
      );
    }

    var candidates = unused
        .where((question) => question.difficulty == request.preferredDifficulty)
        .toList();
    if (candidates.isEmpty) {
      candidates = unused
          .where(
            (question) => question.difficulty != request.preferredDifficulty,
          )
          .toList();
    }

    final unseen = candidates
        .where((question) => !seen.contains(question.id))
        .toList();
    if (unseen.isNotEmpty) candidates = unseen;

    final avoidedCategory = _categoryToAvoid(request.recentAnsweredCategories);
    if (avoidedCategory != null) {
      final alternatives = candidates
          .where((question) => question.category != avoidedCategory)
          .toList();
      if (alternatives.isNotEmpty) candidates = alternatives;
    }

    final question = candidates[_index(candidates.length)];
    return QuestionSelectionResult(
      question: question,
      seenQuestionIds: {...seen, question.id},
      didResetSeenCycle: didResetSeenCycle,
    );
  }

  int _index(int length) {
    final value = random.nextDouble();
    if (value < 0 || value >= 1) {
      throw ArgumentError.value(
        value,
        'random.nextDouble',
        'must be in [0, 1)',
      );
    }
    return (value * length).floor();
  }

  String? _categoryToAvoid(List<String> categories) {
    if (categories.length < 2) return null;
    final latest = categories[categories.length - 1];
    return latest == categories[categories.length - 2] ? latest : null;
  }
}
