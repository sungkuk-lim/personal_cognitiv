import 'family_kinship.dart';
import 'korean_person_names.dart';
import 'medical_entity_lexicon.dart';
import 'memory_graph_semantics.dart';
import 'memory_semantic_extract.dart';
import 'organization_hierarchy.dart';
import 'relation_domain_hierarchy.dart';

/// 진료과 단위 서브-허브 (depth 2).
class DepartmentCareHub {
  const DepartmentCareHub({
    required this.department,
    this.organizationContext,
    this.patients = const [],
  });

  final String department;
  final String? organizationContext;
  final List<PersonCareRecord> patients;

  String get displayTitle {
    if (organizationContext != null &&
        organizationContext!.isNotEmpty &&
        !department.contains(organizationContext!)) {
      return '$organizationContext $department';
    }
    return department;
  }
}

/// 병원 또는 인솔자(보호사 등) 단위 서브-허브 (depth 1).
class CareBranchHub {
  const CareBranchHub.organization({
    required this.organization,
    this.departments = const [],
  }) : escortName = null,
       escortRole = null,
       organizationContext = null;

  const CareBranchHub.escort({
    required this.escortName,
    required this.escortRole,
    this.organizationContext,
    this.departments = const [],
  }) : organization = null;

  final String? organization;
  final String? escortName;
  final String? escortRole;
  final String? organizationContext;
  final List<DepartmentCareHub> departments;

  bool get isEscort => escortName != null && escortName!.isNotEmpty;

  String get branchTitle =>
      isEscort ? '$escortName $escortRole' : (organization ?? '');

  String get branchSubtitle =>
      isEscort ? (organizationContext ?? escortRole ?? '') : '기관';
}

/// 다단계 허브 트리 — 루트(출발기관) → 서브(병원/보호사) → 진료과 → 환자.
class CareDepthTree {
  const CareDepthTree({
    this.rootOrganization,
    this.primaryEvent,
    this.branches = const [],
  });

  final String? rootOrganization;
  final String? primaryEvent;
  final List<CareBranchHub> branches;

  bool get hasDepth => branches.any((b) => b.departments.isNotEmpty);

  int get patientCount => branches.fold(
    0,
    (n, b) => n + b.departments.fold(0, (d, h) => d + h.patients.length),
  );
}

/// 기관(병원 등) 단위 구간 — 환자·진료과 묶음.
class OrgCareSegment {
  const OrgCareSegment({required this.organization, this.people = const []});

  final String organization;
  final List<PersonCareRecord> people;
}

/// 역할 기반 인물 기록 (환자·간호사·보호자 등).
class PersonCareRecord {
  const PersonCareRecord({
    required this.name,
    this.department,
    this.role = '환자',
    this.companionName,
    this.companionRole,
  });

  final String name;
  final String? department;
  final String role;

  /// 환자 아래 연결할 인솔자·담당자 (보호사·간호사·나 등).
  final String? companionName;
  final String? companionRole;
}

/// 문장 흐름에서 읽어낸 의미 프레임 (특정 문장 하드코딩 없음).
class MemorySemanticFrame {
  const MemorySemanticFrame({
    this.primaryEvent,
    this.reportingOrganization,
    this.declaredTotalCount,
    this.countRole = '참여',
    this.orgSegments = const [],
    this.depthTree = const CareDepthTree(),
    this.organizationHierarchy = const OrganizationHierarchy(),
    this.structuredRelations = const [],
    this.metaTags = const [],
  });

  final String? primaryEvent;
  final String? reportingOrganization;
  final int? declaredTotalCount;
  final String? countRole;
  final List<OrgCareSegment> orgSegments;
  final CareDepthTree depthTree;
  final OrganizationHierarchy organizationHierarchy;
  final List<MemoryRelation> structuredRelations;
  final List<String> metaTags;

  int get extractedPersonCount => depthTree.hasDepth
      ? depthTree.patientCount
      : organizationHierarchy.hasHierarchy
      ? organizationHierarchy.nodes
            .where((n) => n.kind == OrganizationNodeKind.person)
            .length
      : orgSegments.fold<int>(0, (a, s) => a + s.people.length);

  List<String> get allPeople {
    if (organizationHierarchy.hasHierarchy) {
      return organizationHierarchy.nodes
          .where((n) => n.kind == OrganizationNodeKind.person)
          .map((n) => n.label)
          .toList();
    }
    if (depthTree.hasDepth) {
      return depthTree.branches
          .expand(
            (b) => b.departments.expand((d) => d.patients.map((p) => p.name)),
          )
          .toList();
    }
    return orgSegments.expand((s) => s.people.map((p) => p.name)).toList();
  }

