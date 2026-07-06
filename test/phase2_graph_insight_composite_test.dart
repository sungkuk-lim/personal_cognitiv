import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/core/pro_feature_gate.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/features/graph/graph_node_insight.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_composite_query_examples.dart';
import 'package:personal_cognitive/utils/memory_query.dart';

Memory _m({
  required String id,
  required String content,
  DateTime? createdAt,
}) {
  return Memory(
    id: id,
    content: content,
    summary: content,
    entities: const [],
    createdAt: createdAt ?? DateTime(2026, 6, 1),
  );
}

void main() {
  group('composite query examples', () {
    for (final example in kGraphCompositeQueryExamplesKo) {
      test('parses ≥${example.minDimensions} dims: ${example.query}', () {
        final q = parseNaturalLanguageQuery(example.query, localeCode: 'ko');
        expect(q.isComposite, isTrue);
        expect(
          compositeQueryDimensionCount(q) >= example.minDimensions ||
              q.people.length >= 2 ||
              requiresProForMemoryQuery(q),
          isTrue,
        );
        expect(requiresProForMemoryQuery(q), isTrue);
      });
    }

    test('has 20 Korean examples', () {
      expect(kGraphCompositeQueryExamplesKo.length, 20);
    });
  });

  test('민수랑 행복했던 식사 extracts person emotion activity', () {
    final q = parseNaturalLanguageQuery('민수랑 행복했던 식사만 보여줘', localeCode: 'ko');
    expect(q.people, contains('민수'));
    expect(q.emotions, contains('행복'));
    expect(q.activities, contains('식사'));
    expect(requiresProForMemoryQuery(q), isTrue);
  });

  test('single person query is not pro gated', () {
    final q = parseNaturalLanguageQuery('민수 기억', localeCode: 'ko');
    expect(requiresProForMemoryQuery(q), isFalse);
  });

  test('graph node insight builds timeline and theme hub', () {
    final memories = [
      _m(id: '1', content: '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.', createdAt: DateTime(2026, 7, 5)),
      _m(id: '2', content: '민수와 카페에서 보드게임', createdAt: DateTime(2026, 6, 12)),
    ];
    final node = GraphNodeData(
      id: 'person_민수',
      title: '민수',
      subtitle: '',
      color: const Color(0xFF000000),
      kind: GraphNodeKind.person,
      size: const Size(100, 48),
      layoutClusterId: 'c',
    );
    final insight = buildGraphNodeInsight(
      node: node,
      connectedMemories: memories,
      allMemories: memories,
      fragments: const {},
      localeCode: 'ko',
    );
    expect(insight.totalCount, 2);
    expect(insight.themeHubLabel, '민수와의 기억');
    expect(insight.timelineMemories.length, 2);
    expect(insight.summaryLine, contains('민수'));
  });
}
