import 'dart:convert';

import '../core/memory_work_type.dart';
import '../models/memory_pipeline_models.dart';
import '../services/ai_service.dart';
import '../utils/memory_graph_semantics.dart';

/// ④ 업무별 AI 구조화 — 클라우드일 때만 호출.
class WorkTypeAiExtractor {
  const WorkTypeAiExtractor._();

  static Future<StructuredMemoryExtract?> extract({
    required MemoryWorkType workType,
    required String normalizedText,
    required String localeCode,
    StructuredMemoryExtract? localBaseline,
  }) async {
    if (normalizedText.trim().isEmpty) return null;

    final system = _systemPrompt(workType, localeCode);
    final user = normalizedText.trim();

    try {
      final raw = await AiService.instance.chatJson(systemPrompt: system, userPrompt: user);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return _parseAiJson(data, workType, localBaseline: localBaseline);
    } catch (_) {
      return localBaseline;
    }
  }

  static String _systemPrompt(MemoryWorkType workType, String localeCode) {
    final lang = localeCode == 'ko' ? 'Korean' : 'English';
    final base = 'Respond in $lang. Return JSON only. Never invent patients or hospitals not in the text.';
    return switch (workType) {
      MemoryWorkType.homeVisitMedical => '''
$base
Work type: home visit / medical outreach (방문간호·외진).
Schema:
{
  "summary": "one sentence core meaning",
  "origin_hospital": "string or null",
  "declared_patient_count": number or null,
  "visits": [
    {
      "hospital": "string",
      "escort": {"name": "string or null", "role": "보호사|간호사 or null"},
      "departments": [
        {"name": "진료과명", "patients": ["환자이름"]}
      ]
    }
  ]
}
Rules: patients are people only. departments and hospitals are NOT patients. Use exact names from text.
''',
      MemoryWorkType.social => '''
$base
Schema: {"summary": "string", "people": ["string"], "place": "string or null", "activity": "string or null"}
''',
      MemoryWorkType.travel => '''
$base
Schema: {"summary": "string", "places": ["string"], "people": ["string"]}
''',
      _ => '''
$base
Schema: {"summary": "string", "entities": ["short nouns max 6"], "category": "Work|Social|Health|Travel|Other"}
''',
    };
  }

  static StructuredMemoryExtract? _parseAiJson(
    Map<String, dynamic> data,
    MemoryWorkType workType, {
    StructuredMemoryExtract? localBaseline,
  }) {
    return switch (workType) {
      MemoryWorkType.homeVisitMedical => _parseHomeVisit(data, localBaseline),
      _ => _parseGeneric(data, workType, localBaseline),
    };
  }

  static StructuredMemoryExtract _parseHomeVisit(
    Map<String, dynamic> data,
    StructuredMemoryExtract? baseline,
  ) {
    final visitsRaw = data['visits'] as List<dynamic>? ?? const [];
    final branches = <StructuredVisitBranch>[];
    for (final v in visitsRaw) {
      if (v is! Map<String, dynamic>) continue;
      final escort = v['escort'] as Map<String, dynamic>?;
      final deptsRaw = v['departments'] as List<dynamic>? ?? const [];
      final depts = <StructuredDepartmentRecord>[];
      for (final d in deptsRaw) {
        if (d is! Map<String, dynamic>) continue;
        final name = (d['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final patients = (d['patients'] as List<dynamic>? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        depts.add(StructuredDepartmentRecord(department: name, patients: patients));
      }
      branches.add(StructuredVisitBranch(
        hospital: (v['hospital'] as String?)?.trim(),
        escortName: escort?['name'] as String?,
        escortRole: escort?['role'] as String?,
        departments: depts,
      ));
    }

    final visit = StructuredVisitRecord(
      originHospital: (data['origin_hospital'] as String?)?.trim(),
      declaredPatientCount: (data['declared_patient_count'] as num?)?.toInt(),
      branches: branches.isNotEmpty
          ? branches
          : baseline?.visit?.branches ?? const [],
    );

    final relations = <MemoryRelation>[
      if (baseline != null) ...baseline.relations,
    ];

    return StructuredMemoryExtract(
      summary: (data['summary'] as String?)?.trim().isNotEmpty == true
          ? data['summary'] as String
          : (baseline?.summary ?? ''),
      workType: MemoryWorkType.homeVisitMedical,
      visit: visit,
      relations: relations,
      extraEntities: baseline?.extraEntities ?? const [],
    );
  }

  static StructuredMemoryExtract _parseGeneric(
    Map<String, dynamic> data,
    MemoryWorkType workType,
    StructuredMemoryExtract? baseline,
  ) {
    final entities = (data['entities'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return StructuredMemoryExtract(
      summary: (data['summary'] as String?)?.trim().isNotEmpty == true
          ? data['summary'] as String
          : (baseline?.summary ?? ''),
      workType: workType,
      extraEntities: [...entities, ...(baseline?.extraEntities ?? const [])],
      relations: baseline?.relations ?? const [],
      visit: baseline?.visit,
    );
  }
}