  List<String> get allOrganizations => [
    if (organizationHierarchy.hasHierarchy)
      ...organizationHierarchy.nodes
          .where((n) => n.kind == OrganizationNodeKind.organization)
          .map((n) => n.label),
    if (reportingOrganization != null && reportingOrganization!.isNotEmpty)
      reportingOrganization!,
    ...orgSegments.map((s) => s.organization),
  ].toSet().toList();

  List<String> get allDepartments {
    if (depthTree.hasDepth) {
      return depthTree.branches
          .expand((b) => b.departments.map((d) => d.department))
          .toSet()
          .toList();
    }
    return orgSegments
        .expand((s) => s.people.map((p) => p.department).whereType<String>())
        .toSet()
        .toList();
  }
}

const kSemanticMedicalEventKeywords = {
  '외진',
  '내원',
  '입원',
  '퇴원',
  '진료',
  '검진',
  '수술',
  '응급',
};

const kDepartmentSuffixPattern =
    r'(?:과|내과|외과|치과|안과|정형외과|소화기내과|신경과|피부과|산부인과|소아과|이비인후과|비뇨기과|영상의학과|재활의학과)';

final RegExp _orgAnchorPattern = RegExp(
  r'([가-힣A-Za-z0-9]{2,24}(?:병원|의원|클리닉|센터))(?:에는|의|에|에서|으로는|로는)?',
);

final RegExp _declaredTotalPattern = RegExp(r'총\s*(\d+)\s*명');
final RegExp _totalWithActionPattern = RegExp(
  r'(\d+)\s*명(?:이|이\s*)?(?:왔|나왔|참석|방문|외진|진료|기록)',
);

final RegExp _patientRolePattern = RegExp(r'([가-힣]{2,4})\s*(환자|간호사|보호자|의사|담당)');

final RegExp _departmentPattern = RegExp(
  '([가-힣A-Za-z0-9]{2,12}$kDepartmentSuffixPattern)',
);

bool _isCarePersonName(String raw) {
  final name = normalizeKoreanPersonName(
    stripTrailingKoreanParticles(raw.trim()),
  );
  if (name == '나') return true;
  if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(name)) return false;
  if (isMedicalDepartmentLabel(name) ||
      isMedicalFacilityLabel(name) ||
      isMedicalRoleToken(name)) {
    return false;
  }
  return true;
}

/// 본문 전체를 흐름 단위로 파싱합니다.
///
/// [entityTags]에 AI가 저장한 `hier_json:` 이 있으면 규칙 실패 시 사용합니다.
MemorySemanticFrame parseMemorySemanticFlow(
  String rawText, {
  String localeCode = 'ko',
  List<String> entityTags = const [],
}) {
  final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return const MemorySemanticFrame();
  }

  final event = _detectPrimaryEvent(text);
  final reportingOrg = _detectReportingOrganization(text);
  final (declaredTotal, countRole) = _detectDeclaredTotal(text);
  final orgSegments = _parseOrgCareSegments(text);
  var organizationHierarchy = parseOrganizationHierarchy(text);
  if (!organizationHierarchy.hasHierarchy) {
    final family = parseFamilyKinship(text);
    if (family.hasHierarchy) {
      organizationHierarchy = family;
    } else {
      final domain = parseRelationDomainHierarchy(text);
      if (domain.hasHierarchy) {
        organizationHierarchy = domain;
      } else {
        final stored = OrganizationHierarchy.fromEntityTags(entityTags);
        if (stored != null && stored.hasHierarchy) {
          organizationHierarchy = stored;
        }
      }
    }
  }
  final depthTree = _buildCareDepthTree(
    text: text,
    reportingOrg: reportingOrg,
    event: event,
    orgSegments: orgSegments,
  );
  final relations = _buildStructuredRelations(
    text: text,
    event: event,
    reportingOrg: reportingOrg,
    depthTree: depthTree,
    orgSegments: orgSegments,
    declaredTotal: declaredTotal,
    countRole: countRole,
    localeCode: localeCode,
    organizationHierarchy: organizationHierarchy,
  );
  final meta = <String>[
    if (event != null) 'flow:event:$event',
    if (reportingOrg != null) 'flow:origin:$reportingOrg',
    if (declaredTotal != null) 'flow:count:declared:$declaredTotal',
    'flow:count:extracted:${depthTree.patientCount}',
  ];

  return MemorySemanticFrame(
    primaryEvent: event,
    reportingOrganization: reportingOrg,
    declaredTotalCount: declaredTotal,
    countRole: countRole,
    orgSegments: orgSegments,
    depthTree: depthTree,
    organizationHierarchy: organizationHierarchy,
    structuredRelations: relations,
    metaTags: meta,
  );
}

