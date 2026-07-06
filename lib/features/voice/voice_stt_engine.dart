import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const Duration speechListenFor = Duration(minutes: 30);
const Duration speechPauseFor = Duration(seconds: 15);

/// 음성→텍스트 — 기기 STT만 사용 (무료·실시간).
/// OpenAI는 저장 단계에서 텍스트 분류·요약에만 사용합니다.
abstract class VoiceSttEngine {
  bool get isCloudBacked => false;
  Future<bool> initialize({VoidCallback? onAutoRestart});
  Future<void> listen({
    required String localeId,
    required void Function(String recognized, bool finalResult) onResult,
    Duration listenFor = speechListenFor,
    Duration pauseFor = speechPauseFor,
  });
  Future<void> stop();
  bool get isListening;
}

class VoiceSttEngineResolver {
  static VoiceSttEngine resolve(stt.SpeechToText deviceSpeech) {
    return DeviceVoiceSttEngine(deviceSpeech);
  }
}

class DeviceVoiceSttEngine implements VoiceSttEngine {
  DeviceVoiceSttEngine(this._speech);

  final stt.SpeechToText _speech;
  VoidCallback? _onAutoRestart;

  @override
  bool get isCloudBacked => false;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({VoidCallback? onAutoRestart}) async {
    _onAutoRestart = onAutoRestart;
    return _speech.initialize(
      onStatus: (status) {
        if (status == 'done') _onAutoRestart?.call();
      },
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String recognized, bool finalResult) onResult,
    Duration listenFor = speechListenFor,
    Duration pauseFor = speechPauseFor,
  }) async {
    if (_speech.isListening) return;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
