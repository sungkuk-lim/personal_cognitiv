/// 방문간호·외진 등 업무 유형 — 유형별 분석기·프롬프트 라우팅에 사용.
enum MemoryWorkType {
  homeVisitMedical,
  social,
  travel,
  workGeneral,
  general,
}

const String kWorkTypeTagPrefix = 'tag:work:';

String workTypeTag(MemoryWorkType type) => '$kWorkTypeTagPrefix${type.name}';

MemoryWorkType? workTypeFromEntityTag(String tag) {
  if (!tag.startsWith(kWorkTypeTagPrefix)) return null;
  final name = tag.substring(kWorkTypeTagPrefix.length);
  for (final t in MemoryWorkType.values) {
    if (t.name == name) return t;
  }
  return null;
}

String workTypeCategory(MemoryWorkType type) {
  return switch (type) {
    MemoryWorkType.homeVisitMedical => 'Health',
    MemoryWorkType.social => 'Social',
    MemoryWorkType.travel => 'Travel',
    MemoryWorkType.workGeneral => 'Work',
    MemoryWorkType.general => 'Other',
  };
}

String workTypeSubCategoryLabel(MemoryWorkType type, {String localeCode = 'ko'}) {
  if (localeCode != 'ko') {
    return switch (type) {
      MemoryWorkType.homeVisitMedical => 'Home visit / outreach',
      MemoryWorkType.social => 'Social',
      MemoryWorkType.travel => 'Travel',
      MemoryWorkType.workGeneral => 'Work',
      MemoryWorkType.general => 'General',
    };
  }
  return switch (type) {
    MemoryWorkType.homeVisitMedical => '방문·외진',
    MemoryWorkType.social => '함께한 순간',
    MemoryWorkType.travel => '나들이·장소',
    MemoryWorkType.workGeneral => '업무',
    MemoryWorkType.general => '음성 기억',
  };
}