String? _detectPrimaryEvent(String text) {
  final status = RegExp(
    r'(오늘\s*)?[가-힣A-Za-z0-9\s]{0,12}외진\s*현황',
  ).firstMatch(text);
  if (status != null) {
    var raw = status.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    raw = raw
        .replaceAll(RegExp(r'[가-힣A-Za-z0-9]+(?:병원|의원|클리닉|센터)\s*'), '')
        .trim();
    if (!raw.startsWith('오늘')) raw = '오늘 $raw';
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  for (final keyword in kSemanticMedicalEventKeywords) {
    if (text.contains(keyword)) return keyword;
  }
  for (final keyword in kSemanticEventLexicon) {
    if (text.contains(keyword)) return keyword;
  }
  return null;
}

String? _detectReportingOrganization(String text) {
  final fromOrigin = RegExp(
    r'([가-힣A-Za-z0-9]{2,24}(?:병원|의원|클리닉|센터))에서\s*(?:환자가?\s*)?(?:외진|내원|진료)',
  ).firstMatch(text);
  if (fromOrigin != null) return _cleanOrg(fromOrigin.group(1)!);

  final reportCtx = RegExp(
    r'([가-힣A-Za-z0-9]{2,24}(?:병원|의원|클리닉|센터))\s*(?:외진현황|현황|보고|기록)',
  ).firstMatch(text);
  if (reportCtx != null) return _cleanOrg(reportCtx.group(1)!);

  final first = _orgAnchorPattern.firstMatch(text);
  return first != null ? _cleanOrg(first.group(1)!) : null;
}

(int? total, String role) _detectDeclaredTotal(String text) {
  final m1 = _declaredTotalPattern.firstMatch(text);
  if (m1 != null) {
    final role = text.contains('환자') ? '환자' : '참여';
    return (int.tryParse(m1.group(1)!), role);
  }
  final m2 = _totalWithActionPattern.firstMatch(text);
  if (m2 != null) {
    final role = text.contains('환자') ? '환자' : '참여';
    return (int.tryParse(m2.group(1)!), role);
  }
  return (null, '참여');
}

CareDepthTree _buildCareDepthTree({
  required String text,
  required String? reportingOrg,
  required String? event,
  required List<OrgCareSegment> orgSegments,
}) {
  final escortsByOrg = _parseEscortsByOrganization(text);
  var deptFirst = _parseDeptFirstBlocks(text);
  deptFirst = _mergeDeptMaps(deptFirst, _parseHospitalPatientDeptLists(text));
  deptFirst = _mergeDeptMaps(deptFirst, _parseInlinePatientOrgDept(text));
  final companions = _parsePatientCompanionMap(text);
  final extraPatients = _parseAdditionalPatientNames(text);
  final branches = <CareBranchHub>[];

  if (deptFirst.isNotEmpty) {
    for (final entry in deptFirst.entries) {
      final org = entry.key;
      final escort = escortsByOrg[org];
      final depts = _applyCompanionsToDepartments(entry.value, companions);
      if (escort != null) {
        branches.add(
          CareBranchHub.escort(
            escortName: escort.$1,
            escortRole: escort.$2,
            organizationContext: org,
            departments: depts,
          ),
        );
      } else {
        branches.add(
          CareBranchHub.organization(organization: org, departments: depts),
        );
      }
    }
  } else {
    for (final seg in orgSegments) {
      if (seg.organization.isEmpty || seg.people.isEmpty) continue;
      final escort = escortsByOrg[seg.organization];
      final depts = _applyCompanionsToDepartments(
        _groupPeopleByDepartment(seg.organization, seg.people),
        companions,
      );
      if (escort != null) {
        branches.add(
          CareBranchHub.escort(
            escortName: escort.$1,
            escortRole: escort.$2,
            organizationContext: seg.organization,
            departments: depts,
          ),
        );
      } else {
        branches.add(
          CareBranchHub.organization(
            organization: seg.organization,
            departments: depts,
          ),
        );
      }
    }
  }

  if (extraPatients.isNotEmpty) {
    final hostOrg = deptFirst.keys.firstWhere(
      (o) => o.contains('성소') || o.contains('병원'),
      orElse: () => reportingOrg ?? '외진',
    );
    final extraDept = DepartmentCareHub(
      department: '추가 외진',
      organizationContext: hostOrg,
      patients: extraPatients
          .map((n) => PersonCareRecord(name: n, role: '환자'))
          .toList(),
    );
    final idx = branches.indexWhere(
      (b) => !b.isEscort && b.organization == hostOrg,
    );
    if (idx >= 0) {
      final b = branches[idx];
      branches[idx] = CareBranchHub.organization(
        organization: b.organization!,
        departments: [...b.departments, extraDept],
      );
    } else {
      branches.add(
        CareBranchHub.organization(
          organization: hostOrg,
          departments: [extraDept],
        ),
      );
    }
  }

  return CareDepthTree(
    rootOrganization: reportingOrg,
    primaryEvent: event,
    branches: _dedupeOrganizationBranches(branches),
  );
}

Map<String, (String, String)> _parseEscortsByOrganization(String text) {
  final out = <String, (String, String)>{};
  for (final m in RegExp(
    r'([가-힣A-Za-z0-9]+병원)(?:에|에서)?\s*(?:외진)?(?:환자를?\s*)?인솔한\s*([가-힣]{2,4})\s*(보호사|간호사)',
  ).allMatches(text)) {
    out[m.group(1)!] = (normalizeKoreanPersonName(m.group(2)!), m.group(3)!);
  }
  for (final m in RegExp(
    r'([가-힣]{2,4})\s*(보호사|간호사)(?:가|는|이)?\s*(?:.*?)?([가-힣A-Za-z0-9]+병원)(?:에|에서)?\s*(?:외진)?(?:환자)?\s*인솔',
  ).allMatches(text)) {
    out[m.group(3)!] = (normalizeKoreanPersonName(m.group(1)!), m.group(2)!);
  }
  return out;
}

/// 성소병원에 이정숙 정형외과, 김명희 안과 … (이름+진료과 나열).
Map<String, List<DepartmentCareHub>> _parseHospitalPatientDeptLists(
  String text,
) {
  final out = <String, List<DepartmentCareHub>>{};
  final blockRe = RegExp(
    r'([가-힣A-Za-z0-9]+병원)에\s+([^\.]+?)(?=기우대\s+[가-힣A-Za-z0-9]+병원|총\s*\d|\.|$)',
  );
  for (final block in blockRe.allMatches(text)) {
    final org = _cleanOrg(block.group(1)!);
    final slice = block.group(2)!.trim();
    if (slice.contains('의 ')) continue;
    final deptsByName = <String, List<PersonCareRecord>>{};
    for (final m in RegExp(
      '([가-힣]{2,4})\\s+($kDepartmentSuffixPattern)',
    ).allMatches(slice)) {
      final name = normalizeKoreanPersonName(m.group(1)!);
      final dept = m.group(2)!.trim();
      if (!_isCarePersonName(name)) continue;
      deptsByName
          .putIfAbsent(dept, () => [])
          .add(PersonCareRecord(name: name, department: dept, role: '환자'));
    }
    if (deptsByName.isEmpty) continue;
    out[org] = deptsByName.entries
        .map(
          (e) => DepartmentCareHub(
            department: e.key,
            organizationContext: org,
            patients: e.value,
          ),
        )
        .toList();
  }
  return out;
}

/// 기우대 안동병원에 소화기내과
Map<String, List<DepartmentCareHub>> _parseInlinePatientOrgDept(String text) {
  final out = <String, List<DepartmentCareHub>>{};
  for (final m in RegExp(
    '([가-힣]{2,4})\\s+([가-힣A-Za-z0-9]+병원)에\\s+($kDepartmentSuffixPattern)',
  ).allMatches(text)) {
    final name = normalizeKoreanPersonName(m.group(1)!);
    final org = _cleanOrg(m.group(2)!);
    final dept = m.group(3)!.trim();
    if (!_isCarePersonName(name)) continue;
    final hub = DepartmentCareHub(
      department: dept,
      organizationContext: org,
      patients: [PersonCareRecord(name: name, department: dept, role: '환자')],
    );
    out[org] = _mergeDeptHubLists(out[org] ?? const [], [hub]);
  }
  return out;
}

Map<String, List<DepartmentCareHub>> _mergeDeptMaps(
  Map<String, List<DepartmentCareHub>> a,
  Map<String, List<DepartmentCareHub>> b,
) {
  if (b.isEmpty) return a;
  final out = Map<String, List<DepartmentCareHub>>.from(a);
  for (final entry in b.entries) {
    out[entry.key] = _mergeDeptHubLists(
      out[entry.key] ?? const [],
      entry.value,
    );
  }
  return out;
}

List<DepartmentCareHub> _mergeDeptHubLists(
  List<DepartmentCareHub> a,
  List<DepartmentCareHub> b,
) {
  final byDept = <String, DepartmentCareHub>{};
  for (final hub in [...a, ...b]) {
    final key = hub.department;
    final existing = byDept[key];
    if (existing == null) {
      byDept[key] = hub;
    } else {
      final patients = <PersonCareRecord>[...existing.patients];
      final seen = patients.map((p) => p.name).toSet();
      for (final p in hub.patients) {
        if (seen.add(p.name)) patients.add(p);
      }
      byDept[key] = DepartmentCareHub(
        department: hub.department,
        organizationContext:
            hub.organizationContext ?? existing.organizationContext,
        patients: patients,
      );
    }
  }
  return byDept.values.toList();
}

Map<String, (String, String)> _parsePatientCompanionMap(String text) {
  final out = <String, (String, String)>{};
  for (final m in RegExp(
    r'([가-힣]{2,4})\s*환자는\s*([가-힣]{2,4})\s*(간호사|보호사)가',
  ).allMatches(text)) {
    final patient = normalizeKoreanPersonName(m.group(1)!);
    final escort = normalizeKoreanPersonName(m.group(2)!);
    if (!_isCarePersonName(patient) || !isLikelyKoreanPersonName(escort))
      continue;
    out[patient] = (escort, _normalizeRole(m.group(3)!));
  }
  final selfMatch = RegExp(
    '난\\s+(.+?)\\s+환자(?:를|을)?\\s*데리고\\s+($kDepartmentSuffixPattern)',
  ).firstMatch(text);
  if (selfMatch != null) {
    for (final raw in selfMatch.group(1)!.split(RegExp(r'[,，、]'))) {
      final p = normalizeKoreanPersonName(raw.trim());
      if (p.isNotEmpty && _isCarePersonName(p)) {
        out[p] = ('나', '본인');
      }
    }
  }
  return out;
}

List<DepartmentCareHub> _applyCompanionsToDepartments(
  List<DepartmentCareHub> depts,
  Map<String, (String, String)> companions,
) {
  if (companions.isEmpty) return depts;
  return depts
      .map(
        (d) => DepartmentCareHub(
          department: d.department,
          organizationContext: d.organizationContext,
          patients: d.patients.map((p) {
            final c = companions[p.name];
            if (c == null) return p;
            return PersonCareRecord(
              name: p.name,
              department: p.department,
              role: p.role,
              companionName: c.$1,
              companionRole: c.$2,
            );
          }).toList(),
        ),
      )
      .toList();
}

List<String> _parseAdditionalPatientNames(String text) {
  final m = RegExp(r'추가로\s*([^.]+?)(?:환자|포함|외진|\.|$)').firstMatch(text);
  if (m == null) return [];
  return m
      .group(1)!
      .split(RegExp(r'[,，、]'))
      .map((s) => normalizeKoreanPersonName(s.trim().replaceAll('환자', '')))
      .where((n) => n.length >= 2 && _isCarePersonName(n))
      .toList();
}

List<CareBranchHub> _dedupeOrganizationBranches(List<CareBranchHub> branches) {
  final byKey = <String, CareBranchHub>{};
  for (final b in branches) {
    final key = b.isEscort
        ? 'escort::${b.escortName}::${b.organizationContext}'
        : 'org::${b.organization}';
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = b;
    } else if (!b.isEscort && !existing.isEscort) {
      byKey[key] = CareBranchHub.organization(
        organization: b.organization!,
        departments: _mergeDeptHubLists(existing.departments, b.departments),
      );
    }
  }
  return byKey.values.toList();
}

