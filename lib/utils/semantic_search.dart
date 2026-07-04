import '../models/memory.dart';
import '../services/local_memory_store.dart';
import '../features/graph/graph_chat_save.dart';
import '../utils/embedding_utils.dart';
import '../utils/memory_keyword_ui.dart';

/// 의미 검색 + 키워드 검색 하이브리드 (프라이버시·클라우드 공통).
const double semanticSearchEmbeddingThreshold = 0.38;

List<Memory> searchMemoriesByEmbedding(
  List<Memory> memories,
  List<double> queryEmbedding, {
  double threshold = semanticSearchEmbeddingThreshold,
  int limit = 8,
}) {
  final scored = <({Memory memory, double score})>[];
  for (final memory in memories) {
    final emb = memory.embedding;
    if (emb == null || emb.isEmpty) continue;
    final score = cosineSimilarity(queryEmbedding, emb);
    if (score >= threshold) {
      scored.add((memory: memory, score: score));
    }
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(limit).map((e) => e.memory).toList();
}

List<Memory> mergeMemoriesById(List<Memory> primary, List<Memory> extra, {int limit = 8}) {
  final seen = <String>{};
  final merged = <Memory>[];
  for (final memory in [...primary, ...extra]) {
    if (seen.add(memory.id)) merged.add(memory);
    if (merged.length >= limit) break;
  }
  return merged;
}

/// 키워드 + (선택) 임베딩으로 기억 검색.
List<Memory> searchMemoriesHybrid({
  required List<Memory> memories,
  required String query,
  List<double>? queryEmbedding,
  bool deviceOnly = false,
  int limit = 8,
}) {
  final visible = memories.where(isUserFacingMemory).toList();
  final keywordMatches = searchLocalMemories(
    visible,
    query,
    limit: limit,
    requireLocalOnly: deviceOnly,
  );

  if (queryEmbedding == null || queryEmbedding.isEmpty) {
    return keywordMatches;
  }

  final embeddingMatches = searchMemoriesByEmbedding(visible, queryEmbedding, limit: limit);
  return mergeMemoriesById(keywordMatches, embeddingMatches, limit: limit);
}

/// 검색·그래프 하이라이트용 — 기억이 entity 목록과 겹치는지.
bool memoryMatchesAnyEntity(Memory memory, Iterable<String> entities) {
  for (final entity in entities) {
    if (memoryMatchesKeyword(memory, entity)) return true;
  }
  return false;
}

String recallNotificationTitle(String localeCode) =>
    localeCode == 'ko' ? '기억이 소환되었습니다' : 'A memory surfaced';

String recallNotificationChannelName(String localeCode) =>
    localeCode == 'ko' ? '기억 소환' : 'Memory recall';

String recallNotificationChannelDesc(String localeCode) =>
    localeCode == 'ko' ? '과거 장소에서 기억을 알려줍니다' : 'Reminds you of memories at places you visit';
