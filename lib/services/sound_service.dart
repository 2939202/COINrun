import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 효과음
//
//   punch  - 대결에서 칠 때 (휙 + 퍽)
//   hit    - 대결에서 맞았을 때 (묵직한 퍽)
//   whoosh - 대결에서 피했을 때 (휙)
//   coin   - 러닝 중 골드가 생길 때 (띠링). 생긴 만큼 여러 번 울립니다.
// 소리 파일은 assets/sounds/에 있습니다. (파이썬으로 합성한 짧은 WAV)
//
// 볼륨은 설정에서 0~100%로 고르고, 이 폰에만 저장합니다. (shared_preferences)
// 계정마다 따로 둘 이유가 없어서 Firestore에는 올리지 않습니다.
// ============================================================
enum Sfx {
  punch('sounds/punch.wav'),
  hit('sounds/hit.wav'),
  whoosh('sounds/whoosh.wav'),
  coin('sounds/coin.wav');

  final String asset; // AssetSource는 assets/를 빼고 적습니다.

  const Sfx(this.asset);
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _volumeKey = 'sfxVolume';
  static const double defaultVolume = 0.7;

  // 설정 화면의 슬라이더가 이 값을 지켜봅니다.
  final ValueNotifier<double> volume = ValueNotifier(defaultVolume);
  bool _loaded = false;

  // 소리가 겹쳐도 끊기지 않게 소리마다 플레이어를 따로 둡니다.
  final Map<Sfx, AudioPlayer> _players = {};

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      volume.value = prefs.getDouble(_volumeKey) ?? defaultVolume;
    } catch (error) {
      debugPrint('효과음 볼륨을 읽지 못했습니다: $error');
    }
  }

  Future<void> setVolume(double value) async {
    volume.value = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume.value);
    } catch (error) {
      debugPrint('효과음 볼륨을 저장하지 못했습니다: $error');
    }
  }

  // 골드가 count만큼 생겼을 때 띠링을 그만큼 울립니다.
  // 한꺼번에 많이 생겨도 너무 길어지지 않게 최대 8번, 0.14초 간격으로.
  Future<void> playCoins(int count) async {
    final int times = count.clamp(0, 8);
    for (int i = 0; i < times; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 140));
      // 겹쳐 울리게 기다리지 않고 틉니다.
      unawaited(play(Sfx.coin));
    }
  }

  Future<void> play(Sfx sfx) async {
    await load();
    if (volume.value <= 0) return;
    try {
      final AudioPlayer player = _players[sfx] ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        // 다른 앱 음악을 멈추지 않고 그 위에 살짝 얹습니다.
        ..setAudioContext(
          AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
        );
      await player.stop();
      await player.play(AssetSource(sfx.asset), volume: volume.value);
    } catch (error) {
      // 소리가 안 나도 대결은 그대로 진행합니다.
      debugPrint('효과음을 틀지 못했습니다: $error');
    }
  }
}
