import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';

/// 같은 날 + 같은 좌표 + 같은 입력 맥락(카테고리) 기억을 묶는 키.
class MemoryClusterKey {
  const MemoryClusterKey({
    required this.dayKey,
    required this.placeKey,
    required this.contextKey,
  });

  final String dayKey;
  final String placeKey;
  /// 타임라인 입력 카테고리(가족·일반 등) — 맥락이 다르면 같은 GPS라도 분리.
  final String contextKey;

  String get id => '${dayKey}_${placeKey}_$contextKey';

  @override
  bool operator ==(Object other) =>
      other is MemoryClusterKey &&
      other.dayKey == dayKey &&
      other.placeKey == placeKey &&
      other.contextKey == contextKey;

  @override
  int get hashCode => Object.hash(dayKey, placeKey, contextKey);
}

String memoryDayKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

String memoryPlaceKey(Memory memory) {
  if (memory.lat == null || memory.lng == null) return 'unknown';
  return '${memory.lat!.toStringAsFixed(4)},${memory.lng!.toStringAsFixed(4)}';
}

String memoryContextKey(Memory memory) {
  final sub = memory.subCategory.trim();
  if (sub.isNotEmpty) return sub;
  final cat = memory.category.trim();
  return cat.isNotEmpty ? cat : 'other';
}

MemoryClusterKey clusterKeyForMemory(Memory memory) {
  return MemoryClusterKey(
    dayKey: memoryDayKey(memory.createdAt),
    placeKey: memoryPlaceKey(memory),
    contextKey: memoryContextKey(memory),
  );
}

/// 타임라인·관계망 메모는 연결된 본 기억과 같은 날·장소 묶음에 넣습니다.
MemoryClusterKey timelineClusterKeyForMemory(Memory memory, List<Memory> allMemories) {
  if (!isGraphNoteMemory(memory)) return clusterKeyForMemory(memory);
  final primary = allMemories.where((m) => !isGraphNoteMemory(m)).toList();
  final related = resolveGraphNoteRelatedMemory(memory, primary);
  if (related != null) return clusterKeyForMemory(related);
  return clusterKeyForMemory(memory);
}

/// 타임라인·관계망용 날짜+장소 클러스터.
class MemoryTimelineGroup {
  const MemoryTimelineGroup({
    required this.key,
    required this.memories,
  });

  final MemoryClusterKey key;
  final List<Memory> memories;

  Memory get primary => memories.first;

  bool get isGrouped => memories.length > 1;
}

List<MemoryTimelineGroup> groupMemoriesForTimeline(List<Memory> memories) {
  if (memories.isEmpty) return const [];

  final visible = memories.where(isUserFacingMemory).toList();
  if (visible.isEmpty) return const [];

  final sorted = [...visible]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final buckets = <String, List<Memory>>{};

  for (final memory in sorted) {
    final key = timelineClusterKeyForMemory(memory, memories).id;
    buckets.putIfAbsent(key, () => []).add(memory);
  }

  final groups = <MemoryTimelineGroup>[];
  for (final entry in buckets.entries) {
    final list = [...entry.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    groups.add(MemoryTimelineGroup(key: timelineClusterKeyForMemory(list.first, memories), memories: list));
  }

  groups.sort((a, b) => b.primary.createdAt.compareTo(a.primary.createdAt));
  return groups;
}

/// 날짜+장소 조합마다 고유 색 — 같은 날·같은 장소는 동일, 그 외는 다름.
Color colorForMemoryCluster(MemoryClusterKey key) {
  const palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFF8D6E63),
    Color(0xFFEC407A),
    Color(0xFF7E57C2),
    Color(0xFF29B6F6),
    Color(0xFFD4E157),
  ];
  final hash = Object.hash(key.dayKey, key.placeKey, key.contextKey);
  return palette[hash.abs() % palette.length];
}

Color colorForMemory(Memory memory) => colorForMemoryCluster(clusterKeyForMemory(memory));
