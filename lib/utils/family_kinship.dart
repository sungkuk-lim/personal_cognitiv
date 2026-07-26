import 'organization_hierarchy.dart';

/// 가족 구성원·친족 관계를 [OrganizationHierarchy] 형태로 변환합니다.
///
/// 그래프 레이아웃·렌더는 기업 조직과 동일 경로를 재사용하고,
/// 파서만 가족 어휘(아버지/어머니/형제/부부 등)에 맞춥니다.
OrganizationHierarchy parseFamilyKinship(String rawText) {
  final text = rawText.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (text.isEmpty) return const OrganizationHierarchy();
  if (!_looksLikeFamilyText(text)) return const OrganizationHierarchy();

  final roles = <String, String>{};
  for (final m in _roleNamePattern.allMatches(text)) {
    final role = m.group(1)!;
    final name = _cleanPersonName(m.group(2)!);
    if (name.isEmpty) continue;
    roles.putIfAbsent(role, () => name);
  }
  if (roles.length < 3) return const OrganizationHierarchy();

  String? nameOf(String role) => roles[role];

  final father = nameOf('아버지') ?? nameOf('아빠');
  final mother = nameOf('어머니') ?? nameOf('엄마');
  final grandmother = nameOf('할머니');
  final grandfather = nameOf('할아버지');
  final uncle = nameOf('삼촌');
  final first = nameOf('첫째');
  final second = nameOf('둘째');
  final children = <String>[
    if (first != null) first,
    if (second != null) second,
    ..._extraChildren(roles, {father, mother, grandmother, grandfather, uncle}),
  ];

  final nodes = <OrganizationHierarchyNode>[];
  final edges = <OrganizationHierarchyEdge>[];
  final cross = <OrganizationCrossRelation>[];
  final seen = <String>{};

  void addPerson(String? label) {
    if (label == null || label.isEmpty || !seen.add(label)) return;
    nodes.add(
      OrganizationHierarchyNode(
        label: label,
        kind: OrganizationNodeKind.person,
      ),
    );
  }

  void link(String from, String to, [String label = '자녀']) {
    if (from.isEmpty || to.isEmpty || from == to) return;
    addPerson(from);
    addPerson(to);
    if (edges.any((e) => e.from == from && e.to == to)) return;
    edges.add(OrganizationHierarchyEdge(from: from, to: to, label: label));
  }

  void relate(String? a, String predicate, String? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty || a == b) return;
    addPerson(a);
    addPerson(b);
    if (cross.any(
      (r) => r.subject == a && r.predicate == predicate && r.object == b,
    )) {
      return;
    }
    cross.add(
      OrganizationCrossRelation(subject: a, predicate: predicate, object: b),
    );
  }

  final elderRoot = grandmother ?? grandfather;
  final root = elderRoot ?? father ?? '우리 가족';
  if (root == '우리 가족') {
    nodes.add(
      const OrganizationHierarchyNode(
        label: '우리 가족',
        kind: OrganizationNodeKind.organization,
      ),
    );
  } else {
    addPerson(root);
  }

  if (elderRoot != null) {
    if (father != null) link(elderRoot, father);
    if (uncle != null) link(elderRoot, uncle);
  } else if (root == '우리 가족') {
    if (father != null) link(root, father, '구성');
    if (mother != null) link(root, mother, '구성');
  }

  if (father != null) {
    for (final child in children) {
      link(father, child);
    }
  } else if (mother != null) {
    for (final child in children) {
      link(mother, child);
    }
  }

  if (text.contains('부부') || RegExp(r'아버지와\s*어머니').hasMatch(text)) {
    relate(father, '부부', mother);
  }
  if (text.contains('형제자매') || text.contains('형제') || text.contains('자매')) {
    if (children.length >= 2) {
      relate(children[0], '형제자매', children[1]);
    }
  }

  // 「김민수는 할머니를 자주 찾아뵙고」 / 「김민수는 박순자를 자주 찾아뵙고」
  for (final m in _visitPattern.allMatches(text)) {
    final subject = _cleanPersonName(m.group(1)!);
    final objectRaw = m.group(2)!;
    final object = roles[objectRaw] ?? _cleanPersonName(objectRaw);
    relate(subject, '문안', object);
  }
  // 「어머니와 삼촌은 명절 준비를 함께」 — 역할명으로도 매칭
  if (mother != null &&
      uncle != null &&
      text.contains('명절') &&
      (text.contains('함께') || text.contains('준비'))) {
    relate(mother, '명절 준비', uncle);
  }

  if (edges.length < 2) return const OrganizationHierarchy();
  return OrganizationHierarchy(
    root: root,
    nodes: nodes,
    hierarchyEdges: edges,
    crossRelations: cross,
  );
}

String _cleanPersonName(String raw) {
  var s = raw.trim();
  // 「삼촌 김태호로 이루어져」처럼 이름 뒤 부사격만 제거 (은/는은 이름에 포함될 수 있음)
  if (s.endsWith('으로') && s.length > 4) {
    s = s.substring(0, s.length - 2);
  } else if (s.endsWith('로') && s.length > 2) {
    final base = s.substring(0, s.length - 1);
    if (RegExp(r'^[가-힣]{2,4}$').hasMatch(base)) s = base;
  }
  if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(s)) return '';
  return s;
}

bool _looksLikeFamilyText(String text) {
  if (!text.contains('가족')) return false;
  const cues = [
    '아버지',
    '어머니',
    '아빠',
    '엄마',
    '할머니',
    '할아버지',
    '삼촌',
    '형제',
    '부부',
    '첫째',
    '둘째',
  ];
  var hits = 0;
  for (final c in cues) {
    if (text.contains(c)) hits++;
  }
  return hits >= 3;
}

List<String> _extraChildren(Map<String, String> roles, Set<String?> reserved) {
  final out = <String>[];
  for (final entry in roles.entries) {
    if (entry.key == '아들' || entry.key == '딸' || entry.key == '자녀') {
      if (!reserved.contains(entry.value)) out.add(entry.value);
    }
  }
  return out;
}

final RegExp _roleNamePattern = RegExp(
  r'(아버지|어머니|아빠|엄마|할머니|할아버지|삼촌|첫째|둘째|아들|딸|자녀)\s*'
  r'([가-힣]{2,4})',
);

final RegExp _visitPattern = RegExp(
  r'([가-힣]{2,4})(?:은|는)\s*(할머니|할아버지|[가-힣]{2,4})(?:을|를)\s*(?:자주\s*)?찾아',
);
