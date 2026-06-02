import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 백그라운드에서 무음 오디오를 루프 재생하여 앱 프로세스를 유지한다.
///
/// Android: MethodChannel으로 포그라운드 서비스를 시작해 OS가 프로세스를 보호하도록 한다.
/// iOS: Info.plist의 UIBackgroundModes:[audio]에 의해 오디오 재생 중 백그라운드 실행이 허용된다.
class BackgroundAudioService {
  BackgroundAudioService._();
  static final instance = BackgroundAudioService._();

  static const _channel = MethodChannel('com.nagaja.app/background_audio');
  final _player = AudioPlayer();
  bool _running = false;

  /// 무음 오디오 루프 시작. 이미 실행 중이면 무시(idempotent).
  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      if (Platform.isAndroid) await _channel.invokeMethod('startService');
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.0);
      await _player.play(AssetSource('audio/silence.mp3'));
    } catch (e) {
      debugPrint('[BGAudio] start error: $e');
      _running = false;
    }
  }

  /// 무음 오디오 루프 중지. 실행 중이 아니면 무시(idempotent).
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await _player.stop();
      if (Platform.isAndroid) await _channel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('[BGAudio] stop error: $e');
    }
  }

  bool get isRunning => _running;
}
