import '../core/memory_work_type.dart';
import '../utils/memory_graph_semantics.dart';

/// 사전 fuzzy 매칭 결과.
class DictionaryCorrection {
  const DictionaryCorrection({
    required this.field,
    required this.raw,
    required this.corrected,
    required this.confidence,
    this.needsUserConfirm = false,
  });

  final String field;
  final String raw;
  final String corrected;
  final double confidence;
  final bool needsUserConfirm;
}

/// 파이프라인 검증 이슈 (인원 불일치·사전 미매칭 등).
class PipelineValidationIssue {
  const PipelineValidationIssue({
    required this.code,
    required this.message,
    this.severity = 'info',
  });

  final String code;
  final String message;
  final String severity;

  bool get isBlocking => severity == 'error';
}

/// 구조화된 방문·외진 기록 (JSON·로컬 파서 공통).
class StructuredVisitRecord {
  const StructuredVisitRecord({
    this.originHospital,
    this.declaredPatientCount,
    this.branches = const [],
  });

  final String? originHospital;
  final int? declaredPatientCount;
  final List<StructuredVisitBranch> branches;
}

class StructuredVisitBranch {
  const StructuredVisitBranch({
    this.hospital,
    this.escortName,
    this.escortRole,
    this.departments = const [],
  });

  final String? hospital;
  final String? escortName;
  final String? escortRole;
  final List<StructuredDepartmentRecord> departments;
}

class StructuredDepartmentRecord {
  const StructuredDepartmentRecord({
    required this.department,
    this.patients = const [],
  });

  final String department;
  final List<String> patients;
}

/// ⑤~⑦ 단계 산출물.
class StructuredMemoryExtract {
  const StructuredMemoryExtract({
    this.summary = '',
    this.workType = MemoryWorkType.general,
    this.visit,
    this.extraEntities = const [],
    this.relations = const [],
  });

  final String summary;
  final MemoryWorkType workType;
  final StructuredVisitRecord? visit;
  final List<String> extraEntities;
  final List<MemoryRelation> relations;

  int get extractedPatientCount {
    final v = visit;
    if (v == null) return 0;
    return v.branches.fold<int>(
      0,
      (n, b) => n + b.departments.fold<int>(0, (d, dept) => d + dept.patients.length),
    );
  }

  List<String> toPipelineEntityTags() {
    final tags = <String>[
      workTypeTag(workType),
      ...extraEntities,
      for (final rel in relations) rel.toEntityTag(),
    ];
    final v = visit;
    if (v?.declaredPatientCount != null) {
      tags.add('count:declared:환자:${v!.declaredPatientCount}');
    }
    if (extractedPatientCount > 0) {
      tags.add('count:extracted:환자:$extractedPatientCount');
    }
    return tags;
  }
}

/// STT → 저장 직전 파이프라인 결과.
class MemoryCapturePipelineResult {
  const MemoryCapturePipelineResult({
    required this.originalText,
    required this.normalizedText,
    required this.workType,
    required this.extract,
    this.corrections = const [],
    this.issues = const [],
    this.usedCloudAi = false,
  });

  final String originalText;
  final String normalizedText;
  final MemoryWorkType workType;
  final StructuredMemoryExtract extract;
  final List<DictionaryCorrection> corrections;
  final List<PipelineValidationIssue> issues;
  final bool usedCloudAi;

  String get summary => extract.summary;

  List<String> get pipelineEntityTags => extract.toPipelineEntityTags();

  bool get hasQuantityMismatch {
    final declared = extract.visit?.declaredPatientCount;
    if (declared == null) return false;
    return declared != extract.extractedPatientCount;
  }
}
