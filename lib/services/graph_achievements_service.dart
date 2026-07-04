import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import '../utils/memory_entity_extract.dart';
import 'graph_insights_service.dart';

class GraphAchievement {
  const GraphAchievement({
    required this.id,
    required this.titleKo,
    required this.titleEn,
    required this.descriptionKo,
    required this.descriptionEn,
    required this.iconName,
    required this.threshold,
    required this.metric,
  });

  final String id;
  final String titleKo;
  final String titleEn;
  final String descriptionKo;
  final String descriptionEn;
  final String iconName;
  final int threshold;
  final GraphAchievementMetric metric;
}

enum GraphAchievementMetric { nodes, people, places, memories, studyMemories }

const List<GraphAchievement> graphAchievements = [
  GraphAchievement(
    id: 'nodes_25',
    titleKo: '관계망 새싹',
    titleEn: 'Sprouting graph',
    descriptionKo: '관계 노드 25개 달성',
    descriptionEn: '25 graph nodes',
    iconName: 'hub',
    threshold: 25,
    metric: GraphAchievementMetric.nodes,
  ),
  GraphAchievement(
    id: 'nodes_100',
    titleKo: '삶의 지도',
    titleEn: 'Life map',
    descriptionKo: '관계 노드 100개 달성',
    descriptionEn: '100 graph nodes',
    iconName: 'map',
    threshold: 100,
    metric: GraphAchievementMetric.nodes,
  ),
  GraphAchievement(
    id: 'people_10',
    titleKo: '인물 관계망',
    titleEn: 'People web',
    descriptionKo: '인물 노드 10명 연결',
    descriptionEn: '10 people in your graph',
    iconName: 'people',
    threshold: 10,
    metric: GraphAchievementMetric.people,
  ),
  GraphAchievement(
    id: 'places_20',
    titleKo: '여행 지도',
    titleEn: 'Place explorer',
    descriptionKo: '장소 20곳 연결',
    descriptionEn: '20 places linked',
    iconName: 'place',
    threshold: 20,
    metric: GraphAchievementMetric.places,
  ),
  GraphAchievement(
    id: 'memories_50',
    titleKo: '기억 수집가',
    titleEn: 'Memory collector',
    descriptionKo: '기억 50건 저장',
    descriptionEn: '50 memories saved',
    iconName: 'memory',
    threshold: 50,
    metric: GraphAchievementMetric.memories,
  ),
  GraphAchievement(
    id: 'study_20',
    titleKo: '학습 노드',
    titleEn: 'Study streak',
    descriptionKo: '공부·학습 기록 20건',
    descriptionEn: '20 study memories',
    iconName: 'study',
    threshold: 20,
    metric: GraphAchievementMetric.studyMemories,
  ),
];

int graphMetricValue({
  required GraphAchievementMetric metric,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
}) {
  return switch (metric) {
    GraphAchievementMetric.nodes => estimateGraphNodeCount(memories, fragments),
    GraphAchievementMetric.people => _uniquePeople(memories, fragments),
    GraphAchievementMetric.places => _uniquePlaces(memories, fragments),
    GraphAchievementMetric.memories => memories.length,
    GraphAchievementMetric.studyMemories =>
      memories.where((m) => m.category == 'Study' || m.subCategory.contains('공부') || m.subCategory.contains('Study')).length,
  };
}

int estimateGraphNodeCount(List<Memory> memories, Map<String, GraphMemoryFragment> fragments) {
  final nodes = <String>{};
  for (final memory in memories) {
    nodes.add('memory_${memory.id}');
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        nodes.add('${s.kind}_${s.label}');
      }
    }
    for (final e in userVisibleEntityLabels(memory)) {
      nodes.add('entity_$e');
    }
  }
  return nodes.length;
}

int _uniquePeople(List<Memory> memories, Map<String, GraphMemoryFragment> fragments) {
  final people = <String>{};
  for (final memory in memories) {
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'person') people.add(s.label);
      }
    }
    for (final p in extractMemoryEntities(memory).people) {
      people.add(p);
    }
  }
  return people.length;
}

int _uniquePlaces(List<Memory> memories, Map<String, GraphMemoryFragment> fragments) {
  final places = <String>{};
  for (final memory in memories) {
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'place') places.add(s.label);
      }
    }
    for (final p in extractMemoryEntities(memory).places) {
      places.add(p);
    }
  }
  return places.length;
}

/// 새로 달성한 배지를 반환하고 prefs에 저장합니다.
Future<List<GraphAchievement>> checkAndUnlockGraphAchievements({
  required SharedPreferences prefs,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
}) async {
  final unlocked = readGraphAchievementsUnlocked(prefs);
  final newly = <GraphAchievement>[];

  for (final achievement in graphAchievements) {
    if (unlocked.contains(achievement.id)) continue;
    final value = graphMetricValue(metric: achievement.metric, memories: memories, fragments: fragments);
    if (value >= achievement.threshold) {
      newly.add(achievement);
      unlocked.add(achievement.id);
    }
  }

  if (newly.isNotEmpty) {
    await writeGraphAchievementsUnlocked(prefs, unlocked);
  }
  return newly;
}

List<GraphAchievement> readUnlockedAchievements(SharedPreferences prefs) {
  final ids = readGraphAchievementsUnlocked(prefs);
  return graphAchievements.where((a) => ids.contains(a.id)).toList();
}
