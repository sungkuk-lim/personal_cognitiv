import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'graph_satellites.dart';
import 'memory_entity_extract.dart';

/// 리스트·관계망에서 반복되는 엔티티 추출 비용을 줄입니다.
final class MemoryEntityCache {
  MemoryEntityCache._();

  static final _bundles = <String, MemoryEntityBundle>{};
  static final _visibleSatellites = <String, GraphMemorySatellites>{};

  static String _key(
    Memory memory,
    String localeCode, {
    GraphMemoryFragment? aiFragment,
  }) {
    final frag = aiFragment == null
        ? ''
        : '${aiFragment.meaningTitle}|${aiFragment.satellites.map((s) => '${s.kind}:${s.label}').join(',')}';
    return '${memory.id}:${memory.content.hashCode}:${memory.summary.hashCode}:'
        '${memory.entities.join('|')}:$localeCode:$frag';
  }

  static MemoryEntityBundle bundle(
    Memory memory, {
    String localeCode = 'ko',
    GraphMemoryFragment? aiFragment,
  }) {
    final key = _key(memory, localeCode, aiFragment: aiFragment);
    return _bundles.putIfAbsent(
      key,
      () => extractMemoryEntities(
        memory,
        localeCode: localeCode,
        aiFragment: aiFragment,
      ),
    );
  }

  static GraphMemorySatellites visibleSatellites(
    Memory memory, {
    String localeCode = 'ko',
    GraphMemoryFragment? aiFragment,
    String? hubTitle,
  }) {
    final key = '${_key(memory, localeCode, aiFragment: aiFragment)}:vis:${hubTitle ?? ''}';
    return _visibleSatellites.putIfAbsent(
      key,
      () => visibleGraphSatellitesForMemory(
        memory,
        localeCode: localeCode,
        aiFragment: aiFragment,
        hubTitle: hubTitle,
      ),
    );
  }

  static void clear() {
    _bundles.clear();
    _visibleSatellites.clear();
  }
}
