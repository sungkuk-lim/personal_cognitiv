import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_meaning.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _hospitalDinner = '''
6월 21일 저녁 7시에 병원직원들과 회식을 하게 되었어
참석자로는 배춘남 간호과장, 이미경 간호팀장, 간호사로는 황상기, 김경아, 김경희, 배재석, 임예림, 이재근이 참석하였고 보호사로는 이동명, 서충원, 나, 권용선, 조익태 이렇게 모두 13명이 옥동 중화요리집에서 탕수육, 자장면 등 술과 여러가지 음식을 시켜놓고 이런 저런 얘기를 하면 회식을 했어
''';

void main() {
  test('hospital dinner entity extraction', () {
    final people = extractPeopleFromMemoryText(_hospitalDinner);
    expect(people, contains('배춘남'));
    expect(people, contains('이미경'));
    expect(people, contains('황상기'));
    expect(people, contains('김경아'));
    expect(people, contains('이동명'));
    expect(people, contains('권용선'));
    expect(people, isNot(contains('원직원들')));
    expect(people, isNot(contains('간호과장')));
    expect(people.length, greaterThanOrEqualTo(8));

    final places = extractPlacesFromMemoryText(_hospitalDinner);
    expect(places.any((p) => p.contains('옥동') && p.contains('요리집')), isTrue);

    final orgs = extractOrganizationsFromText(_hospitalDinner);
    expect(orgs, contains('병원'));
    expect(orgs, contains('간호과'));

    expect(extractEventTitleFromText(_hospitalDinner), '병원 직원 회식');
  });

  test('hospital dinner graph layout uses event hub and people satellites', () {
    final people = extractPeopleFromMemoryText(_hospitalDinner);
    final memory = Memory(
      id: 'hospital_dinner',
      content: _hospitalDinner,
      summary: extractEventTitleFromText(_hospitalDinner),
      entities: buildVoiceGraphEntities(
        speechPlace: '옥동 중화요리집',
        peopleNames: people,
      ),
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );

    final bundle = extractMemoryEntities(memory, localeCode: 'ko');
    expect(bundle.eventTitle, contains('회식'));
    expect(bundle.people.length, greaterThanOrEqualTo(8));
    expect(bundle.places.any((p) => p.contains('옥동')), isTrue);

    final satellites = extractGraphSatellites(memory, localeCode: 'ko');
    expect(satellites.activities, isNot(contains('술')));
    expect(satellites.activities, isNot(contains('탕수육')));

    final meaning = graphMeaningSentence(memory, localeCode: 'ko');
    expect(meaning, contains('회식'));

    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(layout.nodes.any((n) => n.id.startsWith('event_hub_')), isFalse);
    expect(layout.nodes.any((n) => n.id == 'memory_hospital_dinner'), isTrue);
    expect(layout.nodes.any((n) => n.title == '배춘남'), isTrue);
    expect(layout.nodes.any((n) => n.title == '술'), isFalse);
    expect(layout.nodes.any((n) => n.title == '탕수육'), isFalse);
  });
}
