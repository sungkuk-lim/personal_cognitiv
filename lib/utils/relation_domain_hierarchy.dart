import 'organization_hierarchy.dart';

/// 연인·친구·반려·일상·공부·여행 등 선언형 관계 트리를
/// [OrganizationHierarchy]로 변환합니다. (기업/가족 파서 이후 fallback)
OrganizationHierarchy parseRelationDomainHierarchy(String rawText) {
  final text = rawText.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return const OrganizationHierarchy();

  final parsers = <OrganizationHierarchy Function(String)>[
    _parseCoupleDomain,
    _parseFriendCircles,
    _parsePetDomain,
    _parseLifeDomain,
    _parseStudyDomain,
    _parseTravelDomain,
  ];
  for (final parse in parsers) {
    final result = parse(text);
    if (result.hasHierarchy) return result;
  }
  return const OrganizationHierarchy();
}

// ─── shared builder ───────────────────────────────────────────────

class _TreeBuilder {
  String? root;
  final nodes = <String, OrganizationHierarchyNode>{};
  final edges = <OrganizationHierarchyEdge>[];
  final edgeKeys = <String>{};
  final cross = <OrganizationCrossRelation>[];
  final crossKeys = <String>{};

  void setRoot(String label, {OrganizationNodeKind kind = OrganizationNodeKind.organization}) {
    root = label;
    add(label, kind);
  }

  void add(String label, [OrganizationNodeKind? kind]) {
    final clean = label.trim();
    if (clean.isEmpty) return;
    nodes.putIfAbsent(
      clean,
      () => OrganizationHierarchyNode(label: clean, kind: kind ?? _guessKind(clean)),
    );
  }

  void link(
    String from,
    String to, {
    String label = '구성',
    OrganizationNodeKind? toKind,
  }) {
    final a = from.trim();
    final b = to.trim();
    if (a.isEmpty || b.isEmpty || a == b) return;
    add(a);
    add(b, toKind);
    final key = '$a\u0000$b';
    if (edgeKeys.add(key)) {
      edges.add(OrganizationHierarchyEdge(from: a, to: b, label: label));
    }
  }

  void relate(String subject, String predicate, String object) {
    final a = subject.trim();
    final b = object.trim();
    if (a.isEmpty || b.isEmpty || a == b) return;
    add(a, _guessKind(a));
    add(b, _guessKind(b));
    final key = '$a\u0000$predicate\u0000$b';
    if (crossKeys.add(key)) {
      cross.add(OrganizationCrossRelation(subject: a, predicate: predicate, object: b));
    }
  }

  OrganizationHierarchy build() {
    if (root == null || root!.isEmpty || edges.length < 2) {
      return const OrganizationHierarchy();
    }
    return OrganizationHierarchy(
      root: root,
      nodes: nodes.values.toList(growable: false),
      hierarchyEdges: List.unmodifiable(edges),
      crossRelations: List.unmodifiable(cross),
    );
  }
}

OrganizationNodeKind _guessKind(String label) {
  if (RegExp(r'프로젝트$').hasMatch(label)) return OrganizationNodeKind.project;
  // 장소: 지명·목적지·행정구역 접미사
  if (RegExp(r'(도$|시$|군$|구$|여행지|목적지|호텔|공항|바다|산|섬|일출봉|우도|성산)')
          .hasMatch(label) ||
      const {'제주도', '강릉', '일본', '대만', '오사카', '교토', '타이베이', '타이페이', '제주'}
          .contains(label)) {
    return OrganizationNodeKind.place;
  }
  // 음식·맛집
  if (RegExp(r'(맛집|음식|식사|카페|디저트|간식)').hasMatch(label)) {
    return OrganizationNodeKind.food;
  }
  // 활동
  if (RegExp(r'(여행|운동|영화|감상|독서|사진|산책|러닝|헬스|촬영|탐방|놀이)')
      .hasMatch(label)) {
    return OrganizationNodeKind.activity;
  }
  if (RegExp(r'^[가-힣]{2,4}$').hasMatch(label)) return OrganizationNodeKind.person;
  if (RegExp(r'^(코코|초코|나비|먼지|[A-Za-z][A-Za-z0-9_+#.-]{1,20})$').hasMatch(label)) {
    return OrganizationNodeKind.person;
  }
  return OrganizationNodeKind.organization;
}