Map<String, List<DepartmentCareHub>> _parseDeptFirstBlocks(String text) {
  final out = <String, List<DepartmentCareHub>>{};
  final orgBlocks = RegExp(
    r'([가-힣A-Za-z0-9]+병원)의\s*([^\.]+?)(?=(?:[가-힣A-Za-z0-9]+병원)의|\.|$)',
  ).allMatches(text);

  for (final block in orgBlocks) {
    final org = _cleanOrg(block.group(1)!);
    final slice = block.group(2)!;
    final depts = <DepartmentCareHub>[];
    for (final m in RegExp(
      '($kDepartmentSuffixPattern)에\\s*([^\\.]+?)(?=(?:$kDepartmentSuffixPattern)에|\\.|\\s*\$)',
    ).allMatches(slice)) {
      final dept = m.group(1)!.trim();
      final patients = _extractPatientNames(m.group(2)!);
      if (patients.isNotEmpty) {
        depts.add(
          DepartmentCareHub(
            department: dept,
            organizationContext: org,
            patients: patients,
          ),
        );
      }
    }
    if (depts.isNotEmpty) out[org] = depts;
  }
  return out;
}

List<PersonCareRecord> _extractPatientNames(String slice) {
  final records = <PersonCareRecord>[];
  final seen = <String>{};
  for (final m in _patientRolePattern.allMatches(slice)) {
    final name = normalizeKoreanPersonName(m.group(1)!);
    if (name.isEmpty || name.length < 2) continue;
    if (!isLikelyKoreanPersonName(name) && !isFamilyRelationTerm(name))
      continue;
    if (!seen.add(name)) continue;
    final tail = slice.substring(m.end).trim();
    final companion = _companionAfterPatient(tail);
    records.add(
      PersonCareRecord(
        name: name,
        role: _normalizeRole(m.group(2)!),
        companionName: companion?.$1,
        companionRole: companion?.$2,
      ),
    );
  }
  return records;
}

