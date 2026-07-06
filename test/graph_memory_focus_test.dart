import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellite_chips.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _busanTrip = '''6월 18일 해순, 은정, 연숙, 재운, 대호 이렇게 나를 포함해서 6명이 부산 광안리 해수욕장에 20일 까지 여행을 했어
장어구이, 조개구이, 술.. 좋은 추억이 되었는데 18일 밤 11시쯤 연숙이가 대호랑 무슨 일이 있었는지 연숙이가 없어져서 여행이 엉망이 됐어
다음날 연락이 왔는데 혼자사 집으로 갔다는거야
여행이 즐거워야 되는건데.. 많이 실망했어''';

Memory _busanMemory() {
  final fields = buildVoiceMemoryFields(
    speechText: _busanTrip,
    capturedAt: DateTime(2026, 6, 18, 23),
    localeCode: 'ko',
    gpsPlace: '부산 광안리 해수욕장',
  );
  return Memory(
    id: 'busan_trip',
    content: fields.content,
    summary: fields.summary,
    entities: fields.entities,
    category: fields.category,
    createdAt: DateTime(2026, 6, 18, 23),
  );
}

void main() {
  test('buildMemoryFocusGraphLayout shows one memory hub and satellites', () {
    final memory = _busanMemory();
    final result = buildMemoryFocusGraphLayout(memory, localeCode: 'ko');

    expect(result.memoryId, 'busan_trip');
    expect(result.layout.nodes.any((n) => n.id == 'memory_busan_trip'), isTrue);
    expect(result.layout.nodes.where((n) => n.kind == GraphNodeKind.person).length, greaterThanOrEqualTo(2));
    expect(result.layout.nodes.any((n) => n.title.contains('해수욕장')), isTrue);
    expect(result.layout.edges, isNotEmpty);
  });

  test('collectGraphSatelliteChipItems orders people and places first', () {
    final memory = _busanMemory();
    final items = collectGraphSatelliteChipItems(memory, localeCode: 'ko', maxCount: 6);
    final satellites = extractGraphSatellites(memory, localeCode: 'ko');

    expect(items, isNotEmpty);
    expect(items.first.kind, GraphNodeKind.person);
    expect(items.any((i) => satellites.people.contains(i.label) || satellites.places.contains(i.label)), isTrue);
  });
}
