import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_event_layout.dart';
import 'package:personal_cognitive/features/graph/graph_person_layout.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/utils/memory_semantic_flow.dart';

void main() {
  const base =
      '오늘 대성그린병원 외진현황으로는 성소병원에 이정숙 정형외과, 김명희 안과, 정준호 치과, 이기동 치과, '
      '기우대 안동병원에 소화기내과 총7명이 외진나왔어 기우대 환자는 김남영 간호사가 데리고 안동병원으로 갔고 '
      '이정숙 환자는 김중원 보호사가 데리고 정형외과로 갔고 난 김명희, 정준호, 이기동 환자를데리고 치과에왔어';

  const withExtra = '$base 추가로 박태수, 이조국, 이정우 환자도 외진에 포함됐어.';

  test('user rounds sentence — semantic frame', () {
    final frame = parseMemorySemanticFlow(withExtra);
    // ignore: avoid_print
    print('=== SEMANTIC FRAME ===');
    print('event: ${frame.primaryEvent}');
    print('origin: ${frame.reportingOrganization}');
    print('declared: ${frame.declaredTotalCount} extracted: ${frame.extractedPersonCount}');
    print('people: ${frame.allPeople}');
    for (final b in frame.depthTree.branches) {
      print('branch: ${b.branchTitle} escort=${b.isEscort}');
      for (final d in b.departments) {
        print('  dept: ${d.department}');
        for (final p in d.patients) {
          print('    patient: ${p.name} companion=${p.companionName}/${p.companionRole}');
        }
      }
    }
    expect(frame.allPeople, containsAll(['기우대', '김명희', '이정숙']));
    final andong = frame.depthTree.branches.firstWhere((b) => b.organization == '안동병원');
    expect(andong.departments.single.patients.single.companionName, '김남영');
    final dental = frame.depthTree.branches
        .expand((b) => b.departments)
        .firstWhere((d) => d.department == '치과');
    expect(dental.patients.every((p) => p.companionName == '나'), isTrue);
  });

  test('user rounds sentence — event graph tree', () {
    var memory = Memory(
      id: 'verify_rounds',
      content: withExtra,
      summary: withExtra,
      entities: const [],
      createdAt: DateTime(2026, 7, 10),
    );
    memory = enrichMemoryGraphSemantics(memory);

    final layout = buildEventGraphLayout([memory]);
  final byDepth = <int, List<String>>{};
    for (final n in layout.nodes) {
      if (n.hubDepth != null) {
        byDepth.putIfAbsent(n.hubDepth!, () => []).add('${n.title} (${n.subtitle})');
      }
    }
    // ignore: avoid_print
    print('=== EVENT GRAPH BY DEPTH ===');
    for (final depth in byDepth.keys.toList()..sort()) {
      print('depth $depth:');
      for (final line in byDepth[depth]!) {
        print('  - $line');
      }
    }
    print('=== EDGES (relation) ===');
    for (final e in layout.edges.where((e) => e.relationEdge)) {
      final from = layout.nodes.firstWhere((n) => n.id == e.fromId).title;
      final to = layout.nodes.firstWhere((n) => n.id == e.toId).title;
      print('  $from --[${e.label}]--> $to');
    }

    expect(layout.nodes.any((n) => n.hubDepth == 0), isTrue);
    expect(layout.nodes.any((n) => n.title == '성소병원' || n.title.contains('성소')), isTrue);

    final rootHub = layout.nodes.firstWhere((n) => n.hubDepth == 0);
    final flatVisitEdges = layout.edges.where(
      (e) => e.fromId == rootHub.id && (e.label == '방문' || e.label == 'visit'),
    );
    expect(flatVisitEdges, isEmpty, reason: 'care tree should not duplicate flat visit edges from root hub');

    expect(layout.nodes.where((n) => n.title == '대성그린병원'), isEmpty);
    expect(layout.nodes.where((n) => n.title.contains('기우대 안동')), isEmpty);
  });

  test('user rounds sentence — person lens omits status noise node', () {
    var memory = Memory(
      id: 'verify_person',
      content: withExtra,
      summary: withExtra,
      entities: const [],
      createdAt: DateTime(2026, 7, 10),
    );
    memory = enrichMemoryGraphSemantics(memory);

    final personLayout = buildPersonOverviewGraphLayout([memory]);
    final titles = personLayout.layout.nodes.map((n) => n.title).toList();
    expect(titles, isNot(contains('현황')));
    expect(titles, contains('이정숙'));
    expect(titles, contains('기우대'));

    final eventLayout = buildEventGraphLayout([memory]);
    expect(eventLayout.nodes.any((n) => n.hubDepth == 0), isTrue);
    expect(eventLayout.nodes.any((n) => n.title == '성소병원'), isTrue);
  });
}