List<String> _splitList(String raw, {bool personNames = false}) {
  return raw
      .split(RegExp(r'\s*(?:,|，|와|과|및|/)\s*'))
      .map((s) => s.trim().replaceFirst(RegExp(r'(?:입니다|이에요|예요|이다|임|요)?$'), ''))
      .map((s) {
        if (personNames) {
          // 이름 끝 은/는(이지은)은 유지. 「김태호로」만 제거.
          if (s.endsWith('으로') && s.length > 4) return s.substring(0, s.length - 2);
          if (s.endsWith('로') && s.length > 2) {
            final base = s.substring(0, s.length - 1);
            if (RegExp(r'^[가-힣]{2,4}$').hasMatch(base)) return base;
          }
          return s;
        }
        return s.replaceFirst(RegExp(r'(?:으로|로|은|는|이|가|을|를|도|만)$'), '');
      })
      .where((s) => s.length >= 1 && s.length <= 40)
      .toList();
}

// ─── 1. 연인 ──────────────────────────────────────────────────────

OrganizationHierarchy _parseCoupleDomain(String text) {
  if (!text.contains('연인') && !text.contains('커플')) {
    return const OrganizationHierarchy();
  }
  final me = RegExp(
    r'저는\s*([가-힣]{2,4})(?=(?:이고|이며|입니다|이에요|,|\s|$))',
  ).firstMatch(text)?.group(1);
  final partner = RegExp(
    r'연인은\s*([가-힣]{2,4})(?=(?:입니다|이고|이며|이에요|,|\s|$))',
  ).firstMatch(text)?.group(1);
  if (me == null || partner == null) return const OrganizationHierarchy();

  final b = _TreeBuilder()..setRoot('우리 관계');
  b.link('우리 관계', me, label: '나', toKind: OrganizationNodeKind.person);
  b.link('우리 관계', partner, label: '연인', toKind: OrganizationNodeKind.person);
  b.link('우리 관계', '함께하는 활동', label: '구성');
  b.relate(me, '연인', partner);

  final activities = <String>[];
  final actMatch = RegExp(
    r'(?:여행|운동|영화\s*감상|[가-힣]{2,12})(?:\s*,\s*(?:여행|운동|영화\s*감상|[가-힣]{2,12})){1,}',
  ).firstMatch(text);
  if (text.contains('여행') && text.contains('운동') && text.contains('영화')) {
    activities.addAll(['여행', '운동', '영화 감상']);
  } else if (actMatch != null) {
    activities.addAll(_splitList(actMatch.group(0)!.replaceAll('영화 감상', '영화감상')).map((s) {
      return s == '영화감상' ? '영화 감상' : s;
    }));
  }
  for (final a in activities) {
    b.link('함께하는 활동', a, label: '활동');
  }
  if (text.contains('제주')) {
    b.link('여행', '제주도', label: '계획');
    b.relate(me, '여행 계획', '제주도');
    b.relate(partner, '여행 계획', '제주도');
  }
  if (text.contains('주말') && text.contains('운동')) {
    b.relate(me, '주말 운동', partner);
  }
  if (text.contains('추천')) {
    b.relate(me, '영화 추천', partner);
  }
  if (text.contains('사진')) {
    b.relate(me, '사진 정리', partner);
  }
  return b.build();
}

// ─── 2. 친구 서클 ─────────────────────────────────────────────────

OrganizationHierarchy _parseFriendCircles(String text) {
  if (!text.contains('친구')) return const OrganizationHierarchy();
  final hasSchool = text.contains('학교 친구');
  final hasWork = text.contains('회사 친구');
  final hasClub = text.contains('동호회');
  if (!hasSchool && !hasWork && !hasClub) return const OrganizationHierarchy();

  final b = _TreeBuilder()..setRoot('나의 친구');
  void attachGroup(String group, String pattern) {
    final m = RegExp(pattern).firstMatch(text);
    if (m == null) return;
    b.link('나의 친구', group, label: '분류');
    for (final name in _splitList(m.group(1)!, personNames: true)) {
      if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(name)) continue;
      b.link(group, name, label: '친구', toKind: OrganizationNodeKind.person);
    }
  }

  attachGroup('학교 친구', r'학교\s*친구는\s*([^./]+?)(?=이고|이며|입니다)');
  attachGroup('회사 친구', r'회사\s*친구는\s*([^./]+?)(?=입니다|이고|이며)');
  attachGroup('동호회 친구', r'동호회에서는\s*([^./]+?)\s*(?:을|를)\s*만납');

  // 함께 활동 교차
  for (final m in RegExp(
    r'([가-힣]{2,4})(?:와|과)\s*([가-힣]{2,4})(?:은|는)\s*'
    r'([가-힣]{2,12}?)(?:을|를)?\s*(?:자주\s*)?(?:함께\s*)?(?:하고|갑니다|운영)',
  ).allMatches(text)) {
    b.relate(m.group(1)!, m.group(3)!, m.group(2)!);
  }
  if (text.contains('소개')) {
    final bridge = RegExp(r'([가-힣]{2,4})(?:은|는)\s*회사\s*친구').firstMatch(text)?.group(1);
    if (bridge != null) {
      b.relate(bridge, '소개', '학교 친구');
      b.relate(bridge, '소개', '회사 친구');
    }
  }
  return b.build();
}

