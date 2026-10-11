import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/widgets/game_motion.dart';

void main() {
  testWidgets('press feedback compresses immediately and releases cleanly', (
    tester,
  ) async {
    await _pumpPressable(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('motion-target'))),
    );
    await tester.pump(GameMotionDurations.tap);

    expect(_scale(tester), closeTo(0.95, 0.001));

    await gesture.up();
    await tester.pump(GameMotionDurations.tap);
    expect(_scale(tester), 1);
  });

  testWidgets('reduced motion keeps press feedback static', (tester) async {
    await _pumpPressable(tester, reducedMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('motion-target'))),
    );
    await tester.pump();

    expect(_scale(tester), 1);

    await gesture.up();
  });

  testWidgets('terminal wrong keeps the wrong semantic marker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnswerMotionEffect(
          motion: AnswerMotion.terminalIncorrect,
          child: SizedBox(width: 100, height: 50),
        ),
      ),
    );

    expect(find.byKey(const Key('wrong-answer-motion')), findsOneWidget);
    expect(find.byKey(const Key('correct-answer-motion')), findsNothing);
  });
}

Future<void> _pumpPressable(WidgetTester tester, {bool reducedMotion = false}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const Center(
          child: PressableScale(
            pressedScale: 0.95,
            markerKey: Key('motion-target'),
            child: SizedBox(width: 120, height: 60),
          ),
        ),
      ),
    ),
  );
}

double _scale(WidgetTester tester) {
  final scale = tester.widget<AnimatedScale>(
    find.descendant(
      of: find.byKey(const Key('motion-target')),
      matching: find.byType(AnimatedScale),
    ),
  );
  return scale.scale;
}
