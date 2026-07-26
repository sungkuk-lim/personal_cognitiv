import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/organization_hierarchy.dart';

void main() {
  test('hierarchy json round-trip via entity tag', () {
    const h = OrganizationHierarchy(
      root: '공부 계획',
      nodes: [
        OrganizationHierarchyNode(
          label: '공부 계획',
          kind: OrganizationNodeKind.organization,
        ),
        OrganizationHierarchyNode(
          label: '프로그래밍',
          kind: OrganizationNodeKind.organization,
        ),
        OrganizationHierarchyNode(
          label: 'Python',
          kind: OrganizationNodeKind.organization,
        ),
      ],
      hierarchyEdges: [
        OrganizationHierarchyEdge(from: '공부 계획', to: '프로그래밍', label: '과목'),
        OrganizationHierarchyEdge(from: '프로그래밍', to: 'Python', label: '구성'),
      ],
      crossRelations: [
        OrganizationCrossRelation(
          subject: 'Python',
          predicate: '도움',
          object: 'Flutter',
        ),
      ],
    );

    final tag = h.toEntityTag();
    expect(tag, isNotNull);
    expect(tag!.startsWith(kHierarchyJsonPrefix), isTrue);

    final restored = OrganizationHierarchy.fromEntityTags([tag]);
    expect(restored, isNotNull);
    expect(restored!.hasHierarchy, isTrue);
    expect(restored.root, '공부 계획');
    expect(restored.hierarchyEdges.length, 2);
  });

  test('sanitize drops labels not in source text', () {
    const h = OrganizationHierarchy(
      root: '여행',
      nodes: [
        OrganizationHierarchyNode(
          label: '여행',
          kind: OrganizationNodeKind.organization,
        ),
        OrganizationHierarchyNode(
          label: '제주도',
          kind: OrganizationNodeKind.organization,
        ),
        OrganizationHierarchyNode(
          label: '존재하지않는도시',
          kind: OrganizationNodeKind.organization,
        ),
      ],
      hierarchyEdges: [
        OrganizationHierarchyEdge(from: '여행', to: '제주도', label: '목적지'),
        OrganizationHierarchyEdge(from: '여행', to: '존재하지않는도시', label: '목적지'),
        OrganizationHierarchyEdge(from: '제주도', to: '우도', label: '계획'),
      ],
    );

    final cleaned = sanitizeHierarchyAgainstSource(
      h,
      '올해 여행으로 제주도와 우도를 갑니다',
    );
    expect(cleaned.hasHierarchy, isTrue);
    expect(cleaned.nodes.map((n) => n.label), containsAll(['여행', '제주도', '우도']));
    expect(cleaned.nodes.map((n) => n.label), isNot(contains('존재하지않는도시')));
  });
}
