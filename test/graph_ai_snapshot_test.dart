import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/subscription_status.dart';
import 'package:personal_cognitive/services/graph_ai_orchestrator.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GraphMemoryFragment parses AI JSON', () {
    final fragment = GraphMemoryFragment.fromMap({
      'meaning_title': '어머니와 따뜻한 저녁',
      'satellites': [
        {'kind': 'person', 'label': '어머니'},
        {'kind': 'emotion', 'label': '그리움'},
      ],
      'relations': [
        {'target_memory_id': 'b', 'relation_type': 'family', 'label': '같은 날'},
      ],
    });

    expect(fragment.isUsable, isTrue);
    expect(fragment.meaningTitle, '어머니와 따뜻한 저녁');
    expect(fragment.satellites, hasLength(2));
    expect(fragment.relations.single.targetMemoryId, 'b');
  });

  test('isGraphAiActive respects toggle and privacy', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(
      isGraphAiActive(
        prefs: prefs,
        graphAiEnabled: true,
        privacyMode: false,
        guestMode: false,
        subscription: SubscriptionStatus.free(),
      ),
      isFalse,
    );

    expect(
      isGraphAiActive(
        prefs: prefs,
        graphAiEnabled: false,
        privacyMode: false,
        guestMode: false,
        subscription: const SubscriptionStatus(tier: 'pro', status: 'active'),
      ),
      isFalse,
    );

    expect(
      isGraphAiActive(
        prefs: prefs,
        graphAiEnabled: true,
        privacyMode: true,
        guestMode: false,
        subscription: const SubscriptionStatus(tier: 'pro', status: 'active'),
      ),
      isFalse,
    );

    expect(
      isGraphAiActive(
        prefs: prefs,
        graphAiEnabled: true,
        privacyMode: false,
        guestMode: false,
        subscription: const SubscriptionStatus(tier: 'pro', status: 'active'),
      ),
      isFalse, // 단위 테스트 환경 — AppEnv.isConfigured == false
    );
  });

  test('buildMemoryGraphLayout uses AI fragment title and satellites', () {
    final memories = [
      Memory(
        id: 'a',
        content: '오늘 있었던 일\n어머니와 식사',
        summary: '식사',
        entities: const ['어머니'],
        createdAt: DateTime(2025, 6, 1, 18),
        category: '일상',
        subCategory: '가족',
      ),
    ];

    const fragment = GraphMemoryFragment(
      meaningTitle: '어머니와의 저녁 식사',
      satellites: [
        GraphAiSatellite(kind: 'person', label: '어머니'),
        GraphAiSatellite(kind: 'activity', label: '식사'),
      ],
    );

    final layoutCollapsed = buildMemoryGraphLayout(
      memories,
      graphFragments: const {'a': fragment},
    );
    final memoryNode = layoutCollapsed.nodes.firstWhere((n) => n.id == 'memory_a');
    expect(memoryNode.title, contains('어머니'));
    expect(memoryNode.satelliteBadge, isNotNull);

    final layoutExpanded = buildMemoryGraphLayout(
      memories,
      graphFragments: const {'a': fragment},
      satelliteExpansions: const {'a': GraphSatelliteExpandMode.all},
    );
    expect(layoutExpanded.nodes.any((n) => n.title == '어머니' && n.kind.name == 'person'), isTrue);
  });
}
