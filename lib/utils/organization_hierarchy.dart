import 'dart:convert';

/// 기업·단체의 다단계 계층과 계층 밖 교차 관계를 표현합니다.
///
/// 의료 도메인 전용 파서와 분리하여, 일반 기억에서 조직 어휘가 우연히
/// 등장했을 때 기존 그래프 의미를 바꾸지 않도록 합니다.
enum OrganizationNodeKind {
  organization,
  person,
  project,
  place,
  event,
  activity,
  food,
  pet,
  item,
}

class OrganizationHierarchyNode {
  const OrganizationHierarchyNode({required this.label, required this.kind});

  final String label;
  final OrganizationNodeKind kind;
}

class OrganizationHierarchyEdge {
  const OrganizationHierarchyEdge({
    required this.from,
    required this.to,
    required this.label,
  });

  final String from;
  final String to;
  final String label;
}

class OrganizationCrossRelation {
  const OrganizationCrossRelation({
    required this.subject,
    required this.predicate,
    required this.object,
  });

  final String subject;
  final String predicate;
  final String object;
}

class OrganizationHierarchy {
  const OrganizationHierarchy({
    this.root,
    this.nodes = const [],
    this.hierarchyEdges = const [],
    this.crossRelations = const [],
  });

  final String? root;
  final List<OrganizationHierarchyNode> nodes;
  final List<OrganizationHierarchyEdge> hierarchyEdges;
  final List<OrganizationCrossRelation> crossRelations;

  bool get hasHierarchy =>
      root != null && root!.isNotEmpty && hierarchyEdges.length >= 2;

  int depthOf(String label) {
    final rootLabel = root;
    if (rootLabel == null || rootLabel.isEmpty) return 0;
    if (label == rootLabel) return 0;
    final depths = <String, int>{rootLabel: 0};
    var changed = true;
    while (changed) {
      changed = false;
      for (final edge in hierarchyEdges) {
        final parentDepth = depths[edge.from];
        if (parentDepth == null || depths.containsKey(edge.to)) continue;
        depths[edge.to] = parentDepth + 1;
        changed = true;
      }
    }
    return depths[label] ?? 1;
  }

  Map<String, dynamic> toJsonMap() => {
        'root': root,
        'nodes': [
          for (final n in nodes) {'label': n.label, 'kind': n.kind.name},
        ],
        'hierarchy_edges': [
          for (final e in hierarchyEdges)
            {'from': e.from, 'to': e.to, 'label': e.label},
        ],
        'cross_relations': [
          for (final r in crossRelations)
            {
              'subject': r.subject,
              'predicate': r.predicate,
              'object': r.object,
            },
        ],
      };

  String? toEntityTag() {
    if (!hasHierarchy) return null;
    return '$kHierarchyJsonPrefix${jsonEncode(toJsonMap())}';
  }

