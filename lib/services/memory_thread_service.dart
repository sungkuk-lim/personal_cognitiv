import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/memory.dart';

class MemoryThreadService {
  MemoryThreadService._();
  static final MemoryThreadService instance = MemoryThreadService._();

  Future<List<Memory>> findRelated({
    required List<double> embedding,
    required String excludeId,
    int count = 3,
    double threshold = 0.55,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc('match_memories', params: {
        'query_embedding': embedding,
        'match_threshold': threshold,
        'match_count': count + 1,
      }) as List<dynamic>;

      return response
          .map((m) => Memory.fromMap(m as Map<String, dynamic>))
          .where((m) => m.id != excludeId)
          .take(count)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
