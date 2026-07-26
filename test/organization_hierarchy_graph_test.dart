import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_event_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_semantic_flow.dart';

const _abcOrganizationText = '''
최상위 조직은 'ABC그룹'입니다.
ABC그룹 아래에는 경영부문, 기술부문, 영업부문이 있습니다.
경영부문에는 전략실과 인사팀이 있으며, 전략실에는 기획파트와 데이터분석파트가 있습니다. 기획파트에는 김민수와 이지은이, 데이터분석파트에는 박준호가 소속되어 있습니다.
기술부문에는 플랫폼본부와 AI본부가 있습니다. 플랫폼본부에는 백엔드팀과 프론트엔드팀이 있으며, 백엔드팀에는 최수현과 정하늘이, 프론트엔드팀에는 윤도현이 있습니다. AI본부에는 모델개발팀이 있으며 한유진과 오세진이 소속되어 있습니다.
영업부문에는 국내영업팀과 해외영업팀이 있습니다. 국내영업팀에는 서울지사와 부산지사가 있으며, 해외영업팀에는 일본지사가 있습니다.
- 김민수와 최수현은 Alpha 프로젝트를 함께 진행합니다.
- 이지은과 한유진은 Beta 프로젝트를 함께 진행합니다.
- Alpha 프로젝트는 Beta 프로젝트와 연계됩니다.
- 박준호는 전략실과 AI본부를 모두 지원합니다.
- 윤도현은 플랫폼본부와 국내영업팀을 연결하는 담당자입니다.
- 한유진은 최수현의 멘토입니다.
- 김민수는 이지은과 협업하며, 오세진과도 공동 연구를 진행합니다.
''';

Memory _memory() => Memory(
  id: 'abc-org',
  content: _abcOrganizationText,
  summary: 'ABC그룹 조직도',
  entities: const [],
  createdAt: DateTime(2026, 7, 25, 10, 19),
);

void main() {
  test('parses five-level corporate hierarchy without truncating labels', () {
    final hierarchy = parseMemorySemanticFlow(
      _abcOrganizationText,
    ).organizationHierarchy;

    expect(hierarchy.hasHierarchy, isTrue);
    expect(hierarchy.root, 'ABC그룹');
    expect(hierarchy.depthOf('김민수'), 4);
    expect(hierarchy.depthOf('최수현'), 4);
    expect(hierarchy.depthOf('서울지사'), 3);

    final labels = hierarchy.nodes.map((n) => n.label).toSet();
    expect(
      labels,
      containsAll(<String>{
        '경영부문',
        '기술부문',
        '영업부문',
        '전략실',
        '플랫폼본부',
        'AI본부',
        '백엔드팀',
        '프론트엔드팀',
        '국내영업팀',
        '해외영업팀',
        '김민수',
        '이지은',
        '박준호',
        '최수현',
        '정하늘',
        '윤도현',
        '한유진',
        '오세진',
      }),
    );
    expect(labels, isNot(contains('트렌드팀')));
    expect(labels, isNot(contains('외영업팀')));
    expect(labels, isNot(contains('오세진과도')));
  });

  test('parses projects, support, connector, mentor, and collaboration', () {
    final relations = parseMemorySemanticFlow(
      _abcOrganizationText,
    ).organizationHierarchy.crossRelations;

    bool has(String s, String p, String o) => relations.any(
      (r) => r.subject == s && r.predicate == p && r.object == o,
    );

    expect(has('김민수', '참여', 'Alpha 프로젝트'), isTrue);
    expect(has('최수현', '참여', 'Alpha 프로젝트'), isTrue);
    expect(has('이지은', '참여', 'Beta 프로젝트'), isTrue);
    expect(has('한유진', '참여', 'Beta 프로젝트'), isTrue);
    expect(has('Alpha 프로젝트', '연계', 'Beta 프로젝트'), isTrue);
    expect(
      has('박준호', '지원', '전략실'),
      isTrue,
      reason: relations
          .map((r) => '${r.subject}-${r.predicate}-${r.object}')
          .join(', '),
    );
    expect(has('박준호', '지원', 'AI본부'), isTrue);
    expect(
      has('윤도현', '연결 담당', '플랫폼본부'),
      isTrue,
      reason: relations
          .map((r) => '${r.subject}-${r.predicate}-${r.object}')
          .join(', '),
    );
    expect(has('윤도현', '연결 담당', '국내영업팀'), isTrue);
    expect(has('한유진', '멘토', '최수현'), isTrue);
    expect(has('김민수', '협업', '이지은'), isTrue);
    expect(has('김민수', '공동 연구', '오세진'), isTrue);
  });

  test('event graph preserves hierarchy edges and semantic cross links', () {
    final layout = buildEventGraphLayout([_memory()]);
    final byTitle = {for (final node in layout.nodes) node.title: node};

    expect(byTitle.keys, containsAll(['ABC그룹', '경영부문', '기획파트', '김민수']));
    expect(byTitle['ABC그룹']!.hubDepth, 0);
    expect(byTitle['김민수']!.hubDepth, 4);

    bool hasEdge(String from, String label, String to, {bool? semanticLink}) {
      final fromId = byTitle[from]!.id;
      final toId = byTitle[to]!.id;
      return layout.edges.any(
        (edge) =>
            edge.fromId == fromId &&
            edge.toId == toId &&
            edge.label == label &&
            (semanticLink == null || edge.semanticLink == semanticLink),
      );
    }

    expect(hasEdge('ABC그룹', '소속', '경영부문', semanticLink: false), isTrue);
    expect(hasEdge('기획파트', '소속', '김민수', semanticLink: false), isTrue);
    expect(hasEdge('김민수', '참여', 'Alpha 프로젝트', semanticLink: true), isTrue);
    expect(hasEdge('한유진', '멘토', '최수현', semanticLink: true), isTrue);
    expect(layout.edges.where((e) => e.label == '동행'), isEmpty);

    final positions = initialEventGraphPositions(
      layout.nodes,
      layout.edges,
      const Size(2000, 1400),
    );
    final rootPosition = positions[byTitle['ABC그룹']!.id]!;
    final minsu = positions[byTitle['김민수']!.id]!;
    final management = positions[byTitle['경영부문']!.id]!;
    // Top-down: deeper nodes are below the root; siblings share a row band.
    expect(management.dy, greaterThan(rootPosition.dy));
    expect(minsu.dy, greaterThan(management.dy));
    expect(
      (positions[byTitle['기술부문']!.id]!.dy - management.dy).abs(),
      lessThan(20),
      reason: 'same-depth siblings should share a horizontal band',
    );
  });
}
