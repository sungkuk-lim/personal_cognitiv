import 'graph_meaning_extract.dart';
import 'memory_entity_extract.dart';

import 'korean_person_names.dart';

import 'photo_memory_format.dart';

import 'graph_meaning.dart';

import 'ocr_utils.dart';



/// 음성 기억에서 인물·장소·GPS를 정리해 사진 기억과 같은 형식으로 저장합니다.

PhotoMemoryFields buildVoiceMemoryFields({

  required String speechText,

  required DateTime capturedAt,

  required String localeCode,

  String? gpsPlace,

}) {

  final trimmed = speechText.trim();

  final speechPlace = extractPlaceHintFromOcr(trimmed);

  final people = extractPeopleFromMemoryText(trimmed);

  final summary = extractEventTitleFromText(trimmed, localeCode: localeCode);
  final resolvedSummary = summary.isNotEmpty
      ? summary
      : extractBestMeaningLineForGraph(trimmed, localeCode: localeCode);



  final entities = buildVoiceGraphEntities(

    speechPlace: speechPlace,

    gpsPlace: gpsPlace,

    peopleNames: people,

  );



  final category = inferVoiceCategory(trimmed, speechPlace: speechPlace, gpsPlace: gpsPlace);

  final subCategory = localeCode == 'ko'

      ? (category == 'Travel' ? '나들이·장소' : category == 'Social' ? '함께한 순간' : '음성 기억')

      : (category == 'Travel' ? 'Outing' : category == 'Social' ? 'Together' : 'Voice memory');



  return PhotoMemoryFields(

    summary: resolvedSummary,

    content: trimmed,

    entities: entities,

    category: category,

    subCategory: subCategory,

  );

}



/// 클라우드 AI 분류 결과와 로컬 인물·장소 추출을 합칩니다.

PhotoMemoryFields mergeVoiceFieldsWithAi({

  required PhotoMemoryFields localFields,

  required Map<String, dynamic> aiData,

}) {

  final aiEntities = sanitizeEntities(List<String>.from(aiData['entities'] ?? []))

      .where((e) => !isNonPlaceGraphToken(e) && (isLikelyKoreanPersonName(e) || looksLikeKoreanPlaceName(e) || e.length > 4))

      .toList();

  final mergedEntities = sanitizeEntities([

    ...localFields.entities,

    ...aiEntities,

  ]);



  final aiSummary = (aiData['summary'] as String? ?? '').trim();

  final localSummary = localFields.summary.trim();

  final summary = aiSummary.isNotEmpty && isMeaningfulGraphSummary(aiSummary)

      ? aiSummary

      : (localSummary.isNotEmpty ? localSummary : aiSummary);



  return PhotoMemoryFields(

    summary: summary.isNotEmpty ? summary : localFields.summary,

    content: localFields.content,

    entities: mergedEntities,

    category: (aiData['category'] as String?)?.trim().isNotEmpty == true

        ? aiData['category'] as String

        : localFields.category,

    subCategory: (aiData['sub_category'] as String?)?.trim().isNotEmpty == true

        ? aiData['sub_category'] as String

        : localFields.subCategory,

  );

}



List<String> buildVoiceGraphEntities({

  String? speechPlace,

  String? gpsPlace,

  List<String> peopleNames = const [],

}) {

  final merged = <String>[

    ...sanitizeEntities(peopleNames),

  ];



  void addPlace(String? value) {

    final place = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

    if (place.isEmpty || place.length > 22 || isJunkEntityOrKeyword(place) || isGenericPhotoLabel(place)) return;

    if (isNonPlaceGraphToken(place)) return;

    if (RegExp(r'(?:연락|집으로|다음날|행동)').hasMatch(place)) return;

    merged.add(place);

  }



  addPlace(speechPlace);

  final gps = gpsPlace?.trim() ?? '';

  final speech = speechPlace?.trim() ?? '';

  if (gps.isNotEmpty && gps != speech) {

    addPlace(gps);

  }



  return sanitizeEntities(merged);

}



List<String> extractPeopleNamesFromSpeech(String text) => extractPeopleFromMemoryText(text);



String inferVoiceCategory(

  String text, {

  String? speechPlace,

  String? gpsPlace,

}) {

  final hasPlace = (speechPlace?.trim().isNotEmpty ?? false) || (gpsPlace?.trim().isNotEmpty ?? false);

  if (hasPlace) return 'Travel';



  const socialHints = ['친구', '만났', '놀러', '식사', '점심', '저녁', '술', '함께', '같이'];

  if (socialHints.any(text.contains)) return 'Social';



  return 'Other';

}


