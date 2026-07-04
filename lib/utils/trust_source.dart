import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';

/// 기억 출처 — 신뢰 배지·대시보드용.
enum MemoryTrustSource {
  userRecord,
  aiAssist,
}

bool isAiAssistedMemory(Memory memory) {
  if (isGraphAnchorMediaStorage(memory)) return false;
  if (isGraphNoteMemory(memory)) return true;
  final sub = memory.subCategory.trim();
  if (sub == '관계망 메모' || sub == 'Graph note') return true;
  if (memory.userMemo.contains(kGraphAnchorMemoPrefix) && graphNoteFactTitle(memory).trim().isNotEmpty) {
    return true;
  }
  return false;
}

MemoryTrustSource trustSourceForMemory(Memory memory) {
  return isAiAssistedMemory(memory) ? MemoryTrustSource.aiAssist : MemoryTrustSource.userRecord;
}

int countAiAssistedMemories(Iterable<Memory> memories) {
  return memories.where(isAiAssistedMemory).length;
}

int countUserRecordMemories(Iterable<Memory> memories) {
  return memories.where((m) => !isAiAssistedMemory(m) && isUserFacingMemory(m)).length;
}
