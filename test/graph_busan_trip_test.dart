import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_meaning.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/photo_memory_format.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _busanTrip = '''6월 18일 해순, 은정, 연숙, 재운, 대호 이렇게 나를 포함해서 6명이 부산 광안리 해수욕장에 20일 까지 여행을 했어
장어구이, 조개구이, 술.. 좋은 추억이 되었는데 18일 밤 11시쯤 연숙이가 대호랑 무슨 일이 있었는지 연숙이가 없어져서 여행이 엉망이 됐어
다음날 연락이 왔는데 혼자사 집으로 갔다는거야
여행이 즐거워야 되는건데.. 많이 실망했어''';

const _daehoFollowUp = '''대호의 행동이 너무 이상했다
많은 의문을 남긴다,
아직도 그날에 어떤 일이 있었는지 모른다.. 다만 짐작만 할 뿐.''';

Memory _memoryFromSpeech(String id, String speech, {String? gps}) {
  final fields = buildVoiceMemoryFields(
    speechText: speech,
    capturedAt: DateTime(2026, 6, 18, 23, 0),
    localeCode: 'ko',
    gpsPlace: gps ?? '부산 광안리 해수욕장',
  );
  return Memory(
    id: id,
    content: fields.content,
    summary: fields.summary,
    entities: fields.entities,
    category: fields.category,
    createdAt: DateTime(2026, 6, 18, 23, 0),
    lat: 35.153,
    lng: 129.118,
  );
}

void main() {
  test('extractPeopleNamesFromSpeech parses comma-separated travel companions', () {
    final names = extractPeopleNamesFromSpeech(_busanTrip);
    expect(names, containsAll(['해순', '은정', '연숙', '재운', '대호']));
    expect(names, isNot(contains('연락')));
    expect(names.first, anyOf('연숙', '대호'));
  });

  test('daeho follow-up memory extracts 대호 not 아직도', () {
    final names = extractPeopleNamesFromSpeech(_daehoFollowUp);
    expect(names, contains('대호'));
    expect(names, isNot(contains('아직도')));
    expect(extractPlaceHintFromOcr(_daehoFollowUp), isNull);
  });

  test('busan trip graph meaning focuses on incident not logistics', () {
    final memory = _memoryFromSpeech('trip', _busanTrip);
    final meaning = graphMeaningSentence(memory, localeCode: 'ko');

    expect(meaning, isNot(contains('다음날 연락')));
    expect(meaning, anyOf(contains('연숙'), contains('엉망'), contains('실망'), contains('대호')));
    expect(memory.entities, containsAll(['해순', '대호', '연숙']));
    expect(memory.entities, isNot(contains('연락')));
  });

  test('busan trip satellites prioritize people place activity emotion', () {
    final memory = _memoryFromSpeech('trip', _busanTrip);
    final satellites = extractGraphSatellites(memory, localeCode: 'ko');

    expect(satellites.people, containsAll(['연숙', '대호']));
    expect(satellites.places.first, contains('해수욕장'));
    expect(satellites.activities.any((a) => a.contains('여행')), isTrue);
    expect(satellites.emotions, contains('실망'));
  });

  test('daeho follow-up satellites and meaning', () {
    final memory = _memoryFromSpeech('follow', _daehoFollowUp);
    final satellites = extractGraphSatellites(memory, localeCode: 'ko');

    expect(graphMeaningSentence(memory, localeCode: 'ko'), contains('대호'));
    expect(satellites.people, contains('대호'));
    expect(satellites.emotions, contains('의문'));
    expect(satellites.people, isNot(contains('아직도')));
  });
}
