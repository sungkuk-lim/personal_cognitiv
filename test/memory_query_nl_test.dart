import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/memory_query.dart';

void main() {
  test('natural language: today + photo intent', () {
    final q = parseNaturalLanguageQuery('오늘 찍은 사진 있어?', localeCode: 'ko');
    expect(q.hasPhoto, isTrue);
    expect(q.dateStart, isNotNull);
    final start = q.dateStart!;
    final now = DateTime.now();
    expect(start.year, now.year);
    expect(start.month, now.month);
    expect(start.day, now.day);
  });

  test('natural language: dinner place with person', () {
    final q = parseNaturalLanguageQuery('민수랑 먹었던 식당 어디였지?', localeCode: 'ko');
    expect(q.people, contains('민수'));
    expect(q.places.any((p) => p.contains('식당')), isTrue);
  });

  test('natural language: yesterday with mom', () {
    final q = parseNaturalLanguageQuery('어제 엄마랑', localeCode: 'ko');
    expect(q.people, contains('엄마'));
    expect(q.dateStart, isNotNull);
  });
}
