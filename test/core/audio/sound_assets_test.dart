import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all final sound assets are bundled as PCM WAV files', () async {
    for (final path in const [
      'assets/audio/correct.wav',
      'assets/audio/wrong.wav',
      'assets/audio/game_over.wav',
      'assets/audio/extension.wav',
      'assets/audio/hint.wav',
      'assets/audio/shield_activate.wav',
      'assets/audio/shield_impact.wav',
      'assets/audio/new_record.wav',
      'assets/audio/critical_time.wav',
    ]) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      expect(bytes.length, lessThan(500 * 1024), reason: path);
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF', reason: path);
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE', reason: path);
      expect(data.getUint16(22, Endian.little), 2, reason: path);
      expect(data.getUint32(24, Endian.little), 44100, reason: path);
      expect(data.getUint16(34, Endian.little), 16, reason: path);
    }
  });
}