// ─── 3. 반려 ──────────────────────────────────────────────────────

OrganizationHierarchy _parsePetDomain(String text) {
  if (!text.contains('반려') && !text.contains('보호자')) {
    return const OrganizationHierarchy();
  }
  final dogs = <String>[];
  final cats = <String>[];
  final dogM = RegExp(r'반려견은\s*([^.]+?)(?:입니다|이고)').firstMatch(text);
  final catM = RegExp(r'반려묘는\s*([^.]+?)(?:입니다|이고)').firstMatch(text);
  if (dogM != null) dogs.addAll(_splitList(dogM.group(1)!, personNames: true));
  if (catM != null) cats.addAll(_splitList(catM.group(1)!, personNames: true));
  if (dogs.isEmpty && cats.isEmpty) return const OrganizationHierarchy();

  final b = _TreeBuilder()..setRoot('나의 반려동물');
  if (dogs.isNotEmpty) {
    b.link('나의 반려동물', '반려견', label: '분류');
    for (final d in dogs) {
      b.link('반려견', d, label: '반려', toKind: OrganizationNodeKind.pet);
    }
  }
  if (cats.isNotEmpty) {
    b.link('나의 반려동물', '반려묘', label: '분류');
    for (final c in cats) {
      b.link('반려묘', c, label: '반려', toKind: OrganizationNodeKind.pet);
    }
  }
  if (dogs.length >= 2 && text.contains('산책')) {
    b.relate(dogs[0], '산책', dogs[1]);
  }
  if (cats.length >= 2 && (text.contains('놉') || text.contains('놀'))) {
    b.relate(cats[0], '놀이', cats[1]);
  }
  // 코코는 나비와도 친하게
  for (final m in RegExp(
    r'([가-힣]{2,4})(?:은|는)\s*([가-힣]{2,4})(?:와|과)도?\s*친하게',
  ).allMatches(text)) {
    b.relate(m.group(1)!, '친함', m.group(2)!);
  }
  for (final m in RegExp(
    r'([가-힣]{2,4})(?:은|는)\s*([가-힣]{2,4})(?:와|과)\s*간식',
  ).allMatches(text)) {
    b.relate(m.group(1)!, '간식', m.group(2)!);
  }
  if (text.contains('건강') || text.contains('병원')) {
    b.link('나의 반려동물', '건강·병원 일정', label: '관리');
  }
  return b.build();
}

// ─── 4. 일상 영역 ─────────────────────────────────────────────────

OrganizationHierarchy _parseLifeDomain(String text) {
  if (!text.contains('건강관리') || !text.contains('취미')) {
    return const OrganizationHierarchy();
  }
  final b = _TreeBuilder()..setRoot('나의 일상');
  b.link('나의 일상', '건강관리', label: '영역');
  b.link('나의 일상', '취미생활', label: '영역');
  b.link('나의 일상', '업무', label: '영역');
  b.link('나의 일상', '인간관계', label: '영역');

  for (final item in ['헬스', '러닝', '식단 관리']) {
    if (text.contains(item)) {
      b.link('건강관리', item, label: '구성');
    }
  }
  if (text.contains('독서')) b.link('취미생활', '독서', label: '구성');
  if (text.contains('사진')) b.link('취미생활', '사진 촬영', label: '구성');
  for (final m in RegExp(r'([A-Za-z]+)\s*프로젝트').allMatches(text)) {
    b.link(
      '업무',
      '${m.group(1)} 프로젝트',
      label: '구성',
      toKind: OrganizationNodeKind.project,
    );
  }
  if (text.contains('가족')) b.link('인간관계', '가족', label: '구성');
  if (text.contains('친구')) b.link('인간관계', '친구들', label: '구성');
  if (text.contains('러닝 모임')) b.link('인간관계', '러닝 모임', label: '구성');

  if (text.contains('독서') && text.contains('업무')) {
    b.relate('독서', '도움', '업무');
  }
  if (text.contains('사진') && text.contains('여행')) {
    b.relate('사진 촬영', '연결', '여행');
  }
  if (text.contains('러닝 모임')) {
    b.relate('러닝 모임', '함께 운동', '친구들');
  }
  return b.build();
}

