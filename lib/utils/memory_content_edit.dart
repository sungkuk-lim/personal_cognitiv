import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import 'memory_detail_text.dart';
import 'ocr_utils.dart';

/// 상세 시트·편집 다이얼로그에 보이는 본문.
String memoryEditDisplayBody(Memory memory, {required String graphMarkerLabel}) {
  final content = memory.content.trim();
  if (content.isNotEmpty) {
    final parts = splitMemoryBodyForDisplay(memory, graphMarkerLabel: graphMarkerLabel);
    if (parts.mainText.trim().isNotEmpty) return parts.mainText.trim();
    return content;
  }
  return memoryDetailBodyTextFromRaw(memory).trim();
}

/// 본문 편집 저장 — 부록(관계망 메모) 유지, 요약이 본문과 겹치면 함께 갱신.
Memory applyMemoryContentEdit({
  required Memory memory,
  required String newMainText,
  required String previousBodyText,
  required String graphMarkerLabel,
  String localeCode = 'ko',
}) {
  final trimmed = newMainText.trim();
  final hadContent = memory.content.trim().isNotEmpty;

  // 실수로 본문을 비우는 저장을 막습니다.
  if (trimmed.isEmpty && hadContent) {
    return memory;
  }

  final parts = splitMemoryBodyForDisplay(memory, graphMarkerLabel: graphMarkerLabel);
  final content = parts.appendixText != null && parts.appendixText!.trim().isNotEmpty
      ? '$trimmed\n${parts.appendixText!.trim()}'
      : trimmed;

  var updated = memory.copyWith(content: content);

  if (trimmed.isNotEmpty) {
    updated = updated.copyWith(summary: _summaryFromEditedBody(trimmed));
  }

  return updated;
}

String _summaryFromEditedBody(String body) {
  final line = body.split(RegExp(r'[\n\r]+')).first.trim();
  if (line.length <= 80) return line;
  return '${line.substring(0, 77)}…';
}

/// 관계망 레이아웃 캐시 무효화용 — 내용·엔티티가 바뀌면 시그니처가 달라집니다.
String graphMemoryLayoutSignature(Iterable<Memory> memories) {
  return memories
      .map((m) => '${m.id}\x1e${m.summary}\x1e${m.content}\x1e${m.entities.join('\x1f')}')
      .join('\x1d');
}
