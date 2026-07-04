import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/photo_memory_format.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _gilancheonTrip = '''2026년 6월 22일 아버지, 어머니, 나, 집사람, 예린이, 태민이 이렇게 6명이서 길안천에 놀러갔었어 다슬기를 잡을 려고 식두들이 신이 났어
아버지와 어머니는 고스톰을 치며 시간을 보내셨고 나, 집사람, 예린이, 태민이는 다슬기를 잡아 다슬기 국을 끊여 먹으며 즐거운 시간을 보냈어''';

Memory _memoryFromSpeech(String id, String speech, {String? gps}) {
  final fields = buildVoiceMemoryFields(
    speechText: speech,
    capturedAt: DateTime(2026, 6, 22, 14, 0),
    localeCode: 'ko',
    gpsPlace: gps ?? '길안천',
  );
  return Memory(
    id: id,
    content: fields.content,
    summary: fields.summary,
    entities: fields.entities,
    category: fields.category,
    subCategory: fields.subCategory,
    createdAt: DateTime(2026, 6, 22, 14, 0),
    lat: 36.5,
    lng: 128.7,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('extractPlaceHintFromOcr picks 길안천 not long phrase', () {
    expect(extractPlaceHintFromOcr(_gilancheonTrip), '길안천');
  });

  test('gilancheon trip extracts family, place, activities', () {
    final memory = _memoryFromSpeech('gilancheon', _gilancheonTrip);
    final bundle = extractMemoryEntities(memory, localeCode: 'ko');
    final satellites = extractGraphSatellites(memory, localeCode: 'ko');

    expect(bundle.people, containsAll(['나', '아버지', '어머니', '집사람', '예린', '태민']));
    expect(bundle.people, isNot(contains('태민이는')));

    expect(bundle.places, contains('길안천'));
    expect(bundle.places.any((p) => p.contains('명이서')), isFalse);

    expect(bundle.activities, contains('고스톰'));
    expect(bundle.activities, contains('다슬기 잡기'));
    expect(bundle.activities, isNot(contains('아버지와 어머니는')));

    expect(bundle.eventTitle, '길안천 나들이');
    expect(satellites.places, contains('길안천'));
  });

  test('gilancheon graph layout satellites', () {
    final memory = _memoryFromSpeech('gilancheon', _gilancheonTrip);
    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    final people = layout.nodes.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title).toList();
    final places = layout.nodes.where((n) => n.kind == GraphNodeKind.place).map((n) => n.title).toList();
    final activities = layout.nodes.where((n) => n.kind == GraphNodeKind.activity).map((n) => n.title).toList();

    expect(people, containsAll(['아버지', '어머니', '집사람', '예린', '태민']));
    expect(places, isNot(contains('길안천')), reason: '허브 제목에 장소가 있으면 장소 위성 생략');
    expect(activities, containsAll(['고스톰', '다슬기 잡기']));

    expect(layout.nodes.any((n) => n.id.startsWith('event_hub_')), isFalse);
    const memoryId = 'memory_gilancheon';
    for (final edge in layout.edges) {
      if (edge.fromId == memoryId) {
        expect(layout.nodes.any((n) => n.id == edge.toId), isTrue);
      }
    }
    expect(layout.edges.where((e) => e.fromId == memoryId).length, greaterThanOrEqualTo(5));
  });

  test('gilancheon satellites auto-expand on small graph', () {
    final memory = _memoryFromSpeech('gilancheon', _gilancheonTrip);
    final expansions = mergeDefaultSatelliteExpansions(
      memories: [memory],
      userExpansions: const {},
      graphFragments: const {},
      localeCode: 'ko',
    );
    expect(expansions[memory.id], GraphSatelliteExpandMode.all);

    final layoutExpanded = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      satelliteExpansions: expansions,
      collapseSatellitesByDefault: true,
    );
    final people = layoutExpanded.nodes.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title).toList();
    expect(people, containsAll(['아버지', '어머니', '집사람', '예린', '태민']));
    expect(layoutExpanded.nodes.firstWhere((n) => n.id == 'memory_gilancheon').satelliteBadge, contains('사람 5'));
  });

  test('gilancheon satellites hidden when user collapsed rail', () {
    final memory = _memoryFromSpeech('gilancheon', _gilancheonTrip);
    final expansions = mergeDefaultSatelliteExpansions(
      memories: [memory],
      userExpansions: const {},
      collapsedMemoryIds: {memory.id},
      graphFragments: const {},
      localeCode: 'ko',
    );
    expect(expansions.containsKey(memory.id), isFalse);

    final layoutCollapsed = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      satelliteExpansions: expansions,
      collapseSatellitesByDefault: true,
    );
    expect(layoutCollapsed.nodes.where((n) => n.kind == GraphNodeKind.person), isEmpty);
  });

  test('gilancheon links people to their activities', () {
    final memory = _memoryFromSpeech('gilancheon', _gilancheonTrip);
    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    bool linked(String person, String activity) {
      final personId = layout.nodes.firstWhere((n) => n.title == person).id;
      final activityId = layout.nodes.firstWhere((n) => n.title == activity).id;
      return layout.edges.any(
        (e) =>
            (e.fromId == personId && e.toId == activityId) ||
            (e.fromId == activityId && e.toId == personId),
      );
    }

    expect(linked('아버지', '고스톰'), isTrue);
    expect(linked('어머니', '고스톰'), isTrue);
    expect(linked('집사람', '다슬기 잡기'), isTrue);
    expect(linked('예린', '다슬기 잡기'), isTrue);
    expect(linked('태민', '다슬기 잡기'), isTrue);
  });
}
