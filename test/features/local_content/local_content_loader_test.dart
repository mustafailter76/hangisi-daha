import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hangisi_daha/domain/gameplay/gameplay_models.dart';
import 'package:hangisi_daha/features/local_content/local_content_loader.dart';

void main() {
  final loader = LocalContentLoader(rootBundle);

  test('parses a valid bundled content package into domain questions', () {
    final questions = loader.parse(_package());

    expect(questions, hasLength(1));
    expect(questions.single.id, 'question-1');
    expect(questions.single.imageA, 'assets/content/images/question-1/a.webp');
    expect(questions.single.comparisonMode, GameplayComparisonMode.higherWins);
  });

  test('accepts a deliberate empty editorial package', () {
    expect(loader.parse('{"schemaVersion":1,"questions":[]}'), isEmpty);
  });

  testWidgets('loads the bundled active question pool', (tester) async {
    final questions = await loader.load();

    expect(questions, hasLength(48));
    expect(questions.map((question) => question.id).toSet(), hasLength(48));
  });

  test('rejects invalid schema, duplicate IDs, values, enums, and paths', () {
    expect(
      () => loader.parse('{"schemaVersion":2,"questions":[]}'),
      throwsFormatException,
    );
    expect(
      () => loader.parse(_package(rows: '[$_row,$_row]')),
      throwsFormatException,
    );
    expect(
      () => loader.parse(_package(row: _row.replaceFirst('20', '10'))),
      throwsFormatException,
    );
    expect(
      () => loader.parse(
        _package(row: _row.replaceFirst('higher_wins', 'sideways')),
      ),
      throwsFormatException,
    );
    expect(
      () => loader.parse(_package(row: _row.replaceFirst('easy', 'expert'))),
      throwsFormatException,
    );
    expect(
      () => loader.parse(
        _package(
          row: _row.replaceFirst('images/question-1/a.webp', '../a.webp'),
        ),
      ),
      throwsFormatException,
    );
  });
}

String _package({String? row, String? rows}) =>
    '{"schemaVersion":1,"questions":${rows ?? '[${row ?? _row}]'}}';

const _row = '''{
  "id":"question-1","questionText":"Hangisi daha büyük?",
  "optionA":"A","optionB":"B","valueA":10,"valueB":20,
  "displayValueA":"10","displayValueB":"20","comparisonMode":"higher_wins",
  "difficulty":"easy","category":"test","hint":"İpucu",
  "imageA":"images/question-1/a.webp","imageB":"images/question-1/b.webp"
}''';
