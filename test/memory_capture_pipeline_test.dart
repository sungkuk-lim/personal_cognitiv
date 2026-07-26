import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/core/memory_work_type.dart';
import 'package:personal_cognitive/data/care_entity_dictionary.dart';
import 'package:personal_cognitive/services/dialect_normalize_service.dart';
import 'package:personal_cognitive/services/memory_capture_pipeline.dart';
import 'package:personal_cognitive/services/work_type_classifier.dart';

void main() {
  const clinic =
      '오늘 대성그린병원 외진현황 보고로는 총 7명이 외진했습니다. '
      '성수병원에는 이정숙 환자를 정형외과, 김명희 환자를 안과, 정준호 환자, 이기동 환자는 치과로 진료했습니다. '
      '안동병원에는 기우대 환자는 소화기내과로 진료했습니다.';

  test('dialect normalize fixes STT hospital typo', () {
    const raw = '성수병원에 김명희 환자';
    final fixed = DialectNormalizeService.normalize(raw);
    expect(fixed, contains('성소병원'));
  });

  test('work type classifier detects home visit medical', () {
    expect(WorkTypeClassifier.classify(clinic), MemoryWorkType.homeVisitMedical);
  });

  test('dictionary fuzzy matches hospital typo', () {
    final exact = lookupHospital('성수병원', CareEntityDictionary.seed());
    expect(exact.matched, isTrue);
    expect(exact.value, '성소병원');

    final fuzzy = lookupHospital('성소병욘', CareEntityDictionary.seed());
    expect(fuzzy.matched, isTrue);
    expect(fuzzy.value, '성소병원');
    expect(fuzzy.needsUserConfirm, isTrue);
  });

  test('pipeline runs locally without AI', () async {
    final result = await MemoryCapturePipeline.instance.process(
      rawSttText: clinic,
      localeCode: 'ko',
      useCloudAi: false,
    );
    expect(result.workType, MemoryWorkType.homeVisitMedical);
    expect(result.normalizedText, contains('성소병원'));
    expect(result.extract.extractedPatientCount, 5);
    expect(result.hasQuantityMismatch, isTrue);
    expect(result.pipelineEntityTags, contains('tag:work:homeVisitMedical'));
    expect(result.pipelineEntityTags.any((e) => e.startsWith('rel:')), isTrue);
  });
}