  static OrganizationHierarchy? fromEntityTags(Iterable<String> entities) {
    for (final tag in entities) {
      if (!tag.startsWith(kHierarchyJsonPrefix)) continue;
      final raw = tag.substring(kHierarchyJsonPrefix.length);
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          final parsed = fromJsonMap(map);
          if (parsed.hasHierarchy) return parsed;
        } else if (map is Map) {
          final parsed = fromJsonMap(Map<String, dynamic>.from(map));
          if (parsed.hasHierarchy) return parsed;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static OrganizationHierarchy fromJsonMap(Map<String, dynamic> map) {
    OrganizationNodeKind kindOf(Object? raw) {
      final name = raw?.toString() ?? 'organization';
      return OrganizationNodeKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => OrganizationNodeKind.organization,
      );
    }

    final nodes = <OrganizationHierarchyNode>[];
    final seen = <String>{};
    void addNode(String label, OrganizationNodeKind kind) {
      final clean = label.trim();
      if (clean.isEmpty || !seen.add(clean)) return;
      nodes.add(OrganizationHierarchyNode(label: clean, kind: kind));
    }

    final root = (map['root'] as String?)?.trim();
    if (root != null && root.isNotEmpty) {
      addNode(root, OrganizationNodeKind.organization);
    }

    for (final raw in (map['nodes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      addNode((m['label'] as String? ?? '').trim(), kindOf(m['kind']));
    }

    final edges = <OrganizationHierarchyEdge>[];
    final edgeKeys = <String>{};
    for (final raw in (map['hierarchy_edges'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final from = (m['from'] as String? ?? '').trim();
      final to = (m['to'] as String? ?? '').trim();
      final label = (m['label'] as String? ?? '구성').trim();
      if (from.isEmpty || to.isEmpty || from == to) continue;
      addNode(from, OrganizationNodeKind.organization);
      addNode(to, OrganizationNodeKind.organization);
      if (edgeKeys.add('$from\u0000$to')) {
        edges.add(OrganizationHierarchyEdge(from: from, to: to, label: label.isEmpty ? '구성' : label));
      }
    }

    final cross = <OrganizationCrossRelation>[];
    final crossKeys = <String>{};
    for (final raw in (map['cross_relations'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final subject = (m['subject'] as String? ?? '').trim();
      final predicate = (m['predicate'] as String? ?? '').trim();
      final object = (m['object'] as String? ?? '').trim();
      if (subject.isEmpty || predicate.isEmpty || object.isEmpty || subject == object) {
        continue;
      }
      addNode(subject, OrganizationNodeKind.person);
      addNode(object, OrganizationNodeKind.person);
      if (crossKeys.add('$subject\u0000$predicate\u0000$object')) {
        cross.add(
          OrganizationCrossRelation(
            subject: subject,
            predicate: predicate,
            object: object,
          ),
        );
      }
    }

    return OrganizationHierarchy(
      root: root,
      nodes: nodes,
      hierarchyEdges: edges,
      crossRelations: cross,
    );
  }
}

/// AI/규칙으로 만든 계층 트리를 Memory.entities에 넣는 접두사.
const String kHierarchyJsonPrefix = 'hier_json:';

const _organizationSuffixes = [
  '그룹',
  '부문',
  '본부',
  '사업부',
  '실',
  '팀',
  '파트',
  '지사',
  '센터',
  '조직',
  '부서',
];

final RegExp _organizationLabelPattern = RegExp(
  '^[가-힣A-Za-z0-9·&_-]{1,30}(?:${_organizationSuffixes.join('|')})\$',
);

final RegExp _personLabelPattern = RegExp(r'^[가-힣]{2,4}$');
final RegExp _projectLabelPattern = RegExp(r'^[가-힣A-Za-z0-9_-]{1,30}\s*프로젝트$');

/// "A에는 B와 C가 있습니다" 형태의 선언형 한국어 조직 설명을 파싱합니다.
///
/// 지원 계층 어휘는 그룹/부문/본부/사업부/실/팀/파트/지사/센터/부서이며,
/// 자식에 조직 접미사가 없고 2~4자의 한글 이름이면 사람으로 취급합니다.
OrganizationHierarchy parseOrganizationHierarchy(String rawText) {
  final text = rawText
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return const OrganizationHierarchy();

  final nodes = <String, OrganizationHierarchyNode>{};
  final hierarchyEdges = <OrganizationHierarchyEdge>[];
  final edgeKeys = <String>{};
  final crossRelations = <OrganizationCrossRelation>[];
  final relationKeys = <String>{};

  OrganizationNodeKind kindFor(String label) {
    if (_projectLabelPattern.hasMatch(label)) {
      return OrganizationNodeKind.project;
    }
    if (_organizationLabelPattern.hasMatch(label)) {
      return OrganizationNodeKind.organization;
    }
    return OrganizationNodeKind.person;
  }

  void addNode(String raw, [OrganizationNodeKind? kind]) {
    final label = _cleanLabel(raw);
    if (label.isEmpty) return;
    nodes.putIfAbsent(
      label,
      () =>
          OrganizationHierarchyNode(label: label, kind: kind ?? kindFor(label)),
    );
  }

  void addHierarchy(String rawParent, String rawChild) {
    final parent = _cleanLabel(rawParent);
    final child = _cleanLabel(rawChild);
    if (parent.isEmpty || child.isEmpty || parent == child) return;
    if (!_organizationLabelPattern.hasMatch(parent)) return;
    if (!_organizationLabelPattern.hasMatch(child) &&
        !_personLabelPattern.hasMatch(child)) {
      return;
    }
    addNode(parent, OrganizationNodeKind.organization);
    addNode(
      child,
      _organizationLabelPattern.hasMatch(child)
          ? OrganizationNodeKind.organization
          : OrganizationNodeKind.person,
    );
    final key = '$parent\u0000$child';
    if (edgeKeys.add(key)) {
      hierarchyEdges.add(
        OrganizationHierarchyEdge(from: parent, to: child, label: '소속'),
      );
    }
  }

  void addRelation(String rawSubject, String predicate, String rawObject) {
    final subject = _cleanLabel(rawSubject);
    final object = _cleanLabel(rawObject);
    if (subject.isEmpty || object.isEmpty || subject == object) return;
    addNode(subject);
    addNode(object);
    final key = '$subject\u0000$predicate\u0000$object';
    if (relationKeys.add(key)) {
      crossRelations.add(
        OrganizationCrossRelation(
          subject: subject,
          predicate: predicate,
          object: object,
        ),
      );
    }
  }

  final quotedRoot = RegExp(
    r'''최상위\s*(?:조직|기관|그룹)?은?\s*['"]([^'"]+)['"]''',
  ).firstMatch(text);
  final plainRoot = RegExp(
    r'최상위\s*(?:조직|기관|그룹)?은?\s*([가-힣A-Za-z0-9·&_-]+(?:그룹|조직))',
  ).firstMatch(text);
  var root = _cleanLabel(quotedRoot?.group(1) ?? plainRoot?.group(1) ?? '');
  if (root.isNotEmpty) addNode(root, OrganizationNodeKind.organization);

  final clausePattern = RegExp(
    r'([가-힣A-Za-z0-9·&_-]{1,30}(?:그룹|부문|본부|사업부|실|팀|파트|지사|센터|조직|부서))'
    r'\s*(?:아래)?에는\s+(.+?)(?=(?:이|가)\s*(?:있|소속)|'
    r'[,，]\s*[가-힣A-Za-z0-9·&_-]{1,30}(?:그룹|부문|본부|사업부|실|팀|파트|지사|센터|조직|부서)\s*(?:아래)?에는|[.;])',
  );
  for (final match in clausePattern.allMatches(text)) {
    final parent = _cleanLabel(match.group(1)!);
    final children = _splitKoreanList(match.group(2)!);
    for (final child in children) {
      addHierarchy(parent, child);
    }
  }

  if (root.isEmpty && hierarchyEdges.isNotEmpty) {
    final children = hierarchyEdges.map((e) => e.to).toSet();
    root = hierarchyEdges
        .map((e) => e.from)
        .firstWhere(
          (label) => !children.contains(label),
          orElse: () => hierarchyEdges.first.from,
        );
  }

  // 두 사람이 같은 프로젝트를 함께 진행.
  for (final match in RegExp(
    r'([가-힣]{2,4})(?:와|과)\s*([가-힣]{2,4})(?:은|는)\s*([가-힣A-Za-z0-9_-]+)\s*프로젝트를\s*함께\s*진행',
  ).allMatches(text)) {
    final project = '${match.group(3)!} 프로젝트';
    addRelation(match.group(1)!, '참여', project);
    addRelation(match.group(2)!, '참여', project);
  }

  // 프로젝트 간 연계.
  for (final match in RegExp(
    r'([가-힣A-Za-z0-9_-]+)\s*프로젝트는\s*([가-힣A-Za-z0-9_-]+)\s*프로젝트와\s*연계',
  ).allMatches(text)) {
    addRelation('${match.group(1)!} 프로젝트', '연계', '${match.group(2)!} 프로젝트');
  }

  // 한 사람이 여러 조직을 지원.
  for (final match in RegExp(
    r'(?:^|[.]\s*)(?:[-•]\s*)?([가-힣]{2,4})(?:은|는)\s*([^.]+?)를\s*(?:모두\s*)?지원',
  ).allMatches(text)) {
    for (final target in _splitKoreanList(match.group(2)!)) {
      if (_organizationLabelPattern.hasMatch(target)) {
        addRelation(match.group(1)!, '지원', target);
      }
    }
  }

  // 조직 사이를 연결하는 담당자.
  for (final rawSentence in text.split('.')) {
    final sentence = rawSentence.trim().replaceFirst(RegExp(r'^[-•]\s*'), '');
    if (!sentence.contains('연결하는 담당자')) continue;
    final subject = nodes.values
        .where((n) => n.kind == OrganizationNodeKind.person)
        .map((n) => n.label)
        .firstWhere(
          (name) =>
              sentence.startsWith('$name은 ') || sentence.startsWith('$name는 '),
          orElse: () => '',
        );
    if (subject.isEmpty) continue;
    final targets =
        RegExp(r'[가-힣A-Za-z0-9·&_-]{1,30}(?:그룹|부문|본부|사업부|실|팀|파트|지사|센터|조직|부서)')
            .allMatches(sentence)
            .map((m) => m.group(0)!)
            .where((label) => label != subject)
            .toSet();
    for (final target in targets) {
      addRelation(subject, '연결 담당', target);
    }
  }

  // 멘토 관계.
  for (final match in RegExp(
    r'(?:^|[.]\s*)(?:[-•]\s*)?([가-힣]{2,4})(?:은|는)\s*([가-힣]{2,4})의\s*멘토',
  ).allMatches(text)) {
    addRelation(match.group(1)!, '멘토', match.group(2)!);
  }

  // 협업 + 같은 문장에 이어지는 공동 연구.
  for (final match in RegExp(
    r'(?:^|[.]\s*)(?:[-•]\s*)?([가-힣]{2,4})(?:은|는)\s*([가-힣]{2,4})(?:와|과)\s*협업',
  ).allMatches(text)) {
    addRelation(match.group(1)!, '협업', match.group(2)!);
    final sentenceEnd = text.indexOf('.', match.end);
    final tail = text.substring(
      match.end,
      sentenceEnd < 0 ? text.length : sentenceEnd,
    );
    for (final research in RegExp(
      r'([가-힣]{2,4})과도?\s*공동\s*연구',
    ).allMatches(tail)) {
      addRelation(match.group(1)!, '공동 연구', research.group(1)!);
    }
  }

  return OrganizationHierarchy(
    root: root.isEmpty ? null : root,
    nodes: nodes.values.toList(growable: false),
    hierarchyEdges: hierarchyEdges,
    crossRelations: crossRelations,
  );
}

/// 본문에 없는 라벨을 제거해 환각·잘림을 막습니다.
OrganizationHierarchy sanitizeHierarchyAgainstSource(
  OrganizationHierarchy hierarchy,
  String sourceText,
) {
  final source = sourceText.replaceAll(RegExp(r'\s+'), ' ');
  bool allowed(String label) {
    final t = label.trim();
    if (t.isEmpty || t.length > 40) return false;
    if (source.contains(t)) return true;
    if (t == hierarchy.root && t.length <= 12) return true;
    return false;
  }

  OrganizationNodeKind kindOf(String label) {
    return hierarchy.nodes
        .firstWhere(
          (n) => n.label == label,
          orElse: () => OrganizationHierarchyNode(
            label: label,
            kind: OrganizationNodeKind.organization,
          ),
        )
        .kind;
  }

  final edges = <OrganizationHierarchyEdge>[];
  final edgeKeys = <String>{};
  for (final e in hierarchy.hierarchyEdges) {
    if (!allowed(e.from) || !allowed(e.to) || e.from == e.to) continue;
    if (edgeKeys.add('${e.from}\u0000${e.to}')) edges.add(e);
  }

  final cross = <OrganizationCrossRelation>[];
  final crossKeys = <String>{};
  for (final r in hierarchy.crossRelations) {
    if (!allowed(r.subject) || !allowed(r.object) || r.subject == r.object) {
      continue;
    }
    final predicate = r.predicate.trim();
    if (predicate.isEmpty || predicate.length > 16) continue;
    if (crossKeys.add('${r.subject}\u0000$predicate\u0000${r.object}')) {
      cross.add(r);
    }
  }

  final labels = <String>{
    if (hierarchy.root != null && allowed(hierarchy.root!)) hierarchy.root!,
    for (final e in edges) ...[e.from, e.to],
    for (final r in cross) ...[r.subject, r.object],
  };

  final root = hierarchy.root;
  if (root == null || !labels.contains(root) || edges.length < 2) {
    return const OrganizationHierarchy();
  }

  return OrganizationHierarchy(
    root: root,
    nodes: [
      for (final label in labels)
        OrganizationHierarchyNode(label: label, kind: kindOf(label)),
    ],
    hierarchyEdges: edges,
    crossRelations: cross,
  );
}

List<String> _splitKoreanList(String raw) {
  return raw
      .replaceAll(RegExp(r'\s*(?:,|，|、)\s*'), '와')
      .split(RegExp(r'\s*(?:와|과)\s*'))
      .map(_cleanListItem)
      .where((v) => v.isNotEmpty)
      .toList();
}

String _cleanListItem(String raw) {
  var value = _cleanLabel(raw);
  if (value.endsWith('이') || value.endsWith('가')) {
    final withoutParticle = value.substring(0, value.length - 1);
    if (_personLabelPattern.hasMatch(withoutParticle) ||
        _organizationLabelPattern.hasMatch(withoutParticle)) {
      value = withoutParticle;
    }
  }
  return value;
}

String _cleanLabel(String raw) {
  var value = raw.trim();
  value = value.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  return value.trim();
}
