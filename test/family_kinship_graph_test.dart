import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_event_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/family_kinship.dart';
import 'package:personal_cognitive/utils/memory_semantic_flow.dart';

const _familyText = '''
우리 가족을 정리해 주세요. 우리 가족은 아버지 김영수, 어머니 이은정, 첫째 김민수, 둘째 김하은, 할머니 박순자, 삼촌 김태호로 이루어져 있습니다. 아버지와 어머니는 부부이고, 김민수와 김하은은 형제자매입니다. 할머니는 아버지의 어머니이며, 삼촌은 아버지의 동생입니다. 김민수는 할머니를 자주 찾아뵙고, 어머니와 삼촌은 명절 준비를 함께 합니다. 가족 구성원과 관계를 보기 쉽게 정리해 주세요.
''';

void main() {
  test('parses family kinship into a generational tree', () {
    final hierarchy = parseFamilyKinship(_familyText);
    expect(hierarchy.hasHierarchy, isTrue);
    expect(hierarchy.root, '박순자');
    expect(hierarchy.depthOf('김영수'), 1);
    expect(hierarchy.depthOf('김민수'), 2);
    expect(hierarchy.depthOf('김태호'), 1);

    bool hasEdge(String from, String to) => hierarchy.hierarchyEdges.any(
      (e) => e.from == from && e.to == to,
    );
    expect(hasEdge('박순자', '김영수'), isTrue);
    expect(hasEdge('박순자', '김태호'), isTrue);
    expect(hasEdge('김영수', '김민수'), isTrue);
    expect(hasEdge('김영수', '김하은'), isTrue);

    bool hasRel(String s, String p, String o) => hierarchy.crossRelations.any(
      (r) => r.subject == s && r.predicate == p && r.object == o,
    );
    expect(hasRel('김영수', '부부', '이은정'), isTrue);
    expect(hasRel('김민수', '형제자매', '김하은'), isTrue);
    expect(hasRel('김민수', '문안', '박순자'), isTrue);
    expect(hasRel('이은정', '명절 준비', '김태호'), isTrue);
  });

  test('family text uses semantic flow org path and tidy top-down layout', () {
    final frame = parseMemorySemanticFlow(_familyText);
    expect(frame.organizationHierarchy.hasHierarchy, isTrue);
    expect(frame.organizationHierarchy.root, '박순자');

    final layout = buildEventGraphLayout([
      Memory(
        id: 'family-1',
        content: _familyText,
        summary: '우리 가족',
        entities: const [],
        createdAt: DateTime(2026, 7, 25),
      ),
    ]);
    final byTitle = {for (final n in layout.nodes) n.title: n};
    expect(byTitle.keys, containsAll(['박순자', '김영수', '김민수', '김하은', '김태호', '이은정']));
    expect(layout.edges.where((e) => e.label == '동행'), isEmpty);

    final positions = initialEventGraphPositions(
      layout.nodes,
      layout.edges,
      const Size(1400, 1000),
    );
    expect(positions[byTitle['김영수']!.id]!.dy, greaterThan(positions[byTitle['박순자']!.id]!.dy));
    expect(positions[byTitle['김민수']!.id]!.dy, greaterThan(positions[byTitle['김영수']!.id]!.dy));
  });
}
