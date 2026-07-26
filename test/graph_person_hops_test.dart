import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_person_hops.dart';

Memory _m(String id, List<String> people) => Memory(
      id: id,
      content: '기록 $id',
      summary: '',
      entities: people,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('personHopDistances finds 1st through 3rd degree', () {
    final memories = [
      _m('1', ['민준', '철수']),
      _m('2', ['철수', '영희']),
      _m('3', ['영희', '민수']),
    ];
    final dist = personHopDistances(
      fromPerson: '민준',
      memories: memories,
      localeCode: 'ko',
      maxDepth: 5,
    );
    expect(dist['철수'], 1);
    expect(dist['영희'], 2);
    expect(dist['민수'], 3);
  });

  test('groupPeopleByHop orders by degree', () {
    final grouped = groupPeopleByHop({'a': 1, 'b': 2, 'c': 1});
    expect(grouped.keys.toList(), [1, 2]);
    expect(grouped[1], containsAll(['a', 'c']));
  });
}
