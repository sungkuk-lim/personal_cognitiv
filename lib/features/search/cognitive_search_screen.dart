import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/crash_reporting.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/ai_service.dart';
import '../../services/local_memory_store.dart';
import '../../utils/ocr_utils.dart';

class CognitiveSearchScreen extends ConsumerStatefulWidget {
  const CognitiveSearchScreen({super.key});
  @override
  ConsumerState<CognitiveSearchScreen> createState() => _CognitiveSearchScreenState();
}

class _CognitiveSearchScreenState extends ConsumerState<CognitiveSearchScreen> {
  final _searchController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;
  ProviderSubscription<String>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _searchSubscription = ref.listenManual<String>(searchQueryProvider, (prev, next) {
      if (next.isEmpty) return;
      _searchController.text = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchQueryProvider.notifier).state = "";
        _performVectorSearch();
      });
    });
  }

  @override
  void dispose() {
    _searchSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performVectorSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || !AppEnv.isConfigured) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _chatHistory.add({'role': 'user', 'content': query});
    });
    _searchController.clear();

    try {
      final t = ref.read(translationsProvider);
      final privacyMode = ref.read(privacyLocalModeProvider);

      if (privacyMode) {
        final matches = searchLocalMemories(ref.read(memoryListProvider), query);
        if (!mounted) return;
        if (matches.isEmpty) {
          setState(() {
            _chatHistory.add({'role': 'assistant', 'content': t['no_results']!});
          });
          return;
        }
        final answer = matches.map((m) => '• ${m.summary.isNotEmpty ? m.summary : m.content}').join('\n');
        ref.read(highlightedEntitiesProvider.notifier).state =
            matches.expand((m) => m.entities).toSet().take(8).toList();
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': answer});
        });
        return;
      }

      final embedding = await AiService.instance.createEmbedding(query);
      final List<dynamic> response = await Supabase.instance.client.rpc('match_memories', params: {
        'query_embedding': embedding,
        'match_threshold': 0.3,
        'match_count': 5,
      });
      final contextMemories = response.map((m) => m['content']).join("\n");
      final List<String> entities = [];
      for (var res in response) {
        entities.addAll(List<String>.from(res['entities'] ?? []));
      }
      ref.read(highlightedEntitiesProvider.notifier).state = entities;

      if (contextMemories.isEmpty) {
        if (!mounted) return;
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': t['no_results']!});
        });
        return;
      }

      final recent = _chatHistory.length > 8 ? _chatHistory.sublist(_chatHistory.length - 8) : _chatHistory;
      final answer = await AiService.instance.chatText(
        systemPrompt:
            "You are a memory assistant. Answer based on the user's stored memories in ${languageNameForLocale(ref.read(languageProvider))}. Be conversational.\nMemories:\n$contextMemories",
        messages: recent,
      );
      if (!mounted) return;
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': answer});
      });
    } catch (e, stack) {
      await CrashReporting.recordError(e, stack, reason: 'vector_search');
      if (!mounted) return;
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': '${ref.read(translationsProvider)['ocr_error']!} ($e)'});
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: t['search_hint']!,
                    prefixIcon: const Icon(Icons.psychology_alt_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  onSubmitted: (_) => _performVectorSearch(),
                ),
              ),
              if (_chatHistory.isNotEmpty)
                IconButton(
                  tooltip: t['clear_chat']!,
                  onPressed: () => setState(() => _chatHistory.clear()),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
        ),
        if (_isLoading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatHistory.length,
            itemBuilder: (context, index) {
              final msg = _chatHistory[index];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                  decoration: BoxDecoration(
                    color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(msg['content'] ?? ''),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
