import 'ocr_utils.dart';

/// 사진 메타(날짜·이름 나열) 형태인지 — 관계망 제목에서 제외.
bool isPhotoStyleSummary(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;

  final hasNameList = RegExp(r'([가-힣]{2,4}\s*,\s*){2,}[가-힣]{2,4}').hasMatch(value);
  final hasDate = RegExp(r'\d{1,2}월\s*\d{1,2}일').hasMatch(value);
  if (hasDate && hasNameList && !_hasPhotoStyleEventLanguage(value)) return true;

  final hasBullet = value.contains('·') || value.contains(',');
  final hasDateTime = hasDate || RegExp(r'\d{1,2}:\d{2}').hasMatch(value);
  return hasBullet && hasDateTime && !_hasPhotoStyleEventLanguage(value);
}

bool _hasPhotoStyleEventLanguage(String text) {
  const hints = ['여행', '실망', '엉망', '사라', '없어', '먹', '갔', '왔', '이상', '추억', '행동'];
  return hints.any(text.contains);
}

/// 관계망·요약용 — 여러 줄 기억에서 사건 중심 한 문장을 고릅니다.
String extractBestMeaningLineForGraph(String raw, {required String localeCode}) {
  final text = raw.trim();
  if (text.isEmpty) {
    return localeCode == 'ko' ? '기억에 남는 순간.' : 'A moment worth remembering.';
  }

  final candidates = _collectMeaningCandidates(text);
  if (candidates.isEmpty) {
    return _polishLine(text.split(RegExp(r'[\n\r]+')).first.trim(), localeCode);
  }

  candidates.sort((a, b) => _scoreMeaningCandidate(b).compareTo(_scoreMeaningCandidate(a)));
  return _polishLine(candidates.first, localeCode);
}

List<String> _collectMeaningCandidates(String raw) {
  final results = <String>[];
  final seen = <String>{};

  void add(String? value) {
    final line = value?.trim() ?? '';
    if (line.isEmpty || isGraphJunkTitle(line) || isGraphMetaContent(line)) return;
    if (seen.add(line)) results.add(line);
  }

  for (final paragraph in raw.split(RegExp(r'[\n\r]+'))) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) continue;

    if (!_isNameListLead(trimmed) && !isPhotoStyleSummary(trimmed)) {
      add(trimmed);
    }

    for (final sentence in trimmed.split(RegExp(r'(?<=[.!?…])\s+|\.{2,}'))) {
      final part = sentence.trim();
      if (part.isEmpty || _isNameListLead(part) || isPhotoStyleSummary(part)) continue;
      add(part);
    }
  }

  return results;
}

bool _isNameListLead(String line) {
  if (RegExp(r'^\d{1,2}월\s*\d{1,2}일\s+[가-힣]{2,4}\s*,').hasMatch(line)) return true;
  if (RegExp(r'^([가-힣]{2,4}\s*,\s*){2,}[가-힣]{2,4}').hasMatch(line) && !_hasEventLanguage(line)) {
    return true;
  }
  return false;
}

bool _hasEventLanguage(String text) {
  const hints = [
    '여행', '실망', '엉망', '사라', '없어', '실종', '이상', '의문', '갈등', '문제',
    '먹', '갔', '왔', '놀', '만나', '추억', '행동', '연락', '집으로',
  ];
  return hints.any(text.contains);
}

int _scoreMeaningCandidate(String line) {
  var score = line.length.clamp(0, 80);

  const strong = ['엉망', '사라', '없어', '실종', '실망', '이상', '의문', '갈등', '충격', '화가', '슬펐', '회식', '병원'];
  const medium = ['여행', '추억', '밤', '대호', '연숙', '회의', '교육', '워크숍'];
  const weak = ['다음날', '연락이 왔', '집으로 갔', '혼자', '탕수육', '자장면', '술'];

  for (final h in strong) {
    if (line.contains(h)) score += 18;
  }
  for (final h in medium) {
    if (line.contains(h)) score += 6;
  }
  for (final h in weak) {
    if (line.contains(h)) score -= 22;
  }
  if (_isNameListLead(line)) score -= 30;
  if (RegExp(r'^\d{1,2}월\s*\d{1,2}일').hasMatch(line) && line.contains(',')) score -= 12;

  return score;
}

String _polishLine(String text, String localeCode) {
  final value = text.trim();
  if (value.isEmpty) return localeCode == 'ko' ? '기억에 남는 순간.' : 'A moment worth remembering.';
  if (RegExp(r'[.!?…]$').hasMatch(value)) return value;
  return '$value.';
}

bool isMeaningfulGraphSummary(String summary) {
  if (summary.isEmpty || isGraphJunkTitle(summary) || isPhotoStyleSummary(summary)) {
    return false;
  }

  final commaParts = summary.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (commaParts.length >= 3 && !summary.contains('.')) return false;

  if (RegExp(r'\d{1,2}:\d{2}').hasMatch(summary) && (summary.contains('·') || summary.contains(','))) {
    return false;
  }

  return summary.length >= 6;
}
