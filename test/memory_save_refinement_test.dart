import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_save_refinement.dart';

Memory _mem({required String content, String type = 'voice'}) {
  return Memory(
    id: '1',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 5),
    type: type,
    isLocalOnly: true,
  );
}

void main() {
  test('shows refinement for exam sentence without date or place', () {
    expect(
      shouldShowMemoryRefinementSheet(
        _mem(content: '아들이 컴퓨터활용능력 1급 시험을 친대 잘 봤으면 좋겠어'),
      ),
      isTrue,
    );
  });

  test('shows refinement when only 오늘 is present', () {
    expect(
      shouldShowMemoryRefinementSheet(
        _mem(content: '아들이 오늘 시험을 친대'),
      ),
      isTrue,
    );
  });

  test('skips refinement when date and place both explicit', () {
    expect(
      shouldShowMemoryRefinementSheet(
        _mem(content: '어제 강남역에서 친구와 저녁을 먹었다'),
      ),
      isFalse,
    );
  });

  test('always shows refinement for photos', () {
    expect(
      shouldShowMemoryRefinementSheet(
        _mem(content: '풍경', type: 'image'),
      ),
      isTrue,
    );
  });

  test('voice default place mode is none', () {
    expect(
      initialPlaceModeForRefinement(
        draft: _mem(content: '아들 시험'),
        captureLat: 37.5,
        captureLng: 127.0,
      ),
      MemoryPlaceMode.none,
    );
  });

  test('photo default place mode is captureHere when GPS exists', () {
    expect(
      initialPlaceModeForRefinement(
        draft: _mem(content: '풍경', type: 'image'),
        captureLat: 36.5,
        captureLng: 128.7,
      ),
      MemoryPlaceMode.captureHere,
    );
  });
}
