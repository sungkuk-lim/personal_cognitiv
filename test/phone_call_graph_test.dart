import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_semantic_extract.dart';

void main() {
  const phoneMemory = '''딸 한테서 전화가 왔다
오늘은 기분이 좋다''';

  test('전화 is not a person token', () {
    expect(isPhoneCallGraphToken('전화'), isTrue);
    expect(isLikelyKoreanPersonName('전화'), isFalse);
  });

  test('딸 from phone call memory is person, 전화 is not', () {
    final memory = Memory(
      id: 'phone',
      content: phoneMemory,
      summary: '딸한테서 전화',
      entities: const [],
      createdAt: DateTime(2026, 1, 1),
    );
    final bundle = extractMemoryEntities(memory, localeCode: 'ko');
    expect(bundle.people, contains('딸'));
    expect(bundle.people, isNot(contains('전화')));
  });
}
