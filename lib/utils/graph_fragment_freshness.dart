import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'memory_detail_text.dart';
import 'memory_grouping.dart';

/// AI 조각이 현재 기억 본문과 맞지 않으면(편집 후 등) 관계망에서 무시합니다.
bool isGraphFragmentStaleForMemory(Memory memory, GraphMemoryFragment? fragment) {
  if (fragment == null || !fragment.isUsable) return true;
  final aiTitle = fragment.meaningTitle.trim();
  if (aiTitle.isEmpty) return false;

  final blob = '${memory.summary}\n${memory.content}'.trim();
  if (blob.isEmpty) return true;

  if (memoryTextsOverlapForDisplay(aiTitle, blob)) return false;
  if (memoryTextsOverlapForDisplay(aiTitle, memory.summary)) return false;
  if (memoryTextsOverlapForDisplay(aiTitle, memory.content)) return false;
  if (blob.contains(aiTitle)) return false;

  return true;
}

GraphMemoryFragment? freshGraphFragmentForMemory(Memory memory, GraphMemoryFragment? fragment) {
  if (isGraphFragmentStaleForMemory(memory, fragment)) return null;
  return fragment;
}

bool isGraphClusterSnapshotStale(
  MemoryTimelineGroup group,
  GraphClusterSnapshot? snapshot, {
  required String localeCode,
}) {
  if (snapshot == null || !snapshot.isUsable) return true;
  final title = snapshot.clusterTitle.trim();
  if (title.isEmpty) return true;

  for (final memory in group.memories) {
    final blob = '${memory.summary}\n${memory.content}'.trim();
    if (memoryTextsOverlapForDisplay(title, blob)) return false;
    if (blob.contains(title)) return false;
  }
  return true;
}
