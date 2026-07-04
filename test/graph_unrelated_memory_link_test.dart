import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_input_category.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _gilancheonTrip = '''2026년 6월 22일 아버지, 어머니, 나, 집사람, 예린이, 태민이 이렇게 6명이서 길안천에 놀러갔었어 다슬기를 잡을 려고 식두들이 신이 났어
아버지와 어머니는 고스톰을 치며 시간을 보내셨고 나, 집사람, 예린이, 태민이는 다슬기를 잡아 다슬기 국을 끊여 먹으며 즐거운 시간을 보냈어''';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  Memory _familyMemory() {
    final fields = buildVoiceMemoryFields(
      speechText: _gilancheonTrip,
      capturedAt: DateTime(2026, 6, 26, 11, 55),
      localeCode: 'ko',
      gpsPlace: '길안천',
    );
    final cat = applyMemoryInputCategory(
      localeCode: 'ko',
      inputCategory: memoryInputCategoryById('family'),
      fallbackCategory: fields.category,
      fallbackSubCategory: fields.subCategory,
    );
    return Memory(
      id: 'gilancheon',
      content: fields.content,
      summary: fields.summary,
      entities: fields.entities,
      category: cat.category,
      subCategory: cat.subCategory,
      createdAt: DateTime(2026, 6, 26, 11, 55),
      lat: 36.568,
      lng: 128.729,
    );
  }

  Memory _generalTestMemory({double? lat, double? lng}) {
    final cat = applyMemoryInputCategory(
      localeCode: 'ko',
      inputCategory: null,
      fallbackCategory: 'Other',
      fallbackSubCategory: '일반',
    );
    return Memory(
      id: 'test',
      content: '테스트',
      summary: '테스트',
      entities: const [],
      category: cat.category,
      subCategory: cat.subCategory,
      createdAt: DateTime(2026, 6, 26, 12, 5),
      lat: lat,
      lng: lng,
    );
  }

  test('family outing and unrelated general test should not link memory hubs', () {
    final family = _familyMemory();
    final general = _generalTestMemory(lat: 36.568, lng: 128.729);

    final layout = buildMemoryGraphLayout([family, general], localeCode: 'ko');

    final memoryEdges = layout.edges.where(
      (e) =>
          e.memoryToMemory &&
          ((e.fromId == 'memory_gilancheon' && e.toId == 'memory_test') ||
              (e.fromId == 'memory_test' && e.toId == 'memory_gilancheon')),
    );
    expect(memoryEdges, isEmpty, reason: 'unrelated memories must not bridge: $memoryEdges');

    final familyNode = layout.nodes.firstWhere((n) => n.id == 'memory_gilancheon');
    final testNode = layout.nodes.firstWhere((n) => n.id == 'memory_test');
    expect(familyNode.layoutClusterId, isNot(testNode.layoutClusterId),
        reason: '가족·일반은 같은 GPS여도 맥락이 다르면 별도 묶음');
  });

  test('general test must not appear as satellite on family memory', () {
    final family = _familyMemory();
    final general = _generalTestMemory(lat: 36.570, lng: 128.731);

    final layout = buildMemoryGraphLayout(
      [family, general],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(layout.nodes.any((n) => n.title == '테스트' && n.kind != GraphNodeKind.memory), isFalse);
    final fromFamily = layout.edges.where((e) => e.fromId == 'memory_gilancheon').map((e) => e.toId);
    expect(fromFamily.contains('memory_test'), isFalse);
  });
}
