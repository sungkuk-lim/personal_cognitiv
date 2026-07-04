import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/graph_ai_snapshot.dart';

const String prefMemoryGraphFragments = 'memory_graph_fragments';
const String prefMemoryGraphClusters = 'memory_graph_clusters';

Map<String, GraphMemoryFragment> readMemoryGraphFragments(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryGraphFragments);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((id, value) {
      final fragment = GraphMemoryFragment.fromMap(Map<String, dynamic>.from(value as Map));
      return MapEntry(id, fragment);
    });
  } catch (_) {
    return {};
  }
}

Map<String, GraphClusterSnapshot> readMemoryGraphClusters(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryGraphClusters);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((clusterId, value) {
      return MapEntry(
        clusterId,
        GraphClusterSnapshot.fromMap(clusterId, Map<String, dynamic>.from(value as Map)),
      );
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryGraphFragment(
  SharedPreferences prefs,
  String memoryId,
  GraphMemoryFragment fragment,
) async {
  final cache = {...readMemoryGraphFragments(prefs), memoryId: fragment};
  await prefs.setString(
    prefMemoryGraphFragments,
    jsonEncode(cache.map((k, v) => MapEntry(k, v.toMap()))),
  );
}

Future<void> saveMemoryGraphCluster(
  SharedPreferences prefs,
  String clusterId,
  GraphClusterSnapshot snapshot,
) async {
  final cache = {...readMemoryGraphClusters(prefs), clusterId: snapshot};
  await prefs.setString(
    prefMemoryGraphClusters,
    jsonEncode(cache.map((k, v) => MapEntry(k, v.toMap()))),
  );
}

Future<void> removeMemoryGraphFragment(SharedPreferences prefs, String memoryId) async {
  final cache = {...readMemoryGraphFragments(prefs)}..remove(memoryId);
  await prefs.setString(
    prefMemoryGraphFragments,
    jsonEncode(cache.map((k, v) => MapEntry(k, v.toMap()))),
  );
}

Future<void> removeMemoryGraphCluster(SharedPreferences prefs, String clusterId) async {
  final cache = {...readMemoryGraphClusters(prefs)}..remove(clusterId);
  await prefs.setString(
    prefMemoryGraphClusters,
    jsonEncode(cache.map((k, v) => MapEntry(k, v.toMap()))),
  );
}
