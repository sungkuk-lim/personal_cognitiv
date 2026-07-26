import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/utils/memory_quantity_validate.dart';
import 'package:personal_cognitive/utils/memory_semantic_flow.dart';

Memory _memory(String content) => Memory(
      id: 't',
      content: content,
      summary: '',
      entities: const [],
      createdAt: DateTime(2026, 7, 9),
    );

void main() {
  const clinicReport =
      '오늘 대성그린병원 외진현황 보고로는 총 7명이 외진했습니다. '
      '성소병원에는 이정숙 환자를 정형외과, 김명희 환자를 안과, 정준호 환자, 이기동 환자는 치과로 진료했습니다. '
      '안동병원에는 기우대 환자는 소화기내과로 진료했습니다.';

  const depthSentence =
      '대성그린병원에서 환자가 외진을 갔어. '
      '성소병원의 안과에 김명희 환자, 정형외과에 이정숙 환자, 치과에 정준호 환자, 이기동 환자. '
      '안동병원의 소화기내과에 기우대 환자.';

  const escortSentence =
      '대성그린병원에서 환자가 외진을 갔어. '
      '성소병원의 안과에 김명희 환자, 정형외과에 이정숙 환자. '
      '안동병원에 외진환자를 인솔한 임성국 보호사가 있고 안동병원의 소화기내과에 기우대 환자.';

  const teamDinner =
      '어제 팀 회식에서 총 12명이 참석했습니다. 강남역 근처 식당에는 김철수, 이영희, 박민수가 왔고, '
      '홍대 지점에는 최지우, 한서연 두 명이 합류했습니다.';

  test('parseMemorySemanticFlow extracts org segments and departments', () {
    final frame = parseMemorySemanticFlow(clinicReport);
    expect(frame.primaryEvent, '오늘 외진현황');
    expect(frame.reportingOrganization, '대성그린병원');
    expect(frame.declaredTotalCount, 7);
    expect(frame.extractedPersonCount, 5);
    expect(frame.allPeople, containsAll(['이정숙', '김명희', '정준호', '이기동', '기우대']));
  });

  test('depth tree groups hospital → department → patients', () {
    final frame = parseMemorySemanticFlow(depthSentence);
    final tree = frame.depthTree;

    expect(tree.rootOrganization, '대성그린병원');
    expect(tree.branches.length, 2);

    final sungso = tree.branches.firstWhere((b) => b.organization == '성소병원');
    expect(sungso.isEscort, isFalse);
    expect(sungso.departments.length, 3);
    expect(
      sungso.departments.firstWhere((d) => d.department == '안과').patients.single.name,
      '김명희',
    );
    expect(
      sungso.departments.firstWhere((d) => d.department == '치과').patients.map((p) => p.name),
      containsAll(['정준호', '이기동']),
    );

    final andong = tree.branches.firstWhere((b) => b.organization == '안동병원');
    expect(andong.departments.single.department, '소화기내과');
    expect(andong.departments.single.patients.single.name, '기우대');
  });

  test('escort becomes depth-1 hub with dept and patient below', () {
    final frame = parseMemorySemanticFlow(escortSentence);
    final andongBranch = frame.depthTree.branches.firstWhere((b) => b.isEscort);

    expect(andongBranch.escortName, '임성국');
    expect(andongBranch.escortRole, '보호사');
    expect(andongBranch.organizationContext, '안동병원');
    expect(andongBranch.departments.single.department, '소화기내과');
    expect(andongBranch.departments.single.patients.single.name, '기우대');

    final rels = extractRelationsFromMemory(_memory(escortSentence));
    expect(rels.any((r) => r.subject == '임성국' && r.predicate == '인솔' && r.object == '기우대'), isTrue);
  });

  test('quantity mismatch is detected for declared vs extracted patients', () {
    final report = quantityReportFromMemory(_memory(clinicReport));
    expect(report, isNotNull);
    expect(report!.hasMismatch, isTrue);
    expect(report.declaredTotal, 7);
    expect(report.extractedCount, 5);
  });

  test('extractMemoryEntities merges flow people and orgs', () {
    final bundle = extractMemoryEntities(_memory(clinicReport));
    expect(bundle.eventTitle, '오늘 외진현황');
    expect(bundle.people, containsAll(['이정숙', '기우대']));
    expect(bundle.organizations, contains('성소병원'));
    expect(bundle.activities, contains('정형외과'));
  });

  test('extractRelationsFromMemory adds care hierarchy relations', () {
    final rels = extractRelationsFromMemory(_memory(depthSentence));
    expect(rels.any((r) => r.predicate == '진료과' && r.object.contains('안과')), isTrue);
    expect(rels.any((r) => r.subject == '김명희' && r.predicate == '진료' && r.object == '안과'), isTrue);
    expect(rels.any((r) => r.predicate == '출발' && r.object == '대성그린병원'), isTrue);
  });

  test('enrichMemoryGraphSemantics stores count tags', () {
    final enriched = enrichMemoryGraphSemantics(_memory(clinicReport));
    expect(enriched.entities.any((e) => e.startsWith('count:declared:')), isTrue);
    expect(enriched.entities.any((e) => e.startsWith('count:extracted:')), isTrue);
  });

  test('generic team dinner does not false-positive patient mismatch', () {
    final frame = parseMemorySemanticFlow(teamDinner);
    expect(frame.declaredTotalCount, 12);
    expect(frame.extractedPersonCount, lessThan(12));
    final report = quantityReportFromMemory(_memory(teamDinner));
    expect(report?.hasMismatch, isTrue);
    expect(report?.role, '참여');
  });
}
