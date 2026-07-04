import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/memory.dart';
import '../providers/app_providers.dart';
import '../utils/memory_query.dart';
import '../utils/memory_image_paths.dart';
import '../utils/memory_video_paths.dart';
import '../utils/semantic_search.dart';
import '../services/graph_memory_traverse.dart';
import '../services/local_memory_store.dart';
import 'ai_service.dart';
import 'graph_query_engine.dart';

/// 검색: 1) 로컬·그래프 DB 조회 → 2) 필요 시 AI는 짧은 요약만.
class SearchAnswerService {
  SearchAnswerService._();
  static final SearchAnswerService instance = SearchAnswerService._();

  Future<SearchAnswerResult> answer({
    required WidgetRef ref,
    required String query,
    required List<Memory> allMemories,
    required bool useCloudEmbedding,
    required String localeCode,
    required String languageName,
  }) async {
    final fragments = ref.read(memoryGraphFragmentsProvider);
    final trimmed = query.trim();
    final parsed = parseNaturalLanguageQuery(trimmed, localeCode: localeCode);
    final imagePaths = ref.read(memoryImagePathsProvider);
    final videoPaths = ref.read(memoryVideoPathsProvider);

    bool hasPhotoFor(String id) =>
        imagePaths[id]?.isNotEmpty == true;
    bool hasVideoFor(String id) =>
        memoryHasVideo(id, videoPaths);

    final graphAnswer = tryAnswerFromGraphDb(
      query: trimmed,
      memories: allMemories,
      fragments: fragments,
      localeCode: localeCode,
      structuredQuery: parsed,
      hasPhotoFor: hasPhotoFor,
      hasVideoFor: hasVideoFor,
    );

    List<Memory> matched;
    if (graphAnswer != null && graphAnswer.relatedMemories.isNotEmpty) {
      matched = graphAnswer.relatedMemories;
    } else if (parsed.isComposite) {
      matched = filterMemoriesByQuery(
        allMemories,
        parsed,
        localeCode: localeCode,
        hasPhotoFor: hasPhotoFor,
        hasVideoFor: hasVideoFor,
      );
      if (matched.isEmpty) {
        matched = traverseGraphForQuery(
          memories: allMemories,
          query: parsed,
          localeCode: localeCode,
        );
      }
      if (matched.isEmpty) {
        matched = await _retrieveMemories(
          query: trimmed,
          allMemories: allMemories,
          useCloudEmbedding: useCloudEmbedding,
          localeCode: localeCode,
          structuredQuery: parsed,
          hasPhotoFor: hasPhotoFor,
          hasVideoFor: hasVideoFor,
        );
      }
    } else {
      matched = await _retrieveMemories(
        query: trimmed,
        allMemories: allMemories,
        useCloudEmbedding: useCloudEmbedding,
        localeCode: localeCode,
        structuredQuery: parsed,
        hasPhotoFor: hasPhotoFor,
        hasVideoFor: hasVideoFor,
      );
    }

    if (matched.isEmpty) {
      return SearchAnswerResult.empty();
    }

    final compositeSummary = parsed.isComposite ? describeMemoryQuery(parsed, localeCode: localeCode) : null;

    if (graphAnswer != null && graphAnswer.skipAiSummary) {
      return SearchAnswerResult(
        memories: matched,
        answerText: graphAnswer.text,
        fromGraphDb: true,
        parsedQuery: parsed,
      );
    }

    if (isPhotoSearchQuery(trimmed) || (parsed.hasPhoto == true && !useCloudEmbedding)) {
      return SearchAnswerResult(
        memories: matched,
        answerText: compositeSummary ?? (matched.isNotEmpty ? '${matched.length}' : null),
        parsedQuery: parsed,
      );
    }

    final compact = buildCompactSearchContext(matched, fragments);
    final hint = graphAnswer?.text ?? compositeSummary;
    try {
      final aiText = await AiService.instance.chatText(
        systemPrompt: _summarySystemPrompt(languageName, hint),
        messages: [
          {'role': 'user', 'content': 'Question: $trimmed\n\nGraph memory index:\n$compact'},
        ],
      );
      return SearchAnswerResult(
        memories: matched,
        answerText: aiText.trim(),
        parsedQuery: parsed,
      );
    } catch (e, stack) {
      debugPrint('Search AI summary failed: $e\n$stack');
      return SearchAnswerResult(memories: matched, answerText: hint, parsedQuery: parsed);
    }
  }

  Future<List<Memory>> _retrieveMemories({
    required String query,
    required List<Memory> allMemories,
    required bool useCloudEmbedding,
    required String localeCode,
    MemoryQuery? structuredQuery,
    bool Function(String memoryId)? hasPhotoFor,
    bool Function(String memoryId)? hasVideoFor,
  }) async {
    List<double>? embedding;
    try {
      embedding = await AiService.instance.createEmbedding(query);
    } catch (_) {
      embedding = null;
    }

    if (useCloudEmbedding && embedding != null) {
      try {
        final List<dynamic> response = await Supabase.instance.client.rpc('match_memories', params: {
          'query_embedding': embedding,
          'match_threshold': 0.3,
          'match_count': 8,
        });
        final cloudMatched =
            response.map<Memory>((m) => Memory.fromMap(Map<String, dynamic>.from(m as Map))).toList();
        final localSemantic = searchMemoriesByEmbedding(allMemories, embedding);
        return mergeMemoriesById(cloudMatched, localSemantic);
      } catch (_) {
        // fall through to hybrid
      }
    }

    if (structuredQuery != null && structuredQuery.isComposite) {
      final composite = searchWithMemoryQuery(
        memories: allMemories,
        query: structuredQuery,
        localeCode: localeCode,
        hasPhotoFor: hasPhotoFor,
        hasVideoFor: hasVideoFor,
        queryEmbedding: embedding,
      );
      if (composite.isNotEmpty) return composite;
    }

    return searchMemoriesHybrid(
      memories: allMemories,
      query: query,
      queryEmbedding: embedding,
      deviceOnly: false,
    );
  }

  String _summarySystemPrompt(String languageName, String? graphHint) {
    final hintLine = graphHint != null ? '\nPre-computed graph fact (prefer this): $graphHint' : '';
    return '''You are MemoryOS search. Reply in $languageName in 2-4 short sentences.
Use ONLY the structured graph memory index below. Never invent facts.$hintLine
Do not repeat the full index — synthesize a helpful answer.''';
  }
}

class SearchAnswerResult {
  const SearchAnswerResult({
    required this.memories,
    this.answerText,
    this.fromGraphDb = false,
    this.parsedQuery,
  });

  factory SearchAnswerResult.empty() => const SearchAnswerResult(memories: []);

  final List<Memory> memories;
  final String? answerText;
  final bool fromGraphDb;
  final MemoryQuery? parsedQuery;

  bool get isEmpty => memories.isEmpty;
}
