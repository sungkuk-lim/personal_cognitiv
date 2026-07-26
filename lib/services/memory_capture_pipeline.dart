import '../core/memory_work_type.dart';
import '../data/care_entity_dictionary.dart';
import '../models/memory_pipeline_models.dart';
import 'dialect_normalize_service.dart';
import 'structured_memory_extract_builder.dart';
import 'work_type_ai_extractor.dart';
import 'work_type_classifier.dart';

/// STT → 사전보정 → 업무분류 → (선택)AI → 엔티티·관계 생성 파이프라인.
///
/// 대부분 단계는 로컬 규칙·사전으로 처리하고, AI는 [useCloudAi]일 때
/// 구조화가 필요한 단계(④)에만 1회 호출합니다.
class MemoryCapturePipeline {
  MemoryCapturePipeline({CareEntityDictionary? dictionary})
      : _dictionary = dictionary ?? CareEntityDictionary.seed();

  final CareEntityDictionary _dictionary;

  static final MemoryCapturePipeline instance = MemoryCapturePipeline();

  Future<MemoryCapturePipelineResult> process({
    required String rawSttText,
    required String localeCode,
    bool useCloudAi = false,
  }) async {
    // ②
    final normalizedText = DialectNormalizeService.normalize(
      rawSttText,
      dictionary: _dictionary,
    );

    // ③
    final workType = WorkTypeClassifier.classify(normalizedText);

    // ④ 로컬 baseline (항상)
    var extract = StructuredMemoryExtractBuilder.fromText(
      normalizedText,
      workType: workType,
      dictionary: _dictionary,
    );

    var usedCloudAi = false;
    if (useCloudAi && _shouldUseAi(workType)) {
      final aiExtract = await WorkTypeAiExtractor.extract(
        workType: workType,
        normalizedText: normalizedText,
        localeCode: localeCode,
        localBaseline: extract,
      );
      if (aiExtract != null) {
        extract = _mergeExtract(extract, aiExtract);
        usedCloudAi = true;
      }
    }

    // ⑤ 검증
    final issues = PipelineValidator.validate(extract, localeCode: localeCode);
    final corrections = _collectCorrections(extract);

    return MemoryCapturePipelineResult(
      originalText: rawSttText,
      normalizedText: normalizedText,
      workType: workType,
      extract: extract,
      corrections: corrections,
      issues: issues,
      usedCloudAi: usedCloudAi,
    );
  }

  bool _shouldUseAi(MemoryWorkType type) {
    return switch (type) {
      MemoryWorkType.homeVisitMedical => true,
      MemoryWorkType.general => false,
      MemoryWorkType.social => true,
      MemoryWorkType.travel => true,
      MemoryWorkType.workGeneral => true,
    };
  }

  StructuredMemoryExtract _mergeExtract(
    StructuredMemoryExtract local,
    StructuredMemoryExtract ai,
  ) {
    if (local.workType != MemoryWorkType.homeVisitMedical) {
      return StructuredMemoryExtract(
        summary: ai.summary.isNotEmpty ? ai.summary : local.summary,
        workType: local.workType,
        visit: ai.visit ?? local.visit,
        extraEntities: {...local.extraEntities, ...ai.extraEntities}.toList(),
        relations: local.relations.isNotEmpty ? local.relations : ai.relations,
      );
    }

    final localVisit = local.visit;
    final aiVisit = ai.visit;
    if (localVisit == null) return ai;
    if (aiVisit == null) return local;

    return StructuredMemoryExtract(
      summary: ai.summary.isNotEmpty ? ai.summary : local.summary,
      workType: MemoryWorkType.homeVisitMedical,
      visit: StructuredVisitRecord(
        originHospital: aiVisit.originHospital ?? localVisit.originHospital,
        declaredPatientCount: aiVisit.declaredPatientCount ?? localVisit.declaredPatientCount,
        branches: localVisit.branches.isNotEmpty ? localVisit.branches : aiVisit.branches,
      ),
      extraEntities: {...local.extraEntities, ...ai.extraEntities}.toList(),
      relations: local.relations,
    );
  }

  List<DictionaryCorrection> _collectCorrections(StructuredMemoryExtract extract) {
    final out = <DictionaryCorrection>[];
    for (final tag in extract.extraEntities) {
      if (!tag.startsWith('dict:confirm:')) continue;
      final body = tag.substring('dict:confirm:'.length);
      final parts = body.split(':');
      if (parts.length < 2) continue;
      final field = parts[0];
      final arrow = parts.sublist(1).join(':');
      final sep = arrow.indexOf('->');
      if (sep <= 0) continue;
      out.add(DictionaryCorrection(
        field: field,
        raw: arrow.substring(0, sep),
        corrected: arrow.substring(sep + 2),
        confidence: 0.85,
        needsUserConfirm: true,
      ));
    }
    return out;
  }

  CareEntityDictionary get dictionary => _dictionary;

  MemoryCapturePipeline withDictionary(CareEntityDictionary dictionary) {
    return MemoryCapturePipeline(dictionary: dictionary);
  }
}
