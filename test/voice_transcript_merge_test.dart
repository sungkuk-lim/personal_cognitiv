import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/voice/voice_input_dialog.dart';

void main() {
  test('normalizeSpeechText removes repeated words and blocks', () {
    expect(
      normalizeSpeechText('오늘 오늘 오늘 오늘 오늘 오늘 오늘 캐리어 오늘 캐리어 도착했어'),
      '오늘 캐리어 도착했어',
    );
    expect(
      normalizeSpeechText('캐리어 도착 캐리어 도착 캐리어 도착'),
      '캐리어 도착',
    );
  });

  test('mergeSpeechTranscript merges overlap without duplication', () {
    expect(
      mergeSpeechTranscript('오늘 캐리어', '오늘 캐리어 도착했어'),
      '오늘 캐리어 도착했어',
    );
    expect(
      mergeSpeechTranscript('오늘 캐리어 도착했어', '도착했어'),
      '오늘 캐리어 도착했어',
    );
  });

  test('mergeSpeechTranscript handles partial to final transition', () {
    expect(
      mergeSpeechTranscript(
        '오늘 캐리어',
        '오늘 캐리어 도착했어',
        previousPartial: '오늘 캐리어',
      ),
      '오늘 캐리어 도착했어',
    );
  });
}

