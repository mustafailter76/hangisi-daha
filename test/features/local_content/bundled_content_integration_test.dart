import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/domain/gameplay/classic/classic_game_engine.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/domain/gameplay/time_attack/time_attack_game_engine.dart';
import 'package:hangisi_daha/features/local_content/local_content_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled questions and all referenced images load and decode', () async {
    final questions = await LocalContentLoader(rootBundle).load();
    expect(questions, hasLength(48));
    expect(questions.map((question) => question.id).toSet(), hasLength(48));

    final imagePaths = questions
        .expand((question) => [question.imageA, question.imageB])
        .toList();
    expect(imagePaths.toSet(), hasLength(96));
    for (final path in imagePaths) {
      final data = await rootBundle.load(path);
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 600, reason: path);
      expect(frame.image.height, 600, reason: path);
      frame.image.dispose();
      codec.dispose();
    }

    final random = _FixedRandom();
    final classic = ClassicGameEngine(questions: questions, random: random);
    final classicStart = classic.start();
    expect(classicStart.presentation.question.id, isNotEmpty);
    final classicOutcome = classic.answer(
      selectedPosition: classic.state.presentation.correctPosition,
      decisionElapsedMs: 1,
    );
    expect(classicOutcome.result, GameplayAnswerResult.correct);

    final timeAttack = TimeAttackGameEngine(
      questions: questions,
      random: _FixedRandom(),
    );
    final timeStart = timeAttack.start();
    expect(timeStart.remainingActiveBudgetMs, 60000);
    timeAttack.activateQuestion();
    final timeOutcome = timeAttack.answer(
      selectedPosition: timeAttack.state.presentation.correctPosition,
      decisionElapsedMs: 1,
    );
    expect(timeOutcome.result, GameplayAnswerResult.correct);
  });
}

class _FixedRandom implements GameplayRandom {
  @override
  double nextDouble() => 0.1;
}
