import '../models/memory.dart';
import 'memory_entity_extract.dart';
import 'ocr_utils.dart';

/// 사용자가 관계 태그를 직접 수정했음을 표시합니다. 자동 re-enrich 시 표시 라벨을 덮어쓰지 않습니다.
const String kTagEntitiesManual = 'tag:entities_manual';

bool memoryHasManualEntityEdit(Memory memory) => memory.entities.contains(kTagEntitiesManual);

/// 상세·편집 UI에 보이는 라벨 목록.
List<String> editableEntityLabelsForMemory(Memory memory) {
  return memory.entities
      .where((e) => !isInternalMemoryEntityTag(e) && !e.startsWith('tag:'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 수동 편집 결과를 entities에 반영합니다 (내부 rel/event/time 태그는 유지).
List<String> mergeManualEntityLabels(Memory memory, List<String> userLabels) {
  final internal = memory.entities.where((e) {
    if (e == kTagEntitiesManual) return false;
    return isInternalMemoryEntityTag(e) || e.startsWith('tag:');
  }).toList();

  final cleaned = <String>[];
  final seen = <String>{};
  for (final raw in userLabels) {
    final label = raw.trim();
    if (label.isEmpty || !seen.add(label)) continue;
    cleaned.add(label);
  }

  return [...cleaned, ...internal, kTagEntitiesManual];
}

/// 타임라인·회상·상세 — 수동 태그 편집 시 저장된 라벨을 그대로 노출합니다.
List<String> displayTagsForMemory(Memory memory, {String localeCode = 'ko'}) {
  if (memoryHasManualEntityEdit(memory)) {
    return editableEntityLabelsForMemory(memory);
  }
  return userVisibleEntityLabels(memory, localeCode: localeCode);
}
