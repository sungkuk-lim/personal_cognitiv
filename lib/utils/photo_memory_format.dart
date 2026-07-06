import '../models/image_memory_analysis.dart';
import 'korean_person_names.dart';
import 'ocr_utils.dart';

class PhotoMemoryFields {
  const PhotoMemoryFields({
    required this.summary,
    required this.content,
    required this.entities,
    required this.category,
    required this.subCategory,
  });

  final String summary;
  final String content;
  final List<String> entities;
  final String category;
  final String subCategory;
}

String formatPhotoCaptureTime(DateTime capturedAt, String localeCode) {
  final h = capturedAt.hour.toString().padLeft(2, '0');
  final m = capturedAt.minute.toString().padLeft(2, '0');
  if (localeCode == 'ko') {
    return '${capturedAt.month}월 ${capturedAt.day}일 $h:$m';
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[capturedAt.month - 1]} ${capturedAt.day}, $h:$m';
}

String unknownPlaceLabel(String localeCode) =>
    localeCode == 'ko' ? '장소 미상' : 'Unknown place';

/// OCR·표지판·음성에서 장소명 후보 추출 (종성로, 월영교, 광안리 해수욕장 등).
String? extractPlaceHintFromOcr(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final cityBridge = RegExp(r'([가-힣]{2,6})\s+([가-힣]{2,8}교)').firstMatch(trimmed);
  if (cityBridge != null) {
    return '${cityBridge.group(1)} ${cityBridge.group(2)}';
  }

  final candidates = <String>[];

  void consider(String? raw) {
    final value = raw?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (value.length < 2 || value.length > 22) return;
    if (isJunkOcrMetaResponse(value) || isGraphMetaContent(value)) return;
    if (isNonPlaceGraphToken(value)) return;
    if (isJunkEntityOrKeyword(value)) return;
    if (RegExp(r'(?:연락|집으로|다음날|실망|엉망|없어|행동|의문|이렇게|명이서|놀러)').hasMatch(value)) return;
    if (RegExp(r'\d').hasMatch(value) && !_placeHintAllowsDigits(value)) return;
    if (value.contains('의 ')) return;
    if (peopleNoiseInPlaceHint(value)) return;
    if (isMisleadingPlaceChonToken(value)) return;
    if (isGraphMorphologyJunkToken(value)) return;
    candidates.add(value);
  }

  // 도시 + 교·대교 (경주 월영교 등).
  for (final match in RegExp(r'([가-힣]{2,6})\s+([가-힣]{2,8}(?:교|대교))').allMatches(trimmed)) {
    consider('${match.group(1)} ${match.group(2)}');
  }

  // 짧은 지명 우선 (길안천에, 월영교에서).
  for (final match in RegExp(r'([가-힣]{2,8}(?:천|산|강|교|봉|령|고개|호|해변|공원|계곡|바다|해수욕장))(?=에\s|에서\s|으로\s|에$|에서$)').allMatches(trimmed)) {
    consider(match.group(1));
  }

  final placeSuffix = RegExp(
    r'([가-힣A-Za-z0-9\s]{2,}(?:중화요리집|요리집|해수욕장|해변|공원|시장|역|대교|교|산|봉|령|고개|강|천|호|로|길|거리|마을|리|동|읍|면|식당|카페))',
  );

  for (final line in trimmed.split(RegExp(r'[\n\r]+'))) {
    for (final match in placeSuffix.allMatches(line.trim())) {
      consider(match.group(1));
    }
  }

  for (final match in placeSuffix.allMatches(trimmed)) {
    consider(match.group(1));
  }

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) => _placeCandidateScore(b).compareTo(_placeCandidateScore(a)));
  return candidates.first;
}

bool peopleNoiseInPlaceHint(String value) {
  return RegExp(r'(?:참석|보호사|간호사|이동|서충|이렇게|명이서|식구)').hasMatch(value);
}

bool _placeHintAllowsDigits(String value) =>
    RegExp(r'(?:로|길|거리)\s*\d').hasMatch(value) || RegExp(r'\d+\s*길').hasMatch(value);

int _placeCandidateScore(String place) {
  var score = 0;
  if (place.contains('해수욕장')) score += 24;
  if (place.contains('해변') || place.contains('공원') || place.contains('계곡')) score += 16;
  if (place.endsWith('천') || place.endsWith('산') || place.endsWith('교')) score += 14;
  if (place.length <= 5) score += 22;
  if (place.length <= 8) score += 8;
  if (place.length >= 12) score -= 24;
  if (place.split(' ').length > 1) score -= 14;
  if (place.endsWith('리') && place.length <= 4) score -= 8;
  return score;
}

