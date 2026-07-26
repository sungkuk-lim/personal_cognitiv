import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/memory_semantic_flow.dart';
import 'package:personal_cognitive/utils/organization_hierarchy.dart';
import 'package:personal_cognitive/utils/relation_domain_hierarchy.dart';

void main() {
  test('1 couple domain', () {
    const text =
        '저는 김민수이고 연인은 이지은입니다. 우리는 여행, 운동, 영화 감상을 함께 즐깁니다. '
        '제주도 여행을 함께 계획하고 있으며, 운동은 매주 주말 같이 하고 있습니다. '
        '서로 영화를 추천해 주고, 여행 사진도 함께 정리합니다.';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(h.root, '우리 관계');
    expect(h.nodes.map((n) => n.label), containsAll(['김민수', '이지은', '여행', '운동', '영화 감상']));
    expect(
      h.crossRelations.any((r) => r.predicate == '연인'),
      isTrue,
    );
  });

  test('nodes carry distinct kinds for color separation', () {
    const text =
        '저는 김민수이고 연인은 이지은입니다. 우리는 여행, 운동, 영화 감상을 함께 즐깁니다. '
        '제주도 여행을 함께 계획하고 있으며, 운동은 매주 주말 같이 하고 있습니다. '
        '서로 영화를 추천해 주고, 여행 사진도 함께 정리합니다.';
    final h = parseRelationDomainHierarchy(text);
    OrganizationNodeKind kindOf(String label) =>
        h.nodes.firstWhere((n) => n.label == label).kind;
    // 사람 / 장소 / 활동이 서로 다른 종류로 분류돼야 색상이 구분된다.
    expect(kindOf('김민수'), OrganizationNodeKind.person);
    expect(kindOf('이지은'), OrganizationNodeKind.person);
    expect(kindOf('제주도'), OrganizationNodeKind.place);
    expect(kindOf('여행'), OrganizationNodeKind.activity);
    final kinds = {kindOf('김민수'), kindOf('제주도'), kindOf('여행')};
    expect(kinds.length, greaterThanOrEqualTo(3));
  });

  test('pet names classified as pet kind', () {
    const text =
        '저는 반려동물을 키웁니다. 반려견은 코코와 초코입니다. 반려묘는 나비입니다. '
        '코코는 초코와 산책을 함께 합니다.';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(
      h.nodes.firstWhere((n) => n.label == '코코').kind,
      OrganizationNodeKind.pet,
    );
    expect(
      h.nodes.firstWhere((n) => n.label == '나비').kind,
      OrganizationNodeKind.pet,
    );
  });

  test('2 friend circles', () {
    const text =
        '저는 학교 친구, 회사 친구, 동호회 친구가 있습니다. 학교 친구는 김민수, 박준호, 이지은이고, '
        '회사 친구는 한유진과 오세진입니다. 동호회에서는 윤도현과 강서윤을 만납니다. '
        '김민수와 한유진은 축구를 함께 하고, 박준호와 오세진은 여행을 자주 갑니다. '
        '이지은과 강서윤은 독서모임을 운영하며, 윤도현은 회사 친구들과 학교 친구들을 서로 소개해 주었어';
    final h = parseRelationDomainHierarchy(text);
    expect(
      h.hasHierarchy,
      isTrue,
      reason: 'root=${h.root} edges=${h.hierarchyEdges.map((e) => '${e.from}->${e.to}').join(', ')}',
    );
    expect(h.root, '나의 친구');
    final labels = h.nodes.map((n) => n.label).toSet();
    expect(labels, containsAll(['학교 친구', '회사 친구', '동호회 친구', '김민수', '한유진', '윤도현']));
    expect(h.crossRelations.any((r) => r.predicate == '축구'), isTrue);
    expect(h.crossRelations.any((r) => r.predicate == '소개'), isTrue);
  });

  test('3 pets', () {
    const text =
        '난 코코, 초코, 나비, 먼지의 보호자야. 반려견은 코코와 초코, 반려묘는 나비와 먼지입니다. '
        '코코와 초코는 매일 함께 산책하고, 나비와 먼지는 함께 놉니다. '
        '코코는 나비와도 친하게 지내고, 초코는 먼지와 간식을 나눠 먹습니다. '
        '저는 모든 반려동물의 건강과 병원 일정을 관리하고 있어';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(h.root, '나의 반려동물');
    expect(h.nodes.map((n) => n.label), containsAll(['반려견', '반려묘', '코코', '초코', '나비', '먼지']));
    expect(h.crossRelations.any((r) => r.predicate == '산책'), isTrue);
  });

  test('4 life domains', () {
    const text =
        '나는 건강관리, 취미생활, 업무, 인간관계를 중심으로 생활해. '
        '건강관리는 헬스와 러닝, 식단 관리로 이루어져 있어. 취미는 독서와 사진 촬영이며, '
        '업무는 Alpha 프로젝트와 Beta 프로젝트를 진행하고 있고, 가족과 친구들을 자주 만나고, '
        '러닝 모임에서는 친구들과 함께 운동을 해. 독서는 업무에도 도움이 되고, 사진 촬영은 여행과도 연결되고.';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(h.root, '나의 일상');
    expect(
      h.nodes.map((n) => n.label),
      containsAll(['건강관리', '헬스', '독서', 'Alpha 프로젝트', '러닝 모임']),
    );
  });

  test('5 study plan', () {
    const text =
        '나는 프로그래밍, 영어, 자격증 공부를 하고 있어 '
        '프로그래밍은 Python과 Flutter를 공부하고 있으며, 영어는 회화와 문법을 함께 공부해 '
        '정보처리기사 자격증도 준비하고 있고 '
        'Python은 Flutter 개발에 도움이 되고, 영어는 프로그래밍 문서를 읽을 때 활용하고 '
        '자격증 공부도 프로그래밍과 연계해서 진행하고 있어';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(h.root, '공부 계획');
    expect(h.nodes.map((n) => n.label), containsAll(['프로그래밍', 'Python', 'Flutter', '영어', '정보처리기사']));
    expect(h.crossRelations.any((r) => r.subject == 'Python' && r.object == 'Flutter'), isTrue);
  });

  test('6 travel plan', () {
    const text =
        '올해는 국내여행으로 제주도와 강릉을, 해외여행으로 일본과 대만을 계획하고 있습니다. '
        '제주도에서는 호텔에 머물며 성산일출봉과 우도를 방문할 예정입니다. '
        '일본에서는 오사카와 교토를 여행하고, 대만에서는 타이베이를 방문하려고 합니다. '
        '제주도와 오사카에서는 맛집 탐방을 계획하고 있고, 성산일출봉과 교토에서는 사진 촬영을 많이 할 예정입니다. '
        '강릉은 친구들과 함께 가고, 제주도에서는 렌터카도 예약했습니다.';
    final h = parseRelationDomainHierarchy(text);
    expect(h.hasHierarchy, isTrue);
    expect(h.root, '올해 여행');
    expect(
      h.nodes.map((n) => n.label),
      containsAll(['국내여행', '제주도', '강릉', '일본', '오사카', '대만', '타이베이', '성산일출봉']),
    );
  });

  test('semantic flow picks domain when not org/family', () {
    final frame = parseMemorySemanticFlow(
      '나는 프로그래밍, 영어, 자격증 공부를 하고 있어 프로그래밍은 Python과 Flutter를 공부하고 있으며',
    );
    expect(frame.organizationHierarchy.root, '공부 계획');
  });
}
