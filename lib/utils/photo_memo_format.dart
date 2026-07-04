import '../models/memory.dart';
import 'photo_memory_format.dart';
import 'ocr_utils.dart';
import 'voice_memory_format.dart';

/// 사용자 메모(이름·장소 등)를 사진 기억 필드에 합칩니다.
PhotoMemoryFields enrichPhotoFieldsWithUserMemo({
  required PhotoMemoryFields fields,
  required String userMemo,
  required DateTime capturedAt,
  required String localeCode,
  String? gpsPlace,
}) {
  final memo = userMemo.trim();
  if (memo.isEmpty) return fields;

  final memoPeople = extractPeopleNamesFromSpeech(memo);
  final memoPlace = extractPlaceHintFromOcr(memo);
  final entities = sanitizeEntities([
    ...memoPeople,
    ...fields.entities,
    if (memoPlace != null && memoPlace.isNotEmpty) memoPlace,
    if (gpsPlace != null && gpsPlace.trim().isNotEmpty) gpsPlace.trim(),
  ]);

  return PhotoMemoryFields(
    // 메모는 관계망 연결(엔티티)에만 쓰고, 제목/본문은 기본 사진 분석 값을 유지합니다.
    summary: fields.summary,
    content: fields.content,
    entities: entities,
    category: fields.category == 'Other' ? inferVoiceCategory(memo, speechPlace: memoPlace, gpsPlace: gpsPlace) : fields.category,
    subCategory: fields.subCategory,
  );
}

/// 추가 사진 메모로 엔티티만 갱신합니다. (본문·userMemo에는 넣지 않음)
Memory mergeEntitiesFromPhotoMemo(Memory memory, String memo) {
  final trimmed = memo.trim();
  if (trimmed.isEmpty) return memory;

  final people = extractPeopleNamesFromSpeech(trimmed);
  final place = extractPlaceHintFromOcr(trimmed);
  final entities = sanitizeEntities([
    ...people,
    ...memory.entities,
    if (place != null && place.isNotEmpty) place,
  ]);

  return memory.copyWith(entities: entities);
}

/// 추가 사진·메모 반영 시 기억의 엔티티·본문을 갱신합니다.
Memory mergeMemoIntoMemory(Memory memory, {String? additionalMemo}) {
  final memo = additionalMemo?.trim() ?? '';
  if (memo.isEmpty) return memory;

  final mergedMemo = [memory.userMemo, memo].where((s) => s.trim().isNotEmpty).join('\n');
  final people = extractPeopleNamesFromSpeech(mergedMemo);
  final place = extractPlaceHintFromOcr(mergedMemo);
  final entities = sanitizeEntities([
    ...people,
    ...memory.entities,
    if (place != null && place.isNotEmpty) place,
  ]);

  final contentParts = <String>[
    mergedMemo,
    if (memory.content.trim().isNotEmpty && !memory.content.startsWith(mergedMemo)) memory.content,
  ];

  return memory.copyWith(
    userMemo: mergedMemo,
    entities: entities,
    content: contentParts.join('\n'),
  );
}
