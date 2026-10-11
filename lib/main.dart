import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/app/app.dart';

Future<void> main() => bootstrapApp();

Future<void> bootstrapApp({void Function(Widget) runner = runApp}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runner(const ProviderScope(child: HangisiDahaApp()));
}