String? pickPrimaryPlaceLabel({
  String? visionPlace,
  List<String> landmarks = const [],
  String? ocrPlace,
  String? gpsPlace,
  String localeCode = 'ko',
}) {
  for (final candidate in [visionPlace, ...landmarks, ocrPlace, gpsPlace]) {
    final value = candidate?.trim() ?? '';
    if (value.isEmpty || isJunkEntityOrKeyword(value) || isGenericPhotoLabel(value)) continue;
    return value;
  }
  return null;
}

bool isGenericPhotoLabel(String text) {
  final v = text.trim().toLowerCase();
  const junk = [
    '기기에 저장된 사진',
    'photo on device',
    '사진',
    'photo',
    'image',
    '기기',
    'device',
    '저장됨',
    'stored',
  ];
  return junk.contains(v) || junk.any((j) => v.contains(j.toLowerCase()));
}

String buildPhotoDisplayTitle({
  required String? placeLabel,
  required DateTime capturedAt,
  required String localeCode,
  List<String> peopleNames = const [],
}) {
  final place = (placeLabel != null && placeLabel.trim().isNotEmpty)
      ? placeLabel.trim()
      : unknownPlaceLabel(localeCode);
  final time = formatPhotoCaptureTime(capturedAt, localeCode);
  final people = sanitizeEntities(peopleNames);
  if (people.isNotEmpty) {
    return '$place · ${people.take(2).join(', ')} · $time';
  }
  return '$place · $time';
}

List<String> buildPhotoGraphEntities({
  required String? placeLabel,
  List<String> peopleNames = const [],
  List<String> landmarks = const [],
  List<String> visionEntities = const [],
  String? ocrText,
}) {
  final fromOcr = ocrText != null ? extractKeywordsFromText(ocrText) : const <String>[];
  final merged = <String>[
    ...sanitizeEntities(peopleNames),
    if (placeLabel != null && placeLabel.trim().isNotEmpty) placeLabel.trim(),
    ...sanitizeEntities(landmarks),
    ...sanitizeEntities(visionEntities),
    ...fromOcr,
  ];
  return sanitizeEntities(merged);
}

PhotoMemoryFields buildPhotoMemoryFieldsLocal({
  required DateTime capturedAt,
  required String localeCode,
  String? gpsPlace,
  String? ocrText,
}) {
  final ocrPlace = ocrText != null ? extractPlaceHintFromOcr(ocrText) : null;
  final place = pickPrimaryPlaceLabel(ocrPlace: ocrPlace, gpsPlace: gpsPlace, localeCode: localeCode);
  final summary = buildPhotoDisplayTitle(
    placeLabel: place,
    capturedAt: capturedAt,
    localeCode: localeCode,
  );
  final entities = buildPhotoGraphEntities(placeLabel: place, ocrText: ocrText);
  final content = [
    if (ocrText != null && ocrText.trim().isNotEmpty) ocrText.trim(),
    summary,
  ].join('\n');

  return PhotoMemoryFields(
    summary: summary,
    content: content.isNotEmpty ? content : summary,
    entities: entities,
    category: 'Travel',
    subCategory: localeCode == 'ko' ? '풍경·장소' : 'Scenery',
  );
}

PhotoMemoryFields buildPhotoMemoryFieldsFromVision({
  required ImageMemoryAnalysis analysis,
  required DateTime capturedAt,
  required String localeCode,
  String? gpsPlace,
}) {
  final ocrPlace = analysis.extractedText.isNotEmpty
      ? extractPlaceHintFromOcr(analysis.extractedText)
      : null;
  final place = pickPrimaryPlaceLabel(
    visionPlace: analysis.placeName,
    landmarks: analysis.landmarks,
    ocrPlace: ocrPlace,
    gpsPlace: gpsPlace,
    localeCode: localeCode,
  );

  final people = sanitizeEntities(analysis.peopleNames);
  final summary = buildPhotoDisplayTitle(
    placeLabel: place,
    capturedAt: capturedAt,
    localeCode: localeCode,
    peopleNames: analysis.photoType == 'portrait' ? people : const [],
  );

  final entities = buildPhotoGraphEntities(
    placeLabel: place,
    peopleNames: people,
    landmarks: analysis.landmarks,
    visionEntities: analysis.entities,
    ocrText: analysis.extractedText,
  );

  final sceneDescription = analysis.summary.trim();
  final content = [
    if (analysis.extractedText.isNotEmpty) analysis.extractedText,
    if (sceneDescription.isNotEmpty && !isJunkOcrMetaResponse(sceneDescription)) sceneDescription,
    summary,
  ].join('\n');

  var category = analysis.category;
  if (analysis.photoType == 'portrait') category = 'Social';
  if (analysis.photoType == 'landscape') category = 'Travel';

  return PhotoMemoryFields(
    summary: summary,
    content: content.isNotEmpty ? content : summary,
    entities: entities,
    category: category,
    subCategory: analysis.subCategory.isNotEmpty
        ? analysis.subCategory
        : (localeCode == 'ko' ? '사진 기억' : 'Photo memory'),
  );
}
