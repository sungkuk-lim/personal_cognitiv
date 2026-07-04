import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/voice/voice_stt_engine.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  test('VoiceSttEngineResolver uses device STT when omakase key absent', () {
    final engine = VoiceSttEngineResolver.resolve(stt.SpeechToText());
    expect(engine, isA<DeviceVoiceSttEngine>());
    expect(engine.isCloudBacked, isFalse);
  });
}
