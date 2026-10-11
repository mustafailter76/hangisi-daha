import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class GameHapticService {
  Future<void> selection();

  Future<void> correct();

  Future<void> wrong();

  Future<void> jokerActivated();

  Future<void> shieldAbsorbed();

  Future<void> gameOver();
}

class SystemGameHapticService implements GameHapticService {
  const SystemGameHapticService();

  @override
  Future<void> selection() => _safe(HapticFeedback.selectionClick);

  @override
  Future<void> correct() => _safe(HapticFeedback.lightImpact);

  @override
  Future<void> wrong() => _safe(HapticFeedback.mediumImpact);

  @override
  Future<void> jokerActivated() => _safe(HapticFeedback.lightImpact);

  @override
  Future<void> shieldAbsorbed() => _safe(HapticFeedback.mediumImpact);

  @override
  Future<void> gameOver() => _safe(HapticFeedback.heavyImpact);

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Haptics are optional feedback and must never interrupt gameplay.
    }
  }
}

final gameHapticServiceProvider = Provider<GameHapticService>(
  (ref) => const SystemGameHapticService(),
);
