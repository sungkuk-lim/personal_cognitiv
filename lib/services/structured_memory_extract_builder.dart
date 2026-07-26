import '../core/memory_work_type.dart';
import '../data/care_entity_dictionary.dart';
import '../models/memory_pipeline_models.dart';
import '../utils/memory_graph_semantics.dart';
import '../utils/memory_semantic_flow.dart';

/// ⑥⑦ 로컬 구조화 — 규칙 파서 + 사전 보정.
class StructuredMemoryExtractBuilder {
  const StructuredMemoryExtractBuilder._();

  static StructuredMemoryExtract fromText(
    String text, {
    required MemoryWorkType workType,
    CareEntityDictionary? dictionary,
  }) {
    final dict = dictionary ?? CareEntityDictionary.seed();
    return switch (workType) {
      MemoryWorkType.homeVisitMedical => _fromHomeVisit(text, dict),
      _ => _fromGeneric(text, workType),
    };
  }

  static StructuredMemoryExtract _fromHomeVisit(String text, CareEntityDictionary dict) {
    final frame = parseMemorySemanticFlow(text);
    final tree = frame.depthTree;
    final corrections = <DictionaryCorrection>[];

    String? origin = tree.rootOrganization;
    if (origin != null) {
      final lookup = lookupHospital(origin, dict);
      if (lookup.value != origin) {
        corrections.add(DictionaryCorrection(
          field: 'origin_hospital',
          raw: origin,
          corrected: lookup.value,
          confidence: lookup.confidence,
          needsUserConfirm: lookup.needsUserConfirm,
        ));
      }
      origin = lookup.value;
    }

    final branches = <StructuredVisitBranch>[];
    for (final branch in tree.branches) {
      String? hospital = branch.organization;
      if (hospital != null) {
        final lookup = lookupHospital(hospital, dict);
        if (lookup.value != hospital) {
          corrections.add(DictionaryCorrection(
            field: 'hospital',
            raw: hospital,
            corrected: lookup.value,
            confidence: lookup.confidence,
            needsUserConfirm: lookup.needsUserConfirm,
          ));
        }
        hospital = lookup.value;
      }

      final depts = <StructuredDepartmentRecord>[];
      for (final dept in branch.departments) {
        final deptLookup = lookupDepartment(dept.department, dict);
        final deptName = deptLookup.value;
        if (deptLookup.value != dept.department) {
          corrections.add(DictionaryCorrection(
            field: 'department',
            raw: dept.department,
            corrected: deptName,
            confidence: deptLookup.confidence,
            needsUserConfirm: deptLookup.needsUserConfirm,
          ));
        }
        depts.add(StructuredDepartmentRecord(
          department: deptName,
          patients: dept.patients.map((p) => p.name).toList(),
        ));
      }

      branches.add(StructuredVisitBranch(
        hospital: hospital,
        escortName: branch.escortName,
        escortRole: branch.escortRole,
        departments: depts,
      ));
    }

    final visit = StructuredVisitRecord(
      originHospital: origin,
      declaredPatientCount: frame.declaredTotalCount,
      branches: branches,
    );

    final relations = List<MemoryRelation>.from(frame.structuredRelations);
    final summary = frame.primaryEvent?.isNotEmpty == true
        ? '${frame.primaryEvent}${origin != null ? ' · $origin' : ''}'
        : (origin ?? '방문·외진 기록');

    return StructuredMemoryExtract(
      summary: summary,
      workType: MemoryWorkType.homeVisitMedical,
      visit: visit,
      extraEntities: [
        ...frame.metaTags,
        for (final c in corrections)
          if (c.needsUserConfirm) 'dict:confirm:${c.field}:${c.raw}->${c.corrected}',
      ],
      relations: relations,
    );
  }

  static StructuredMemoryExtract _fromGeneric(String text, MemoryWorkType workType) {
    final frame = parseMemorySemanticFlow(text);
    return StructuredMemoryExtract(
      summary: frame.primaryEvent ?? text.split(RegExp(r'[.。\n]')).first.trim(),
      workType: workType,
      relations: frame.structuredRelations,
      extraEntities: frame.metaTags,
    );
  }
}

/// 사전 보정·인원 검증.
class PipelineValidator {
  const PipelineValidator._();

  static List<PipelineValidationIssue> validate(
    StructuredMemoryExtract extract, {
    String localeCode = 'ko',
  }) {
    final issues = <PipelineValidationIssue>[];
    final visit = extract.visit;
    if (visit == null) return issues;

    final declared = visit.declaredPatientCount;
    final extracted = extract.extractedPatientCount;
    if (declared != null && declared != extracted) {
      issues.add(PipelineValidationIssue(
        code: 'quantity_mismatch',
        severity: 'warning',
        message: localeCode == 'ko'
            ? '총 $declared명으로 기록되었지만 인식된 환자는 $extracted명입니다.'
            : 'Declared $declared patients but extracted $extracted.',
      ));
    }

    for (final tag in extract.extraEntities) {
      if (tag.startsWith('dict:confirm:')) {
        final body = tag.substring('dict:confirm:'.length);
        issues.add(PipelineValidationIssue(
          code: 'dictionary_confirm',
          severity: 'info',
          message: localeCode == 'ko' ? '사전 보정 확인: $body' : 'Dictionary fix: $body',
        ));
      }
    }

    return issues;
  }
}