// ─── 5. 공부 ──────────────────────────────────────────────────────

OrganizationHierarchy _parseStudyDomain(String text) {
  final hasStudy = text.contains('공부') || text.contains('자격증');
  final hasProg = text.contains('프로그래밍') || text.contains('Python') || text.contains('Flutter');
  if (!hasStudy || !hasProg) return const OrganizationHierarchy();

  final b = _TreeBuilder()..setRoot('공부 계획');
  if (text.contains('프로그래밍')) {
    b.link('공부 계획', '프로그래밍', label: '과목');
    if (text.contains('Python')) {
      b.link('프로그래밍', 'Python', label: '구성');
    }
    if (text.contains('Flutter')) {
      b.link('프로그래밍', 'Flutter', label: '구성');
    }
  }
  if (text.contains('영어')) {
    b.link('공부 계획', '영어', label: '과목');
    if (text.contains('회화')) b.link('영어', '회화', label: '구성');
    if (text.contains('문법')) b.link('영어', '문법', label: '구성');
  }
  if (text.contains('자격증') || text.contains('정보처리기사')) {
    b.link('공부 계획', '자격증', label: '과목');
    if (text.contains('정보처리기사')) {
      b.link('자격증', '정보처리기사', label: '준비');
    }
  }
  if (text.contains('Python') && text.contains('Flutter') && text.contains('도움')) {
    b.relate('Python', '도움', 'Flutter');
  }
  if (text.contains('영어') && text.contains('문서')) {
    b.relate('영어', '활용', '프로그래밍');
  }
  if (text.contains('자격증') && text.contains('연계')) {
    b.relate('자격증', '연계', '프로그래밍');
  }
  return b.build();
}

// ─── 6. 여행 ──────────────────────────────────────────────────────

OrganizationHierarchy _parseTravelDomain(String text) {
  if (!text.contains('여행') && !text.contains('제주') && !text.contains('해외여행')) {
    return const OrganizationHierarchy();
  }
  final hasDomestic = text.contains('국내여행') || text.contains('제주');
  final hasAbroad = text.contains('해외여행') || text.contains('일본') || text.contains('대만');
  if (!hasDomestic && !hasAbroad) return const OrganizationHierarchy();
  // Avoid stealing couple-only short texts
  if (text.contains('연인') && !text.contains('국내여행') && !text.contains('해외여행')) {
    return const OrganizationHierarchy();
  }

  final b = _TreeBuilder()..setRoot('올해 여행');
  if (hasDomestic) {
    b.link('올해 여행', '국내여행', label: '분류');
    if (text.contains('제주')) {
      b.link('국내여행', '제주도', label: '목적지');
      for (final spot in ['호텔', '성산일출봉', '우도', '렌터카']) {
        if (text.contains(spot) || (spot == '호텔' && text.contains('호텔'))) {
          b.link('제주도', spot, label: '계획');
        }
      }
    }
    if (text.contains('강릉')) {
      b.link('국내여행', '강릉', label: '목적지');
    }
  }
  if (hasAbroad) {
    b.link('올해 여행', '해외여행', label: '분류');
    if (text.contains('일본')) {
      b.link('해외여행', '일본', label: '목적지');
      if (text.contains('오사카')) b.link('일본', '오사카', label: '도시');
      if (text.contains('교토')) b.link('일본', '교토', label: '도시');
    }
    if (text.contains('대만')) {
      b.link('해외여행', '대만', label: '목적지');
      if (text.contains('타이베이') || text.contains('타이페이')) {
        b.link('대만', '타이베이', label: '도시');
      }
    }
  }
  if (text.contains('맛집')) {
    b.add('맛집 탐방');
    if (text.contains('제주')) b.relate('제주도', '계획', '맛집 탐방');
    if (text.contains('오사카')) b.relate('오사카', '계획', '맛집 탐방');
  }
  if (text.contains('사진')) {
    b.add('사진 촬영');
    if (text.contains('성산')) b.relate('성산일출봉', '계획', '사진 촬영');
    if (text.contains('교토')) b.relate('교토', '계획', '사진 촬영');
  }
  if (text.contains('강릉') && text.contains('친구')) {
    b.relate('강릉', '동행', '친구들');
  }
  return b.build();
}
