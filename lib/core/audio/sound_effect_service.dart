import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangisi_daha/core/audio/sound_effects_controller.dart';

typedef SoundEffectsEnabledReader = Future<bool> Function();
typedef PlaySoundAsset = Future<void> Function(String assetPath);

abstract interface class SoundEffectService {
  Future<void> playCorrect();

  Future<void> playWrong();

  Future<void> playGameOver();

  Future<void> playExtension();

  Future<void> playHint();

  Future<void> playShieldActivate();

  Future<void> playShieldImpact();

  Future<void> playNewRecord();

  Future<void> playCriticalTime();
}

class LocalSoundEffectService implements SoundEffectService {
  const LocalSoundEffectService({
    required SoundEffectsEnabledReader isEnabled,
    required PlaySoundAsset playAsset,
  }) : _isEnabled = isEnabled,
       _playAsset = playAsset;

  static const correctAssetPath = 'audio/correct.wav';
  static const wrongAssetPath = 'audio/wrong.wav';
  static const gameOverAssetPath = 'audio/game_over.wav';
  static const extensionAssetPath = 'audio/extension.wav';
  static const hintAssetPath = 'audio/hint.wav';
  static const shieldActivateAssetPath = 'audio/shield_activate.wav';
  static const shieldImpactAssetPath = 'audio/shield_impact.wav';
  static const newRecordAssetPath = 'audio/new_record.wav';
  static const criticalTimeAssetPath = 'audio/critical_time.wav';

  final SoundEffectsEnabledReader _isEnabled;
  final PlaySoundAsset _playAsset;

  @override
  Future<void> playCorrect() => _play(correctAssetPath);

  @override
  Future<void> playWrong() => _play(wrongAssetPath);

  @override
  Future<void> playGameOver() => _play(gameOverAssetPath);

  @override
  Future<void> playExtension() => _play(extensionAssetPath);

  @override
  Future<void> playHint() => _play(hintAssetPath);

  @override
  Future<void> playShieldActivate() => _play(shieldActivateAssetPath);

  @override
  Future<void> playShieldImpact() => _play(shieldImpactAssetPath);

  @override
  Future<void> playNewRecord() => _play(newRecordAssetPath);

  @override
  Future<void> playCriticalTime() => _play(criticalTimeAssetPath);

  Future<void> _play(String assetPath) async {
    try {
      if (!await _isEnabled()) return;
      await _playAsset(assetPath);
    } on Object {
      // Sound is optional feedback and must never interrupt gameplay.
    }
  }
}

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => unawaited(player.dispose()));

  return LocalSoundEffectService(
    isEnabled: () async {
      try {
        return await ref.read(soundEffectsControllerProvider.future);
      } on Object {
        return true;
      }
    },
    playAsset: (assetPath) => player.play(AssetSource(assetPath)),
  );
});
