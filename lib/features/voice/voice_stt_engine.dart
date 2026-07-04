import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/crash_reporting.dart';
import '../../core/env.dart';
import '../../services/omakase_stt_service.dart';

const Duration speechListenFor = Duration(minutes: 30);
const Duration speechPauseFor = Duration(seconds: 15);

/// 음성→텍스트 엔진 — Omakase(클라우드) 우선, 없으면 기기 STT.
abstract class VoiceSttEngine {
  bool get isCloudBacked;
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
    if (AppEnv.hasOmakaseStt) {
      return OmakaseVoiceSttEngine(fallback: DeviceVoiceSttEngine(deviceSpeech));
    }
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

class OmakaseVoiceSttEngine implements VoiceSttEngine {
  OmakaseVoiceSttEngine({required this.fallback});

  final DeviceVoiceSttEngine fallback;
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _pollTimer;
  String? _recordPath;
  String _localeId = 'ko';
  void Function(String recognized, bool finalResult)? _onResult;
  int _lastSentBytes = 0;
  bool _listening = false;
  bool _useFallback = false;

  @override
  bool get isCloudBacked => !_useFallback;

  @override
  bool get isListening => _useFallback ? fallback.isListening : _listening;

  @override
  Future<bool> initialize({VoidCallback? onAutoRestart}) async {
    if (!await _recorder.hasPermission()) return false;
    if (!AppEnv.hasOmakaseStt) {
      return fallback.initialize(onAutoRestart: onAutoRestart);
    }
    return true;
  }

  Future<void> _activateFallback({
    required String localeId,
    required void Function(String recognized, bool finalResult) onResult,
    VoidCallback? onAutoRestart,
  }) async {
    _useFallback = true;
    await _recorder.stop();
    _pollTimer?.cancel();
    _listening = false;
    await fallback.initialize(onAutoRestart: onAutoRestart);
    await fallback.listen(localeId: localeId, onResult: onResult);
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String recognized, bool finalResult) onResult,
    Duration listenFor = speechListenFor,
    Duration pauseFor = speechPauseFor,
  }) async {
    if (_useFallback) {
      await fallback.listen(
        localeId: localeId,
        onResult: onResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
      );
      return;
    }
    if (_listening) return;

    _localeId = localeId;
    _onResult = onResult;
    _lastSentBytes = 0;
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/omakase_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _recordPath!,
      );
    } catch (e, stack) {
      debugPrint('Omakase record start failed: $e');
      await CrashReporting.recordError(e, stack, reason: 'omakase_record_start');
      await _activateFallback(localeId: localeId, onResult: onResult);
      return;
    }
    _listening = true;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) => _pollPartial());
  }

  Future<void> _pollPartial() async {
    if (!_listening || _recordPath == null || _onResult == null) return;
    final file = File(_recordPath!);
    if (!file.existsSync()) return;
    final bytes = await file.length();
    if (bytes < 8000 || bytes - _lastSentBytes < 3500) return;
    _lastSentBytes = bytes;

    final text = await OmakaseSttService.instance.transcribeFile(file, localeId: _localeId);
    if (text.isNotEmpty) _onResult!(text, false);
  }

  @override
  Future<void> stop() async {
    if (_useFallback) {
      await fallback.stop();
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_listening) return;
    _listening = false;

    await _recorder.stop();
    final path = _recordPath;
    if (path != null) {
      final file = File(path);
      final text = await OmakaseSttService.instance.transcribeFile(file, localeId: _localeId);
      if (text.isNotEmpty) {
        _onResult?.call(text, true);
      }
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    _recordPath = null;
    _onResult = null;
  }
}
