import 'package:flutter_test/flutter_test.dart';
import 'package:hangisi_daha/core/audio/sound_effect_service.dart';

void main() {
  test('enabled correct feedback plays the correct asset', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => true,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playCorrect();

    expect(playedAssets, [LocalSoundEffectService.correctAssetPath]);
  });

  test('enabled wrong feedback plays the wrong asset', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => true,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playWrong();

    expect(playedAssets, [LocalSoundEffectService.wrongAssetPath]);
  });

  test('disabled correct feedback does not play', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => false,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playCorrect();

    expect(playedAssets, isEmpty);
  });

  test('disabled wrong feedback does not play', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => false,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playWrong();

    expect(playedAssets, isEmpty);
  });

  test('audio playback failure is swallowed', () async {
    final service = LocalSoundEffectService(
      isEnabled: () async => true,
      playAsset: (path) async => throw StateError('audio unavailable'),
    );

    await expectLater(service.playCorrect(), completes);
  });

  test('semantic events map to their exact final assets', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => true,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playCorrect();
    await service.playWrong();
    await service.playGameOver();
    await service.playExtension();
    await service.playHint();
    await service.playShieldActivate();
    await service.playShieldImpact();
    await service.playNewRecord();
    await service.playCriticalTime();

    expect(playedAssets, [
      LocalSoundEffectService.correctAssetPath,
      LocalSoundEffectService.wrongAssetPath,
      LocalSoundEffectService.gameOverAssetPath,
      LocalSoundEffectService.extensionAssetPath,
      LocalSoundEffectService.hintAssetPath,
      LocalSoundEffectService.shieldActivateAssetPath,
      LocalSoundEffectService.shieldImpactAssetPath,
      LocalSoundEffectService.newRecordAssetPath,
      LocalSoundEffectService.criticalTimeAssetPath,
    ]);
  });

  test('master toggle OFF blocks every semantic sound', () async {
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => false,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playCorrect();
    await service.playWrong();
    await service.playGameOver();
    await service.playExtension();
    await service.playHint();
    await service.playShieldActivate();
    await service.playShieldImpact();
    await service.playNewRecord();
    await service.playCriticalTime();

    expect(playedAssets, isEmpty);
  });

  test('turning sound back ON affects only the next event', () async {
    var enabled = false;
    final playedAssets = <String>[];
    final service = LocalSoundEffectService(
      isEnabled: () async => enabled,
      playAsset: (path) async => playedAssets.add(path),
    );

    await service.playWrong();
    enabled = true;
    await service.playCorrect();

    expect(playedAssets, [LocalSoundEffectService.correctAssetPath]);
  });
}
