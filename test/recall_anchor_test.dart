import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/recall_anchor.dart';

Memory _memory({
  String content = '',
  List<String> entities = const [],
  double? lat,
  double? lng,
  double? recallLat,
  double? recallLng,
  String? recallPlaceLabel,
  bool recallEnabled = true,
}) {
  return Memory(
    id: 'm1',
    content: content,
    summary: '',
    entities: entities,
    createdAt: DateTime(2025, 6, 1),
    category: '일상',
    subCategory: '기타',
    lat: lat,
    lng: lng,
    recallLat: recallLat,
    recallLng: recallLng,
    recallPlaceLabel: recallPlaceLabel,
    recallEnabled: recallEnabled,
  );
}

void main() {
  group('primaryStoryPlaceLabel', () {
    test('prefers named place from entities', () {
      final m = _memory(
        content: '광안리 해수욕장',
        entities: ['광안리 해수욕장', '집'],
      );
      expect(primaryStoryPlaceLabel(m), '광안리 해수욕장');
    });
  });

  group('shouldConfirmRecallPlace', () {
    test('true when story place differs from capture GPS', () {
      expect(
        shouldConfirmRecallPlace(
          capturePlaceLabel: '우리집',
          storyPlaceLabel: '광안리 해수욕장',
          captureLat: 35.15,
          captureLng: 129.05,
          storyLat: 35.153,
          storyLng: 129.118,
        ),
        isTrue,
      );
    });

    test('false when labels overlap', () {
      expect(
        shouldConfirmRecallPlace(
          capturePlaceLabel: '광안리',
          storyPlaceLabel: '광안리 해수욕장',
          captureLat: 35.15,
          captureLng: 129.05,
          storyLat: 35.153,
          storyLng: 129.118,
        ),
        isFalse,
      );
    });
  });

  group('effectiveRecallCoordinates', () {
    test('uses recall anchor when enabled', () {
      final m = _memory(
        lat: 35.1,
        lng: 129.0,
        recallLat: 35.153,
        recallLng: 129.118,
        recallEnabled: true,
      );
      final coords = effectiveRecallCoordinates(m);
      expect(coords?.lat, 35.153);
      expect(coords?.lng, 129.118);
    });

    test('null when recall disabled', () {
      final m = _memory(lat: 35.1, lng: 129.0, recallEnabled: false);
      expect(effectiveRecallCoordinates(m), isNull);
    });

    test('falls back to capture GPS for legacy memories', () {
      final m = _memory(lat: 35.1, lng: 129.0, recallEnabled: true);
      final coords = effectiveRecallCoordinates(m);
      expect(coords?.lat, 35.1);
      expect(coords?.lng, 129.0);
    });
  });

  group('recallAnchorStatus', () {
    test('active when recall coordinates and label exist', () {
      final m = _memory(
        recallLat: 35.153,
        recallLng: 129.118,
        recallPlaceLabel: '광안리 해수욕장',
      );
      expect(recallAnchorStatus(m), RecallAnchorStatus.active);
    });

    test('disabled when recall explicitly off', () {
      final m = _memory(recallEnabled: false);
      expect(recallAnchorStatus(m), RecallAnchorStatus.disabled);
    });

    test('needsPlace when story place differs but no recall anchor', () {
      final m = _memory(
        content: '광안리에서 즐거웠다',
        entities: ['광안리 해수욕장'],
        lat: 35.15,
        lng: 129.05,
        recallEnabled: true,
      );
      expect(recallAnchorStatus(m), RecallAnchorStatus.needsPlace);
    });
  });
}
