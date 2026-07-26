import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import 'memory_detail_text.dart';
import 'graph_meaning_extract.dart';
import 'memory_entity_extract.dart';
import 'ocr_utils.dart';

/// 관계망 제목 — 그날·그 순간의 핵심 의미를 한 문장으로 표현합니다.
String graphMeaningSentence(Memory memory, {required String localeCode}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  final hub = bundle.eventTitle.trim();

  if (hub.isNotEmpty && isChipStyleHubTitle(hub)) {
    final line = extractBestMeaningLineForGraph(memory.content, localeCode: localeCode);
    if (line.isNotEmpty && !_isGenericMeaningFallback(line, localeCode)) {
      return _truncateMeaning(line, 58);
    }
  }

  if (hub.isNotEmpty &&
      isMeaningfulHubTitle(hub, localeCode: localeCode) &&
      !_shouldPreferIncidentMeaningOverHubTitle(memory.content, hub)) {
    // 「저녁 먹음」처럼 압축된 허브보다, 짧은 한 문장 원문을 우선합니다.
    final contentLine = _firstMeaningfulContentLine(memory.content);
    if (contentLine != null &&
        !memoryTextHasMultipleClauses(memory.content) &&
        contentLine.length <= 48 &&
        hub.replaceAll(RegExp(r'[.!?…]+$'), '').length + 3 < contentLine.length &&
        !hub.contains('·')) {
      return _truncateMeaning(_polishMeaningSentence(contentLine, localeCode), 58);
    }
    return _truncateMeaning(hub, 58);
  }

  if (_hasIncidentLanguage(memory.content)) {
    final incident = extractBestMeaningLineForGraph(memory.content, localeCode: localeCode);
    if (incident.isNotEmpty && !_isGenericMeaningFallback(incident, localeCode)) {
      return _truncateMeaning(incident, 58);
    }
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

/// 타임라인·회상·검색 카드에 쓰는 통일 제목.
String memoryDisplayTitle(Memory memory, {required String localeCode}) {
  if (isGraphNoteMemory(memory)) {
    final fact = graphNoteFactTitle(memory);
    if (fact.isNotEmpty) return fact;
  }
  return graphMeaningSentence(memory, localeCode: localeCode);
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
  final composed = composeMemoryHubTitle(raw, localeCode: localeCode);
  if (isMeaningfulHubTitle(composed, localeCode: localeCode)) return composed;
  final line = hubTitleFromContentLine(raw, localeCode: localeCode);
  if (line.isNotEmpty) return line;
  return null;
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
  return isGenericHubTitle(text, localeCode: localeCode);
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

bool _hasIncidentLanguage(String text) {
  return RegExp(r'실망|엉망|없어|사라|연락|이상|의문|갈등|문제|실종').hasMatch(text);
}

/// 사건·갈등 본문이 있을 때 음식·여행 키워드만 모은 허브 제목보다 본문 의미를 우선합니다.
bool _shouldPreferIncidentMeaningOverHubTitle(String content, String hubTitle) {
  if (!_hasIncidentLanguage(content)) return false;
  final hub = hubTitle.replaceAll(RegExp(r'[.!?…]+$'), '').trim();
  if (hub.isEmpty) return false;
  if (_hasIncidentLanguage(hub)) return false;
  return true;
}

/// 음성·텍스트 저장 시 summary에 넣을 핵심 의미 한 문장 (메타데이터 제외).
String buildLocalMemoryMeaningSummary({
  required String speechText,
  required String localeCode,
}) {
  return extractBestMeaningLineForGraph(speechText, localeCode: localeCode);
}