(String name, String role)? _companionAfterPatient(String tail) {
  final self = RegExp(r'^(?:[,，、]\s*)?(?:나|저)(?:와|랑|하고)?').firstMatch(tail);
  if (self != null) return ('나', '본인');

  final escort = RegExp(
    r'^(?:[,，、.\s]*)?([가-힣]{2,4})\s*(보호사|간호사|담당)',
  ).firstMatch(tail);
  if (escort != null) {
    final name = normalizeKoreanPersonName(escort.group(1)!);
    if (name.isNotEmpty && isLikelyKoreanPersonName(name)) {
      return (name, _normalizeRole(escort.group(2)!));
    }
  }
  return null;
}

List<DepartmentCareHub> _groupPeopleByDepartment(
  String org,
  List<PersonCareRecord> people,
) {
  final byDept = <String, List<PersonCareRecord>>{};
  for (final p in people) {
    final dept = p.department?.trim().isNotEmpty == true
        ? p.department!.trim()
        : '미지정';
    byDept.putIfAbsent(dept, () => []).add(p);
  }
  return byDept.entries
      .map(
        (e) => DepartmentCareHub(
          department: e.key,
          organizationContext: org,
          patients: e.value,
        ),
      )
      .toList();
}

List<OrgCareSegment> _parseOrgCareSegments(String text) {
  if (_parseDeptFirstBlocks(text).isNotEmpty) {
    final out = <OrgCareSegment>[];
    for (final entry in _parseDeptFirstBlocks(text).entries) {
      final people = entry.value.expand((d) => d.patients).toList();
      out.add(OrgCareSegment(organization: entry.key, people: people));
    }
    return out;
  }

  final anchors = <({String org, int start, int end})>[];
  for (final m in _orgAnchorPattern.allMatches(text)) {
    final org = _cleanOrg(m.group(1)!);
    if (org.isEmpty) continue;
    anchors.add((org: org, start: m.start, end: m.end));
  }
  if (anchors.isEmpty) {
    final people = _extractPeopleRecords(text, currentOrg: null);
    if (people.isEmpty) return const [];
    return [OrgCareSegment(organization: '', people: people)];
  }

  final segments = <OrgCareSegment>[];
  for (var i = 0; i < anchors.length; i++) {
    final start = anchors[i].end;
    final end = i + 1 < anchors.length ? anchors[i + 1].start : text.length;
    final slice = text.substring(start, end);
    final people = _extractPeopleRecords(slice, currentOrg: anchors[i].org);
    if (people.isNotEmpty) {
      segments.add(
        OrgCareSegment(organization: anchors[i].org, people: people),
      );
    }
  }
  return segments;
}

