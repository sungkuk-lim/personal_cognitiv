import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';

void main() {
  test('extractGraphSatellites finds people places activities goals', () {
    final memory = Memory(
      id: '1',
      content: '어머니와 저녁을 먹었다.',
      summary: '',
      entities: const ['어머니'],
      category: 'Social',
      createdAt: DateTime(2026, 6, 17, 21, 27),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.people, contains('어머니'));
    expect(satellites.activities, isNot(contains('어머니와 저녁')));
  });

  test('extractGraphSatellites finds place and goal from travel memory', () {
    final memory = Memory(
      id: '2',
      content: '광안리에서 일몰을 봤다.',
      summary: '',
      entities: const ['광안리'],
      category: 'Travel',
      createdAt: DateTime(2026, 6, 17, 21, 27),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.places, contains('광안리'));
    expect(satellites.activities, isNotEmpty);
  });

  test('extractGraphSatellites finds goal from completion phrase', () {
    final memory = Memory(
      id: '3',
      content: '앱 로고를 완성했다.',
      summary: '',
      entities: const [],
      category: 'Work',
      createdAt: DateTime(2026, 6, 17, 22),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.goals, contains('앱 로고'));
  });

  test('extractGraphSatellites does not classify person as place', () {
    final memory = Memory(
      id: '4',
      content: '어머니와 저녁을 먹었다.',
      summary: '',
      entities: const ['어머니'],
      category: 'Social',
      createdAt: DateTime(2026, 6, 17, 21, 27),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.people, contains('어머니'));
    expect(satellites.places, isNot(contains('어머니')));
  });

  test('person cafe memory splits into person and place not composite activity', () {
    final memory = Memory(
      id: 'cafe',
      content: '철수와 카페에서 3시간 이야기.',
      summary: '',
      entities: const ['철수', '카페'],
      category: 'Social',
      subCategory: '친구',
      createdAt: DateTime(2026, 6, 17, 15),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.people, contains('철수'));
    expect(satellites.places, contains('카페'));
    expect(satellites.activities, isNot(contains('철수와 카페')));
    expect(satellites.activities.where((a) => a.contains('카페')), isEmpty);
  });

  test('peopleNotEmbeddedInPairActivities hides duplicate person satellites', () {
    expect(
      peopleNotEmbeddedInPairActivities(['철수', '민수'], ['철수와 민수']),
      isEmpty,
    );
    expect(
      peopleNotEmbeddedInPairActivities(['철수'], ['철수와 카페']),
      ['철수'],
    );
  });

  test('extractGraphSatellites dedupes nested activities', () {
    final memory = Memory(
      id: '5',
      content: '어머니와 저녁을 먹었다.',
      summary: '',
      entities: const ['어머니', '저녁'],
      category: 'Social',
      createdAt: DateTime(2026, 6, 17, 21, 27),
    );

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.people, contains('어머니'));
    expect(satellites.activities, isNot(contains('어머니와 저녁')));
  });

  test('son dinner memory does not show meal time as activity satellites', () {
    final memory = Memory(
      id: 'son-dinner',
      content: '아들과 저녁 식사를 했다.',
      summary: '',
      entities: const ['아들', '저녁', '식사'],
      category: 'Social',
      createdAt: DateTime(2026, 7, 5, 19),
    );

    final satellites = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(satellites.people, contains('아들'));
    expect(satellites.activities, isNot(contains('저녁')));
    expect(satellites.activities, isNot(contains('식사')));
    expect(satellites.food, isNot(contains('저녁')));
    expect(satellites.food, isNot(contains('식사')));
  });

  test('patient names are people not places on clinic memory', () {
    final memory = Memory(
      id: 'clinic',
      content:
          '성소병원에는 이정숙 환자를 정형외과, 김명희 환자를 안과, 정준호 환자, 이기동 환자는 치과로 진료했습니다.',
      summary: '성소병원 외진',
      entities: const ['성소병원', '이정숙', '김명희', '정준호', '이기동', '정형외과', '안과', '치과'],
      category: 'Work',
      createdAt: DateTime(2026, 7, 9),
    );

    final satellites = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(satellites.people, containsAll(['정준호', '김명희', '이기동', '이정숙']));
    expect(satellites.places, isNot(contains('정준호')));
    expect(satellites.places, isNot(contains('김명희')));
    expect(satellites.places, isNot(contains('이기동')));
    expect(satellites.places, contains('성소병원'));
  });
}
