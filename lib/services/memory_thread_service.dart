import '../core/env.dart';
import '../models/memory.dart';
import '../utils/embedding_utils.dart';
import 'local_memory_thread_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryThreadService {
  MemoryThreadService._();
  static final MemoryThreadService instance = MemoryThreadService._();

  /// 로컬 규칙 우선 → 클라oud 임베딩 보강.
  Future<List<Memory>> findRelated({
    required Memory saved,
    required List<Memory> allMemories,
    List<double>? embedding,
    required String excludeId,
    int count = 3,
    String localeCode = 'ko',
    double threshold = graphEmbeddingSimilarityThreshold,
  }) async {
    final local = LocalMemoryThreadService.findRelated(
      saved: saved,
      allMemories: allMemories,
      excludeId: excludeId,
      limit: count,
      localeCode: localeCode,
    );
    if (local.length >= count) return local;

    final vector = embedding ?? saved.embedding;
    if (vector == null || !AppEnv.isConfigured) return local;

    try {
      final response = await Supabase.instance.client.rpc('match_memories', params: {
        'query_embedding': vector,
        'match_threshold': threshold,
        'match_count': count + 3,
      }) as List<dynamic>;

      final cloud = response
          .map((m) => Memory.fromMap(m as Map<String, dynamic>))
          .where((m) => m.id != excludeId)
          .toList();

      final seen = <String>{};
      final merged = <Memory>[];
      for (final m in [...local, ...cloud]) {
        if (seen.add(m.id)) merged.add(m);
        if (merged.length >= count) break;
      }
      return merged;
    } catch (_) {
      return local;
    }
  }
}
