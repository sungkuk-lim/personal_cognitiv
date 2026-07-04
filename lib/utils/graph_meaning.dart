import 'memory_detail_text.dart';
import 'memory_entity_extract.dart';
import '../models/memory.dart';
import 'graph_meaning_extract.dart';
import 'ocr_utils.dart';

/// 관계망 제목 — 그날·그 순간의 핵심 의미를 한 문장으로 표현합니다.
String graphMeaningSentence(Memory memory, {required String localeCode}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  if (bundle.eventTitle.isNotEmpty && isMeaningfulGraphSummary(bundle.eventTitle)) {
    return _truncateMeaning(bundle.eventTitle, 58);
  }

  final contentLine = _bestMeaningFromContent(memory.content, localeCode);
  final summary = memory.summary.trim();
  if (contentLine != null) {
    if (summary.isEmpty || !memoryTextsOverlapForDisplay(summary, contentLine)) {
      return _truncateMeaning(contentLine, 58);
    }
  }

  if (isMeaningfulGraphSummary(summary)) {
    return _truncateMeaning(summary, 58);
  }

  if (contentLine != null) {
    return _truncateMeaning(contentLine, 58);
  }

  if (memory.subCategory.trim().isNotEmpty && !isGraphJunkTitle(memory.subCategory)) {
    return _truncateMeaning(memory.subCategory.trim(), 58);
  }

  return _truncateMeaning(_synthesizeMeaningFromSignals(memory, localeCode), 58);
}

/// 같은 날·같은 장소 묶음 허브 제목.
String buildGroupGraphMeaning(List<Memory> memories, {required String localeCode}) {
  if (memories.isEmpty) {
    return localeCode == 'ko' ? '기억 묶음' : 'Memory cluster';
  }
  if (memories.length == 1) {
    return graphMeaningSentence(memories.first, localeCode: localeCode);
  }

  final meanings = memories
      .where((m) => !isGraphMetaContent(m.content.trim()))
      .map((m) => graphMeaningSentence(m, localeCode: localeCode))
      .where((s) => !_isGenericMeaningFallback(s, localeCode))
      .map((s) => s.replaceAll(RegExp(r'[.!?…]+$'), ''))
      .toList();

  if (meanings.isEmpty) {
    final date = _formatShortDate(memories.first.createdAt, localeCode);
    return localeCode == 'ko' ? '$date의 기억들' : 'Memories on $date';
  }

  if (meanings.length == 1) {
    return '${meanings.first}.';
  }

  final joined = meanings.take(3).join(', ');
  final date = _formatShortDate(memories.first.createdAt, localeCode);
  if (localeCode == 'ko') {
    return '$date, $joined 등이 담긴 하루.';
  }
  return '$date — a day with $joined.';
}

String? _bestMeaningFromContent(String raw, String localeCode) {
  final line = extractBestMeaningLineForGraph(raw, localeCode: localeCode);
  if (line.isEmpty || isGraphJunkTitle(line)) return null;
  return line;
}

String? _firstMeaningfulContentLine(String raw) {
  for (final line in raw.split(RegExp(r'[\n\r]+'))) {
    final text = line.trim();
    if (text.isEmpty || isPhotoStyleSummary(text) || isGraphJunkTitle(text) || isGraphMetaContent(text)) {
      continue;
    }
    return text;
  }
  return null;
}

String _polishMeaningSentence(String text, String localeCode) {
  final value = text.trim();
  if (value.isEmpty) return value;
  if (RegExp(r'[.!?…]$').hasMatch(value)) return value;
  return '$value.';
}

String _synthesizeMeaningFromSignals(Memory memory, String localeCode) {
  if (localeCode == 'ko') {
    return switch (memory.category) {
      'Study' => '배움과 성장의 순간.',
      'Social' => '소중한 사람과 함께한 시간.',
      'Food' => '맛과 대화가 있는 식사.',
      'Travel' => '새로운 장소에서의 경험.',
      'Work' => '일과 프로젝트의 진행.',
      'Health' => '몸과 마음을 돌본 순간.',
      'Finance' => '생활과 재정의 기록.',
      _ => '기억에 남는 하루의 한 조각.',
    };
  }
  return switch (memory.category) {
    'Study' => 'A moment of learning.',
    'Social' => 'Time shared with someone meaningful.',
    'Food' => 'A meal worth remembering.',
    'Travel' => 'An experience in a new place.',
    'Work' => 'Progress on work or projects.',
    'Health' => 'A moment for body and mind.',
    'Finance' => 'A note on daily life and money.',
    _ => 'A slice of life worth keeping.',
  };
}

bool _isGenericMeaningFallback(String text, String localeCode) {
  return text == (localeCode == 'ko' ? '기억' : 'Memory');
}

String _formatShortDate(DateTime dt, String localeCode) {
  if (localeCode == 'ko') return '${dt.month}월 ${dt.day}일';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _truncateMeaning(String text, int maxLen) {
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen - 1)}…';
}

/// 음성·텍스트 저장 시 summary에 넣을 핵심 의미 한 문장 (메타데이터 제외).
String buildLocalMemoryMeaningSummary({
  required String speechText,
  required String localeCode,
}) {
  return extractBestMeaningLineForGraph(speechText, localeCode: localeCode);
}
