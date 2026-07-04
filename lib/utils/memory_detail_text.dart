import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import 'memory_place_cache.dart';
import 'ocr_utils.dart';

String _normalizeForCompare(String text) {
  return text.trim().replaceAll(RegExp(r'[.!?…]+$'), '').replaceAll(RegExp(r'\s+'), ' ');
}

/// 요약·본문 앞부분이 같으면 본문만 한 번 보여줍니다.
bool memoryTextsOverlapForDisplay(String a, String b) {
  final x = _normalizeForCompare(a);
  final y = _normalizeForCompare(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  if (y.startsWith(x)) return true;
  final firstLine = y.split(RegExp(r'[\n\r]+')).first;
  return _normalizeForCompare(firstLine) == x;
}

/// 본문 앞의 요약·제목 중복을 제거합니다.
String stripLeadingDuplicateText(String lead, String body) {
  final summary = lead.trim();
  var text = body.trim();
  if (summary.isEmpty || text.isEmpty) return text;
  if (_normalizeForCompare(summary) == _normalizeForCompare(text)) return text;

  final summaryNorm = _normalizeForCompare(summary);
  final lines = text.split(RegExp(r'[\n\r]+'));
  if (lines.isNotEmpty && _normalizeForCompare(lines.first) == summaryNorm) {
    return lines.skip(1).join('\n').trim();
  }

  if (text.startsWith(summary)) {
    return text.substring(summary.length).trim().replaceFirst(RegExp(r'^[.!?\s…]+'), '');
  }

  return text;
}

/// 상세 시트에서 요약(제목) 줄을 따로 보여줄지.
bool shouldShowMemoryDetailSummaryTitle({
  required String summaryTitle,
  required String bodyText,
}) {
  final title = summaryTitle.trim();
  final body = bodyText.trim();
  if (title.isEmpty || body.isEmpty) return title.isNotEmpty && body.isEmpty;
  if (_normalizeForCompare(title) == _normalizeForCompare(body)) return false;
  if (memoryTextsOverlapForDisplay(title, body)) return false;
  return true;
}

/// 상세 시트 본문 — 요약과 겹치는 첫 줄은 제거하지 않고 전체 본문 유지(제목만 숨김).
String memoryDetailDisplayBody(Memory memory) {
  return memoryDetailBodyTextFromRaw(memory);
}

String memoryDetailBodyTextFromRaw(Memory memory) {
  if (isGraphNoteMemory(memory)) {
    final fact = graphNoteFactTitle(memory);
    if (fact.isNotEmpty) return fact;
  }

  final content = memory.content.trim();
  if (content.isNotEmpty) return content;

  final summary = stripLatLngFromTitle(memory.summary).trim();
  if (summary.isNotEmpty && !isJunkEntityOrKeyword(summary)) return summary;

  final memo = displayUserMemoForMemory(memory);
  if (memo.isNotEmpty) return memo;

  return '';
}
