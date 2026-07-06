import '../utils/memory_query.dart';

/// 복합 검색 차원 수 (사람·장소·감정·활동·사진·기간 등).
int compositeQueryDimensionCount(MemoryQuery query) {
  var n = 0;
  if (query.people.isNotEmpty) n++;
  if (query.places.isNotEmpty) n++;
  if (query.emotions.isNotEmpty) n++;
  if (query.activities.isNotEmpty) n++;
  if (query.foods.isNotEmpty) n++;
  if (query.hobbies.isNotEmpty) n++;
  if (query.seasons.isNotEmpty) n++;
  if (query.weathers.isNotEmpty) n++;
  if (query.hasPhoto == true) n++;
  if (query.hasVideo == true) n++;
  if (query.subCategory != null && query.subCategory!.isNotEmpty) n++;
  if (query.dateStart != null || query.dateEnd != null) n++;
  return n;
}

/// Phase 2 — 2개 이상 조건 AND 검색, 또는 2명 이상 인물 검색은 Pro.
bool requiresProForMemoryQuery(MemoryQuery query) {
  if (!query.isComposite) return false;
  if (query.people.length >= 2) return true;
  return compositeQueryDimensionCount(query) >= 2;
}