List<PersonCareRecord> _extractPeopleRecords(
  String slice, {
  String? currentOrg,
}) {
  final records = <PersonCareRecord>[];
  final seen = <String>{};

  void addRecord(PersonCareRecord r) {
    final name = normalizeKoreanPersonName(r.name);
    if (name.isEmpty || name.length < 2) return;
    if (!isLikelyKoreanPersonName(name) && !isFamilyRelationTerm(name)) return;
    final key = '${r.role}::$name';
    if (!seen.add(key)) return;
    records.add(
      PersonCareRecord(name: name, department: r.department, role: r.role),
    );
  }

  for (final m in RegExp(
    r'((?:[가-힣]{2,4}\s*환자(?:를|는|가)?\s*,?\s*)+)\s*(?:는|을|를)\s*([^,，、병원]+)',
  ).allMatches(slice)) {
    final namesBlock = m.group(1)!;
    final dept = _cleanDepartment(m.group(2)!, currentOrg: currentOrg);
    for (final pm in _patientRolePattern.allMatches(namesBlock)) {
      addRecord(
        PersonCareRecord(
          name: pm.group(1)!,
          department: dept,
          role: _normalizeRole(pm.group(2)!),
        ),
      );
    }
  }

  for (final m in RegExp(
    r'([가-힣]{2,4})\s*(환자|간호사|보호자|의사|담당)(?:를|는|가)?\s*([^,，、]+?)(?=[,，、]|(?:[가-힣]{2,4})\s*(?:환자|간호사)|병원|총|\d+\s*명|$)',
  ).allMatches(slice)) {
    final dept = _cleanDepartment(m.group(3)!, currentOrg: currentOrg);
    addRecord(
      PersonCareRecord(
        name: m.group(1)!,
        department: dept,
        role: _normalizeRole(m.group(2)!),
      ),
    );
  }

  for (final m in RegExp(
    '([가-힣]{2,4})\\s*환자(?:는|를|가)?\\s*([가-힣A-Za-z0-9]+병원)\\s*($kDepartmentSuffixPattern)',
  ).allMatches(slice)) {
    addRecord(
      PersonCareRecord(
        name: m.group(1)!,
        department: m.group(3)!.trim(),
        role: '환자',
      ),
    );
  }

  return records;
}

