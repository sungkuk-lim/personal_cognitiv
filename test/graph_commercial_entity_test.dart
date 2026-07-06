import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/utils/memory_participation_extract.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

Memory _mem(String content) {
  return Memory(
    id: 'exam_son',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 5),
    isLocalOnly: true,
  );
}

void main() {
  const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';

  test('participation links son to exam', () {
    final links = extractParticipationLinks(
      text,
      localeCode: 'ko',
      knownActivities: {'시험', '컴퓨터 활용 능력 1급 시험'},
    );
    expect(links.any((l) => l.person == '아들' && l.activity.contains('시험')), isTrue);
  });

  test('relations include 응시 and 응원 for family exam wish', () {
    final memory = _mem(text);
    final relations = effectiveRelationsForMemory(memory);

    expect(relations.any((r) => r.predicate == '응시' && r.subject == '아들'), isTrue);
    expect(relations.any((r) => r.predicate == '응원' && r.subject == '나' && r.object == '아들'), isTrue);
  });

  test('visible satellites are son and one exam event only', () {
    final memory = _mem(text);
    final visible = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');

    expect(visible.people, ['아들']);
    expect(visible.events, hasLength(1));
    expect(visible.events.single, contains('시험'));
    expect(visible.activities, isEmpty);
    expect(visible.interests, isEmpty);
  });

  test('graph layout shows hub plus son and exam event only', () {
    final memory = _mem(text);
    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    final satellites = layout.nodes.where((n) => n.kind != GraphNodeKind.memory).toList();
    expect(satellites, hasLength(2));
    expect(satellites.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title), ['아들']);
    expect(satellites.where((n) => n.kind == GraphNodeKind.event).single.title, contains('시험'));
    expect(layout.nodes.where((n) => n.title == '나'), isEmpty);
    expect(layout.nodes.where((n) => n.title == '시험' && n.kind == GraphNodeKind.activity), isEmpty);
    expect(layout.nodes.where((n) => n.title == '컴퓨터'), isEmpty);

    final sonId = layout.nodes.firstWhere((n) => n.title == '아들').id;
    final examId = layout.nodes.firstWhere((n) => n.kind == GraphNodeKind.event).id;
    expect(
      layout.edges.any((e) => e.fromId == sonId && e.toId == examId && e.label == '응시'),
      isTrue,
    );
    expect(
      layout.edges.any((e) => e.fromId.startsWith('memory_') && e.toId == sonId && e.label == '응원'),
      isTrue,
    );
  });

  test('voice category infers Social for family exam wish', () {
    expect(inferVoiceCategory(text), 'Social');
  });
}
