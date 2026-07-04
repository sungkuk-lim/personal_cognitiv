import '../models/memory.dart';
import 'graph_meaning.dart';
import 'memory_grouping.dart';
import 'memory_place_cache.dart';
import 'ocr_utils.dart';
import 'photo_memory_format.dart';
import 'voice_memory_format.dart';

/// 관계망 기억 카드 3줄: 핵심 의미 / 날짜·시간·장소 / 상세주소.
class GraphMemoryCardLabels {
  const GraphMemoryCardLabels({
    required this.meaningLine,
    required this.metaLine,
    required this.addressLine,
  });

  final String meaningLine;
  final String metaLine;
  final String addressLine;
}

GraphMemoryCardLabels buildGraphMemoryCardLabels(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
}) {
  return GraphMemoryCardLabels(
    meaningLine: graphMeaningSentence(memory, localeCode: localeCode),
    metaLine: graphMemoryMetaLine(memory, placeCache, fullAddressCache, localeCode: localeCode),
    addressLine: graphMemoryAddressLine(memory, placeCache, fullAddressCache),
  );
}

GraphMemoryCardLabels buildGroupGraphCardLabels(
  MemoryTimelineGroup group,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
}) {
  final meaning = buildGroupGraphMeaning(group.memories, localeCode: localeCode);
  final metaSource = _bestMemoryForMeta(group.memories);
  var addressLine = '';
  for (final memory in group.memories) {
    final candidate = graphMemoryAddressLine(memory, placeCache, fullAddressCache);
    if (candidate.isNotEmpty) {
      addressLine = candidate;
      break;
    }
  }

  return GraphMemoryCardLabels(
    meaningLine: meaning,
    metaLine: graphMemoryMetaLine(metaSource, placeCache, fullAddressCache, localeCode: localeCode),
    addressLine: addressLine,
  );
}

Memory _bestMemoryForMeta(List<Memory> memories) {
  for (final memory in memories) {
    if (extractPlaceHintFromOcr(memory.content) != null) return memory;
  }
  for (final memory in memories) {
    if (memory.lat != null && memory.lng != null) return memory;
  }
  return memories.first;
}

/// @deprecated Use [graphMeaningSentence].
String graphMemoryContentTitle(Memory memory, {required String localeCode}) =>
    graphMeaningSentence(memory, localeCode: localeCode);

String graphMemoryMetaLine(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
}) {
  final parts = <String>[];

  void addPart(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return;
    if (parts.contains(text)) return;
    parts.add(text);
  }

  addPart(_formatGraphDate(memory.createdAt, localeCode));
  addPart(_formatGraphTime(memory.createdAt));
  addPart(_speechPlaceForGraph(memory));

  return parts.join(', ');
}

String graphMemoryAddressLine(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache,
) {
  final full = fullAddressFromCache(memory, fullAddressCache);
  if (full != null && full.isNotEmpty) return full;

  final short = placeNameFromCache(memory, placeCache);
  if (short != null && short.isNotEmpty && !isLikelyLotNumber(short) && !isLatLngLabel(short)) {
    return short;
  }
  return '';
}

String? _speechPlaceForGraph(Memory memory) {
  final people = extractPeopleNamesFromSpeech(memory.content).toSet();

  final fromSpeech = extractPlaceHintFromOcr(memory.content);
  if (fromSpeech != null && fromSpeech.isNotEmpty && !people.contains(fromSpeech)) {
    return fromSpeech;
  }

  for (final entity in sanitizeEntities(memory.entities)) {
    if (people.contains(entity)) continue;
    if (isLatLngLabel(entity) || isLikelyLotNumber(entity)) continue;
    if (_looksLikePlaceToken(entity) || entity.endsWith('리')) return entity;
  }

  final fromEntity = placeLabelFromEntities(memory);
  if (fromEntity != null && !people.contains(fromEntity)) return fromEntity;
  return null;
}

bool _looksLikePlaceToken(String word) {
  const suffixes = ['리', '동', '로', '길', '역', '산', '교', '공원', '해변', '시', '군', '읍', '면'];
  return suffixes.any(word.endsWith);
}

String _formatGraphDate(DateTime dt, String localeCode) {
  if (localeCode == 'ko') return '${dt.month}월 ${dt.day}일';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _formatGraphTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String localeFallbackTitle({required String localeCode}) {
  return localeCode == 'ko' ? '기억' : 'Memory';
}
