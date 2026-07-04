/// 음성·텍스트에서 상대 날짜(어제·그제 등)를 추출합니다.
int? relativeDayOffsetFromText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  if (RegExp(r'그제|그저께').hasMatch(trimmed)) return -2;
  if (RegExp(r'어제').hasMatch(trimmed)) return -1;
  if (RegExp(r'오늘').hasMatch(trimmed)) return 0;
  if (RegExp(r'내일').hasMatch(trimmed)) return 1;

  return null;
}

DateTime applyRelativeDayOffset(DateTime base, int dayOffset) {
  final shifted = base.add(Duration(days: dayOffset));
  return DateTime(shifted.year, shifted.month, shifted.day, base.hour, base.minute, base.second);
}

String relativeDayLabel(int dayOffset, String localeCode) {
  if (localeCode == 'ko') {
    return switch (dayOffset) {
      -2 => '그제',
      -1 => '어제',
      0 => '오늘',
      1 => '내일',
      _ => '$dayOffset일',
    };
  }
  return switch (dayOffset) {
    -2 => 'two days ago',
    -1 => 'yesterday',
    0 => 'today',
    1 => 'tomorrow',
    _ => '$dayOffset days',
  };
}
