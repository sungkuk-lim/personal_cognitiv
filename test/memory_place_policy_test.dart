import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_place_cache.dart';
import 'package:personal_cognitive/utils/memory_place_policy.dart';

Memory _mem({
  required String content,
  String type = 'voice',
  double? lat,
  double? lng,
  String? recallPlaceLabel,
  List<String> entities = const [],
}) {
  return Memory(
    id: '1',
    userId: 'u',
    content: content,
    summary: content,
    entities: entities,
    createdAt: DateTime(2026, 7, 5),
    type: type,
    lat: lat,
    lng: lng,
    recallPlaceLabel: recallPlaceLabel,
    isLocalOnly: true,
  );
}

void main() {
  test('voice memory without place does not use capture GPS for display', () {
    final memory = _mem(
      content: '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대',
      lat: 37.5665,
      lng: 126.9780,
    );

    expect(memoryUsesGpsForDisplay(memory), isFalse);
    expect(displayCoordinatesForMemory(memory), isNull);
    expect(
      displayPlaceAddress(memory, const {}, const {}, localeCode: 'ko'),
      '장소 미상',
    );
  });

  test('photo memory uses capture GPS for display', () {
    final memory = _mem(
      content: '월영교',
      type: 'image',
      lat: 36.5683,
      lng: 128.7294,
    );

    expect(memoryUsesGpsForDisplay(memory), isTrue);
    expect(displayCoordinatesForMemory(memory)?.lat, 36.5683);
  });

  test('recall place label overrides GPS reverse geocode', () {
    final memory = _mem(
      content: '아들 시험 응원',
      lat: 37.5665,
      lng: 126.9780,
      recallPlaceLabel: '서울시교육청',
    );

    expect(
      displayPlaceAddress(memory, const {}, const {}, localeCode: 'ko'),
      '서울시교육청',
    );
  });

  test('shouldPersistCaptureGpsOnSave is false for place-less voice', () {
    expect(
      shouldPersistCaptureGpsOnSave(
        type: 'voice',
        content: '아들이 오늘 시험을 친대',
      ),
      isFalse,
    );
  });

  test('shouldPersistCaptureGpsOnSave is true for photo', () {
    expect(
      shouldPersistCaptureGpsOnSave(type: 'image', content: '풍경'),
      isTrue,
    );
  });
}
