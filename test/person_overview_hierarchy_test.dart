import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_person_layout.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  test('person overview uses couple hierarchy instead of flat co-occurrence', () {
    const text =
        '저는 김민수이고 연인은 이지은입니다. 우리는 여행, 운동, 영화 감상을 함께 즐깁니다. '
        '제주도 여행을 함께 계획하고 있으며, 운동은 매주 주말 같이 하고 있습니다. '
        '서로 영화를 추천해 주고, 여행 사진도 함께 정리합니다.';
    final result = buildPersonOverviewGraphLayout([
      Memory(
        id: 'couple-1',
        content: text,
        summary: '우리 관계',
        entities: const [],
        createdAt: DateTime(2026, 7, 25),
      ),
    ]);

    final titles = result.layout.nodes.map((n) => n.title).toSet();
    expect(titles, contains('나'));
    expect(titles, contains('이지은'));
    expect(titles, contains('김민수'));
    expect(titles, isNot(contains('연인')));
    expect(titles, isNot(contains('관계')));
    expect(titles, contains('여행'));

    final labels = result.layout.edges.map((e) => e.label).whereType<String>().toSet();
    expect(labels.any((l) => l == '1'), isFalse);
    expect(labels.contains('연인') || labels.contains('활동') || labels.contains('구성'), isTrue);
  });
}
