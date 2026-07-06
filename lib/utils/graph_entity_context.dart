import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'graph_fragment_freshness.dart';
import 'graph_satellites.dart';
import 'memory_entity_extract.dart';

/// 관계망 엔티티·배지·위성의 단일 진실 소스.
class GraphEntityContext {
  const GraphEntityContext({
    required this.bundle,
    required this.visibleSatellites,
    required this.hubTitle,
    this.badgeText,
  });

  final MemoryEntityBundle bundle;
  final GraphMemorySatellites visibleSatellites;
  final String hubTitle;
  final String? badgeText;

  factory GraphEntityContext.forMemory(
    Memory memory, {
    required String localeCode,
    GraphMemoryFragment? aiFragment,
  }) {
    final fragment = freshGraphFragmentForMemory(memory, aiFragment);
    final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: fragment);
    final hubTitle = bundle.eventTitle.trim();
    final visible = visibleGraphSatellitesForMemory(
      memory,
      localeCode: localeCode,
      aiFragment: fragment,
      hubTitle: hubTitle,
    );
    return GraphEntityContext(
      bundle: bundle,
      visibleSatellites: visible,
      hubTitle: hubTitle,
      badgeText: satelliteBadgeFromVisible(visible, localeCode: localeCode),
    );
  }
}

String? satelliteBadgeFromVisible(GraphMemorySatellites s, {required String localeCode}) {
  final people = s.people.length;
  final places = s.places.length;
  final activities = s.activities.length + s.events.length + s.hobbies.length;
  final misc = s.organizations.length +
      s.goals.length +
      s.emotions.length +
      s.interests.length +
      s.contents.length +
      s.food.length;
  final total = people + places + activities + misc;
  if (total == 0) return null;

  final ko = localeCode == 'ko';
  final parts = <String>[];
  if (people > 0) parts.add(ko ? '사람 $people' : '👤 $people');
  if (places > 0) parts.add(ko ? '장소 $places' : '📍 $places');
  if (activities > 0) parts.add(ko ? '활동 $activities' : 'Act $activities');
  if (misc > 0) parts.add(ko ? '기타 $misc' : '+$misc');
  return parts.join(' · ');
}
