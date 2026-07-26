import '../../models/memory.dart';
import '../../utils/entity_canonical.dart';
import '../../utils/korean_person_names.dart';
import '../../utils/memory_entity_cache.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/memory_place_cache.dart';

/// 사람 노드 상세 카드용 집계.
class PersonGraphStats {
  const PersonGraphStats({
    required this.personName,
    required this.memoryCount,
    required this.photoCount,
    required this.topPlaces,
    this.lastMemoryAt,
    required this.strengthStars,
  });

  final String personName;
  final int memoryCount;
  final int photoCount;
  final List<String> topPlaces;
  final DateTime? lastMemoryAt;
  final int strengthStars;
}

PersonGraphStats computePersonGraphStats({
  required String personName,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, String> placeCache,
  required Map<String, String> fullAddressCache,
  String localeCode = 'ko',
}) {
  final linked = <Memory>[];
  for (final m in memories) {
    if (memoryMatchesKeyword(m, personName, localeCode: localeCode)) {
      linked.add(m);
    }
  }

  var photos = 0;
  final placeCounts = <String, int>{};
  DateTime? lastAt;

  for (final m in linked) {
    photos += imageCountForMemoryId(m.id, imagePaths);
    if (lastAt == null || m.createdAt.isAfter(lastAt)) lastAt = m.createdAt;

    final bundle = MemoryEntityCache.bundle(m, localeCode: localeCode);
    for (final place in bundle.places) {
      placeCounts[place] = (placeCounts[place] ?? 0) + 1;
    }
    final addr = displayPlaceAddress(
      m,
      placeCache,
      fullAddressCache,
      localeCode: localeCode,
    );
    if (addr.isNotEmpty && addr != (localeCode == 'ko' ? '장소 미상' : 'Unknown place')) {
      placeCounts[addr] = (placeCounts[addr] ?? 0) + 1;
    }
  }

  final topPlaces = placeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final count = linked.length;
  final stars = count >= 20
      ? 5
      : count >= 12
          ? 4
          : count >= 6
              ? 3
              : count >= 2
                  ? 2
                  : count >= 1
                      ? 1
                      : 0;

  return PersonGraphStats(
    personName: personName,
    memoryCount: count,
    photoCount: photos,
    topPlaces: topPlaces.take(4).map((e) => e.key).toList(),
    lastMemoryAt: lastAt,
    strengthStars: stars,
  );
}

String personStatsMemoryLabel(int count, String localeCode) =>
    localeCode == 'ko' ? '추억 $count개' : '$count memories';

String personStatsPhotoLabel(int count, String localeCode) =>
    localeCode == 'ko' ? '사진 $count장' : '$count photos';