String _normalizeRole(String raw) {
  final v = raw.trim();
  if (v == '담당') return '담당자';
  return v;
}

String _cleanOrg(String raw) =>
    raw.trim().replaceAll(RegExp(r'에는|에서|으로는|로는|에$|의$'), '').trim();

String? _cleanDepartment(String raw, {String? currentOrg}) {
  var v = raw.trim();
  v = v.replaceAll(RegExp(r'(?:로|으로)\s*진료.*$'), '').trim();
  v = v.replaceAll(RegExp(r'(?:로|으로)$'), '').trim();
  if (currentOrg != null && v.contains(currentOrg)) {
    v = v.replaceAll(currentOrg, '').trim();
  }
  for (final m in _departmentPattern.allMatches(v)) {
    return m.group(1)!.trim();
  }
  if (RegExp(kDepartmentSuffixPattern).hasMatch(v) && v.length <= 16) return v;
  return null;
}

List<MemoryRelation> _buildStructuredRelations({
  required String text,
  required String? event,
  required String? reportingOrg,
  required CareDepthTree depthTree,
  required List<OrgCareSegment> orgSegments,
  required int? declaredTotal,
  required String countRole,
  required String localeCode,
  required OrganizationHierarchy organizationHierarchy,
}) {
  final relations = <MemoryRelation>[];
  final eventLabel = event ?? '기록';

  if (organizationHierarchy.hasHierarchy) {
    for (final edge in organizationHierarchy.hierarchyEdges) {
      relations.add(
        MemoryRelation(
          subject: edge.to,
          predicate: edge.label,
          object: edge.from,
        ),
      );
    }
    for (final relation in organizationHierarchy.crossRelations) {
      relations.add(
        MemoryRelation(
          subject: relation.subject,
          predicate: relation.predicate,
          object: relation.object,
        ),
      );
    }
    return relations;
  }

  if (reportingOrg != null && reportingOrg.isNotEmpty) {
    relations.add(MemoryRelation(predicate: '출발', object: reportingOrg));
  }

  if (depthTree.hasDepth) {
    for (final branch in depthTree.branches) {
      final branchLabel = branch.branchTitle;
      if (branch.isEscort) {
        relations.add(
          MemoryRelation(
            subject: branch.escortName!,
            predicate: '인솔',
            object: branch.organizationContext ?? eventLabel,
          ),
        );
      } else if (branch.organization != null) {
        relations.add(
          MemoryRelation(predicate: '방문', object: branch.organization!),
        );
      }

      for (final dept in branch.departments) {
        relations.add(
          MemoryRelation(
            subject: branchLabel,
            predicate: '진료과',
            object: dept.displayTitle,
          ),
        );
        for (final patient in dept.patients) {
          relations.add(
            MemoryRelation(
              subject: patient.name,
              predicate: '진료',
              object: dept.department,
            ),
          );
          if (branch.organization != null) {
            relations.add(
              MemoryRelation(
                subject: patient.name,
                predicate: '소속',
                object: branch.organization!,
              ),
            );
          }
          if (branch.isEscort) {
            relations.add(
              MemoryRelation(
                subject: branch.escortName!,
                predicate: '인솔',
                object: patient.name,
              ),
            );
          }
          if (event != null) {
            relations.add(
              MemoryRelation(
                subject: patient.name,
                predicate: event.contains('외진') ? '외진' : '참여',
                object: eventLabel,
              ),
            );
          }
        }
      }
    }
  } else {
    for (final seg in orgSegments) {
      final org = seg.organization.trim();
      for (final person in seg.people) {
        if (org.isNotEmpty) {
          relations.add(
            MemoryRelation(subject: person.name, predicate: '소속', object: org),
          );
        }
        if (person.department != null && person.department!.isNotEmpty) {
          relations.add(
            MemoryRelation(
              subject: person.name,
              predicate: '진료',
              object: person.department!,
            ),
          );
        }
        if (event != null) {
          relations.add(
            MemoryRelation(
              subject: person.name,
              predicate: event.contains('외진') ? '외진' : '참여',
              object: eventLabel,
            ),
          );
        }
      }
    }
  }

  if (declaredTotal != null) {
    relations.add(MemoryRelation(predicate: '총인원', object: '$declaredTotal명'));
  }

  return relations;
}

