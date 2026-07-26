import '../models/memory.dart';
import 'memory_graph_semantics.dart';
import 'memory_semantic_flow.dart';

const String kCountPrefix = 'count:';

/// 선언된 총인원 vs 추출된 인원 불일치 리포트.
class QuantityConsistencyReport {
  const QuantityConsistencyReport({
    required this.declaredTotal,
    required this.extractedCount,
    required this.role,
    required this.localeCode,
  });

  final int declaredTotal;
  final int extractedCount;
  final String role;
  final String localeCode;

  bool get hasMismatch => declaredTotal != extractedCount;

  int get gap => declaredTotal - extractedCount;

  String get title => localeCode == 'ko' ? '인원 수 확인' : 'Headcount check';

  String get message {
    if (!hasMismatch) {
      return localeCode == 'ko'
          ? '총 $declaredTotal명으로 기록되었고, $extractedCount명이 인식되었습니다.'
          : 'Recorded total $declaredTotal; extracted $extractedCount.';
    }
    if (localeCode == 'ko') {
      return '총 $declaredTotal명이라고 기록되었지만, 현재 인식된 $role은(는) $extractedCount명입니다. '
          '나머지 ${gap.abs()}명을 말씀해 주시면 정확도가 높아집니다.';
    }
    return 'Recorded total $declaredTotal $role, but only $extractedCount were recognized. '
        'Please add the remaining ${gap.abs()} for better accuracy.';
  }
}

QuantityConsistencyReport? quantityReportFromMemory(Memory memory, {String localeCode = 'ko'}) {
  final text = '${memory.content}\n${memory.summary}';
  final frame = parseMemorySemanticFlow(text, localeCode: localeCode);
  if (frame.declaredTotalCount == null) return null;
  final extracted = frame.extractedPersonCount;
  if (extracted == 0 && frame.declaredTotalCount == 0) return null;
  return QuantityConsistencyReport(
    declaredTotal: frame.declaredTotalCount!,
    extractedCount: extracted,
    role: frame.countRole ?? '참여',
    localeCode: localeCode,
  );
}

List<String> countTagsFromFrame(MemorySemanticFrame frame) {
  final tags = <String>[];
  if (frame.declaredTotalCount != null) {
    tags.add('${kCountPrefix}declared:${frame.countRole ?? '참여'}:${frame.declaredTotalCount}');
  }
  final extracted = frame.extractedPersonCount;
  if (extracted > 0) {
    tags.add('${kCountPrefix}extracted:환자:$extracted');
  }
  return tags;
}
