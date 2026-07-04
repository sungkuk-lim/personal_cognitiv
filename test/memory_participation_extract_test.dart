import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/utils/memory_participation_extract.dart';

const _gilancheonTrip = '''2026년 6월 22일 아버지, 어머니, 나, 집사람, 예린이, 태민이 이렇게 6명이서 길안천에 놀러갔었어 다슬기를 잡을 려고 식두들이 신이 났어
아버지와 어머니는 고스톰을 치며 시간을 보내셨고 나, 집사람, 예린이, 태민이는 다슬기를 잡아 다슬기 국을 끊여 먹으며 즐거운 시간을 보냈어''';

void main() {
  test('extracts father-mother gostum and family clamming cohorts', () {
    const activities = {'고스톰', '다슬기 잡기'};
    final links = extractParticipationLinks(
      _gilancheonTrip,
      localeCode: 'ko',
      knownActivities: activities,
    );

    expect(links.any((l) => l.person == '아버지' && l.activity == '고스톰'), isTrue);
    expect(links.any((l) => l.person == '어머니' && l.activity == '고스톰'), isTrue);
    expect(links.any((l) => l.person == '나' && l.activity == '다슬기 잡기'), isTrue);
    expect(links.any((l) => l.person == '집사람' && l.activity == '다슬기 잡기'), isTrue);
    expect(links.any((l) => l.person == '예린' && l.activity == '다슬기 잡기'), isTrue);
    expect(links.any((l) => l.person == '태민' && l.activity == '다슬기 잡기'), isTrue);
  });
}