/// 프레임 결과를 엔티티 번들 병합용 리스트로 펼칩니다.
void mergeSemanticFlowIntoLists({
  required MemorySemanticFrame frame,
  required List<String> people,
  required List<String> organizations,
  required List<String> activities,
  required List<String> events,
  required List<String> places,
  required Set<String> seenPeople,
  required Set<String> seenOrgs,
  required Set<String> seenActivities,
  required Set<String> seenEvents,
  required Set<String> seenPlaces,
}) {
  void addPeople(String name) {
    final n = normalizeKoreanPersonName(name);
    if (n.isEmpty || isMedicalNonPersonToken(n) || isMedicalGraphNoisePhrase(n))
      return;
    if (!seenPeople.add(n)) return;
    people.add(n);
  }

  void addOrg(String name) {
    final o = name.trim();
    if (o.isEmpty || !seenOrgs.add(o)) return;
    organizations.add(o);
  }

  void addActivity(String name) {
    final a = name.trim();
    if (a.isEmpty || !seenActivities.add(a)) return;
    activities.add(a);
  }

  void addPlace(String name) {
    final p = name.trim();
    if (p.isEmpty || isMedicalGraphNoisePhrase(p) || !seenPlaces.add(p)) return;
    places.add(p);
  }

  void addEvent(String name) {
    final e = name.trim();
    if (e.isEmpty || !seenEvents.add(e)) return;
    events.add(e);
  }

  if (frame.primaryEvent != null) addEvent(frame.primaryEvent!);
  if (frame.organizationHierarchy.hasHierarchy) {
    for (final node in frame.organizationHierarchy.nodes) {
      switch (node.kind) {
        case OrganizationNodeKind.organization:
          addOrg(node.label);
        case OrganizationNodeKind.person:
        case OrganizationNodeKind.pet:
          addPeople(node.label);
        case OrganizationNodeKind.project:
        case OrganizationNodeKind.event:
          addEvent(node.label);
        case OrganizationNodeKind.place:
          addPlace(node.label);
        case OrganizationNodeKind.activity:
        case OrganizationNodeKind.food:
        case OrganizationNodeKind.item:
          addActivity(node.label);
      }
    }
    return;
  }
  if (frame.reportingOrganization != null) {
    addOrg(frame.reportingOrganization!);
    addPlace(frame.reportingOrganization!);
  }

  if (frame.depthTree.hasDepth) {
    for (final branch in frame.depthTree.branches) {
      if (branch.isEscort) {
        addPeople(branch.escortName!);
      } else if (branch.organization != null) {
        addOrg(branch.organization!);
        addPlace(branch.organization!);
      }
      for (final dept in branch.departments) {
        addActivity(dept.department);
        addPlace(dept.department);
        for (final p in dept.patients) {
          addPeople(p.name);
        }
      }
    }
    return;
  }

  for (final seg in frame.orgSegments) {
    if (seg.organization.isNotEmpty) {
      addOrg(seg.organization);
      addPlace(seg.organization);
    }
    for (final p in seg.people) {
      addPeople(p.name);
      if (p.department != null) {
        addActivity(p.department!);
        addPlace(p.department!);
      }
    }
  }
}
