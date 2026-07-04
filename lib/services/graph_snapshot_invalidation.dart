import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory.dart';
import '../providers/app_providers.dart';
import '../services/graph_ai_orchestrator.dart';
import '../utils/graph_snapshot_store.dart';
import '../utils/memory_grouping.dart';

/// 편집 직후 오래된 AI 제목·클러스터 요약이 그래프를 덮어쓰지 않도록 제거합니다.
Future<void> invalidateGraphSnapshotsForMemory(
  SharedPreferences prefs,
  Ref ref,
  Memory memory,
) async {
  await removeMemoryGraphFragment(prefs, memory.id);
  cancelGraphAiSyncForMemory(memory.id);

  final clusterId = clusterKeyForMemory(memory).id;
  await removeMemoryGraphCluster(prefs, clusterId);

  ref.read(memoryGraphFragmentsProvider.notifier).state = {
    ...ref.read(memoryGraphFragmentsProvider),
  }..remove(memory.id);

  ref.read(memoryGraphClustersProvider.notifier).state = {
    ...ref.read(memoryGraphClustersProvider),
  }..remove(clusterId);
}
