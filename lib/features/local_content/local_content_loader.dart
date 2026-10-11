import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';

class LocalContentLoader {
  const LocalContentLoader(this.assetBundle);

  static const questionsAssetPath = 'assets/content/questions.json';

  final AssetBundle assetBundle;

  Future<List<LocalGameplayQuestion>> load() async {
    final source = await assetBundle.loadString(questionsAssetPath);
    return parse(source);
  }

  List<LocalGameplayQuestion> parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported local content schema.');
    }
    final rows = decoded['questions'];
    if (rows is! List) throw const FormatException('questions must be a list.');
    final questions = rows.map((row) => _parseQuestion(row)).toList();
    if (questions.map((question) => question.id).toSet().length !=
        questions.length) {
      throw const FormatException('Duplicate question id in local content.');
    }
    return List.unmodifiable(questions);
  }

  LocalGameplayQuestion _parseQuestion(Object? value) {
    if (value is! Map) {
      throw const FormatException('Question must be an object.');
    }
    final row = Map<String, dynamic>.from(value);
    try {
      final question = LocalGameplayQuestion(
        id: _string(row, 'id'),
        questionText: _string(row, 'questionText'),
        optionA: _string(row, 'optionA'),
        optionB: _string(row, 'optionB'),
        valueA: _number(row, 'valueA'),
        valueB: _number(row, 'valueB'),
        displayValueA: _string(row, 'displayValueA'),
        displayValueB: _string(row, 'displayValueB'),
        comparisonMode: _comparisonMode(_string(row, 'comparisonMode')),
        difficulty: _difficulty(_string(row, 'difficulty')),
        category: _string(row, 'category'),
        hint: _optionalString(row['hint']),
        imageA: _imagePath(_string(row, 'imageA')),
        imageB: _imagePath(_string(row, 'imageB')),
      );
      return question;
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('hint must be a string.');
    return value.isEmpty ? null : value;
  }

  num _number(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('$key must be a finite number.');
    }
    return value;
  }

  GameplayComparisonMode _comparisonMode(String value) => switch (value) {
    'higher_wins' => GameplayComparisonMode.higherWins,
    'lower_wins' => GameplayComparisonMode.lowerWins,
    _ => throw const FormatException('Invalid comparison mode.'),
  };

  GameplayDifficulty _difficulty(String value) => switch (value) {
    'easy' => GameplayDifficulty.easy,
    'medium' => GameplayDifficulty.medium,
    'hard' => GameplayDifficulty.hard,
    _ => throw const FormatException('Invalid difficulty.'),
  };

  String _imagePath(String path) {
    if (!RegExp(r'^images/[0-9A-Za-z_-]+/[ab]\.webp$').hasMatch(path)) {
      throw const FormatException('Invalid local image path.');
    }
    return 'assets/content/$path';
  }
}
