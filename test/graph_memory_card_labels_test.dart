import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_meaning.dart';
import 'package:personal_cognitive/utils/graph_memory_card_labels.dart';

void main() {
  test('graphMeaningSentence prefers meaningful AI summary', () {
    final memory = Memory(
      id: '1',
      content: '어머니와 저녁을 먹었다.',
      summary: '가족과 따뜻한 저녁을 보낸 순간.',
      entities: const ['어머니'],
      createdAt: DateTime(2026, 6, 17, 21, 27),
    );

    expect(graphMeaningSentence(memory, localeCode: 'ko'), '어머니와 저녁을 먹었다.');
  });

  test('graphMeaningSentence falls back to user content over metadata summary', () {
    final memory = Memory(
      id: '2',
      content: '광안리에서 일몰을 봤다.',
      summary: '광안리 · 6월 17일 21:27',
      entities: const ['광안리'],
      createdAt: DateTime(2026, 6, 17, 21, 27),
      lat: 36.56,
      lng: 128.72,
    );

    expect(graphMeaningSentence(memory, localeCode: 'ko'), '광안리에서 일몰을 봤다.');
  });

  test('graphMemoryMetaLine shows date time place lot without people', () {
    final memory = Memory(
      id: '3',
      content: '어머니와 저녁을 먹었다.',
      summary: '33-21 · 어머니 · 6월 17일 21:27',
      entities: const ['어머니', '33-21'],
      createdAt: DateTime(2026, 6, 17, 21, 27),
      lat: 36.56,
      lng: 128.72,
    );

    final meta = graphMemoryMetaLine(
      memory,
      const {'36.5600,128.7200': '33-21'},
      const {'36.5600,128.7200': '경북 안동시 한화2길 33-21'},
      localeCode: 'ko',
    );

    expect(meta, '6월 17일, 21:27');
  });

  test('buildGroupGraphMeaning combines multiple memories', () {
    final memories = [
      Memory(
        id: 'a',
        content: 'Flutter 공부를 시작했다.',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 6, 17, 18),
      ),
      Memory(
        id: 'b',
        content: '어머니와 저녁을 먹었다.',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 6, 17, 21),
      ),
    ];

    expect(
      buildGroupGraphMeaning(memories, localeCode: 'ko'),
      '6월 17일, Flutter 공부를 시작했다, 어머니와 저녁을 먹었다 등이 담긴 하루.',
    );
  });

  test('buildGroupGraphMeaning skips meta headline memory', () {
    final memories = [
      Memory(
        id: 'head',
        content: '오늘 있었던 일',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 6, 17, 18),
      ),
      Memory(
        id: 'a',
        content: 'Flutter공부를 시작했다.',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 6, 17, 18, 5),
      ),
      Memory(
        id: 'b',
        content: '어머니와 저녁을 먹었다.',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 6, 17, 21),
      ),
    ];

    expect(
      buildGroupGraphMeaning(memories, localeCode: 'ko'),
      '6월 17일, Flutter공부를 시작했다, 어머니와 저녁을 먹었다 등이 담긴 하루.',
    );
  });

  test('graphMemoryAddressLine uses full geocoded address', () {
    final memory = Memory(
      id: '4',
      content: '어머니와 저녁을 먹었다.',
      summary: '',
      entities: const [],
      createdAt: DateTime(2026, 6, 17, 21, 27),
      lat: 36.56,
      lng: 128.72,
    );

    final address = graphMemoryAddressLine(
      memory,
      const {'36.5600,128.7200': '33-21'},
      const {'36.5600,128.7200': '경북 안동시 한화2길 33-21'},
    );

    expect(address, '경북 안동시 한화2길 33-21');
  });
}
