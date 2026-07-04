import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

void main() {
  test('extractPeopleNamesFromSpeech parses Korean name particles', () {
    expect(
      extractPeopleNamesFromSpeech('월영교에서 황해순이하고 놀러왔다'),
      contains('황해순'),
    );
    expect(
      extractPeopleNamesFromSpeech('민수와 점심을 먹었다'),
      contains('민수'),
    );
    expect(
      extractPeopleNamesFromSpeech('월영교에서 황해순이하고 놀러왔다'),
      isNot(contains('황해순이하고')),
    );
  });

  test('buildVoiceGraphEntities includes speech place, person, and distinct GPS', () {
    final entities = buildVoiceGraphEntities(
      speechPlace: '월영교',
      gpsPlace: '안동댐',
      peopleNames: const ['황해순'],
    );

    expect(entities, containsAll(['황해순', '월영교', '안동댐']));
    expect(entities, isNot(contains('놀러왔다')));
    expect(entities, isNot(contains('바람')));
  });

  test('buildVoiceMemoryFields stores meaning summary from speech', () {
    final fields = buildVoiceMemoryFields(
      speechText: '월영교에서 황해순이하고 놀러왔다. 바람이 너무시원해',
      capturedAt: DateTime(2026, 6, 16, 14, 30),
      localeCode: 'ko',
      gpsPlace: '안동댐',
    );

    expect(fields.summary, contains('황해순'));
    expect(fields.summary, contains('월영교'));
    expect(fields.entities, containsAll(['황해순', '월영교', '안동댐']));
    expect(fields.category, 'Travel');
    expect(fields.content, contains('바람이 너무시원해'));
  });

  test('mergeVoiceFieldsWithAi prefers AI meaning summary when present', () {
    final local = buildVoiceMemoryFields(
      speechText: '월영교에서 황해순이하고 놀러왔다',
      capturedAt: DateTime(2026, 6, 16, 10, 0),
      localeCode: 'ko',
      gpsPlace: '안동댐',
    );

    final merged = mergeVoiceFieldsWithAi(
      localFields: local,
      aiData: {
        'summary': '시원한 바람',
        'entities': ['바람', '여행'],
        'category': 'Travel',
        'sub_category': '야외',
      },
    );

    expect(merged.summary, '시원한 바람');
    expect(merged.entities.first, '황해순');
    expect(merged.entities, containsAll(['황해순', '월영교', '안동댐']));
  });
}
