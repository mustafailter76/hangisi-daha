import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline bootstrap does not require Supabase configuration', () async {
    Widget? launchedWidget;

    await bootstrapApp(runner: (widget) => launchedWidget = widget);

    expect(launchedWidget, isNotNull);
  });
}
