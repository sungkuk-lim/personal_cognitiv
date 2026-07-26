import '../data/care_entity_dictionary.dart';

/// ② STT 후 사투리·오타·띄어쓰기 정규화 (로컬, AI 없음).
class DialectNormalizeService {
  const DialectNormalizeService._();

  static String normalize(String raw, {CareEntityDictionary? dictionary}) {
    final dict = dictionary ?? CareEntityDictionary.seed();
    var text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');

    for (final entry in dict.sttTypoMap.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    // 병원명 붙여쓰기: "성소 병원" → 사전에 있으면 이미 처리됨.
    text = text.replaceAllMapped(
      RegExp(r'([가-힣A-Za-z0-9]{2,12})\s+(병원|의원|클리닉)'),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // 흔한 구어 축약
    const colloquial = {
      '갔어요': '갔어',
      '했어요': '했어',
      '입니다': '',
      '거든요': '',
    };
    for (final entry in colloquial.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    return text.trim();
  }
}
