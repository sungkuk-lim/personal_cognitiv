import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../core/app_maturity.dart';

import '../../core/env.dart';

import '../../core/crash_reporting.dart';

import '../../models/memory.dart';

import '../../providers/app_providers.dart';

import '../../providers/memory_notifier.dart';

import '../../providers/subscription_providers.dart';

import '../../services/entitlement_service.dart';

import '../../services/local_memory_store.dart';

import '../../services/search_answer_service.dart';

import '../../services/subscription_exceptions.dart';

import '../../core/pro_feature_gate.dart';

import '../../utils/graph_composite_query_examples.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/memory_query.dart';
import '../../utils/memory_video_paths.dart';
import '../../utils/ocr_utils.dart';
import '../../utils/semantic_search.dart';
import '../../services/graph_memory_traverse.dart';

import 'search_filter_chips_bar.dart';
import 'search_memory_result_tile.dart';



class _ChatEntry {

  const _ChatEntry.user(this.text)
      : isUser = true,
        results = null,
        searchQuery = null,
        isLocalFallback = false;

  const _ChatEntry.assistant({
    this.text,
    this.results,
    this.searchQuery,
    this.isLocalFallback = false,
  }) : isUser = false;

  final bool isUser;
  final String? text;
  final List<Memory>? results;
  final String? searchQuery;
  final bool isLocalFallback;

}



class CognitiveSearchScreen extends ConsumerStatefulWidget {

  const CognitiveSearchScreen({super.key});

  @override

  ConsumerState<CognitiveSearchScreen> createState() => _CognitiveSearchScreenState();

}



class _CognitiveSearchScreenState extends ConsumerState<CognitiveSearchScreen> {

  final _searchController = TextEditingController();

  final List<_ChatEntry> _chatHistory = [];

  bool _isLoading = false;

  MemoryQuery? _activeQuery;

  String _lastSearchText = '';

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

        _performSearch();

      });

    });

  }



  @override

  void dispose() {

    _searchSubscription?.close();

    _searchController.dispose();

    super.dispose();

  }



  void _pushResults(
    List<Memory> matches, {
    String? aiText,
    String searchQuery = '',
    bool isLocalFallback = false,
  }) {

    final locale = ref.read(languageProvider).languageCode;

    final header = matches.isEmpty

        ? null

        : (locale == 'ko'

            ? '${matches.length}개의 기억을 찾았습니다. 사진을 눌러 자세히 볼 수 있습니다.'

            : 'Found ${matches.length} memories. Tap a photo to see details.');

    setState(() {

      _chatHistory.add(_ChatEntry.assistant(
        text: aiText ?? (matches.isNotEmpty ? header : null),
        results: matches,
        searchQuery: searchQuery,
        isLocalFallback: isLocalFallback,
      ));

    });

    final keyword = primaryKeywordForMemories(matches, searchQuery);

    ref.read(highlightedEntitiesProvider.notifier).state =

        keyword != null && keyword.isNotEmpty ? [keyword] : [];

  }



  void _runLocalSearch(String query, Map<String, String> t, {String? note}) {

    final localeCode = ref.read(languageProvider).languageCode;

    final parsed = _activeQuery ?? parseNaturalLanguageQuery(query, localeCode: localeCode);

    final imagePaths = ref.read(memoryImagePathsProvider);

    final videoPaths = ref.read(memoryVideoPathsProvider);

    bool hasPhotoFor(String id) => imagePaths[id]?.isNotEmpty == true;

    bool hasVideoFor(String id) => memoryHasVideo(id, videoPaths);

    final allMemories = ref.read(memoryListProvider);

    List<Memory> matches;

    if (parsed.isComposite) {

      matches = filterMemoriesByQuery(

        allMemories,

        parsed,

        localeCode: localeCode,

        hasPhotoFor: hasPhotoFor,

        hasVideoFor: hasVideoFor,

      );

      if (matches.isEmpty) {

        matches = traverseGraphForQuery(

          memories: allMemories,

          query: parsed,

          localeCode: localeCode,

        );

      }

      if (matches.isEmpty) {

        matches = searchWithMemoryQuery(

          memories: allMemories,

          query: parsed,

          localeCode: localeCode,

          hasPhotoFor: hasPhotoFor,

          hasVideoFor: hasVideoFor,

        );

      }

    } else {

      matches = searchMemoriesHybrid(

        memories: allMemories,

        query: query,

        deviceOnly: false,

      );

    }



    if (!mounted) return;

    if (matches.isEmpty) {

      setState(() {

        _chatHistory.add(_ChatEntry.assistant(text: t['no_results']!));

      });

      return;

    }



    final summary = parsed.isComposite ? describeMemoryQuery(parsed, localeCode: localeCode) : null;

    _pushResults(matches, aiText: note ?? summary, searchQuery: query, isLocalFallback: true);

  }



  Future<void> _refineWithActiveQuery() async {

    final query = _activeQuery;

    if (query == null || query.isEmpty) return;

    final t = ref.read(translationsProvider);

    final localeCode = ref.read(languageProvider).languageCode;

    final imagePaths = ref.read(memoryImagePathsProvider);

    final videoPaths = ref.read(memoryVideoPathsProvider);

    bool hasPhotoFor(String id) => imagePaths[id]?.isNotEmpty == true;

    bool hasVideoFor(String id) => memoryHasVideo(id, videoPaths);

    final allMemories = ref.read(memoryListProvider);

    var matches = filterMemoriesByQuery(

      allMemories,

      query,

      localeCode: localeCode,

      hasPhotoFor: hasPhotoFor,

      hasVideoFor: hasVideoFor,

    );

    if (matches.isEmpty) {

      matches = traverseGraphForQuery(

        memories: allMemories,

        query: query,

        localeCode: localeCode,

      );

    }

    if (!mounted) return;

    if (matches.isEmpty) {

      setState(() {

        if (_chatHistory.isNotEmpty && !_chatHistory.last.isUser) {

          _chatHistory.removeLast();

        }

        _chatHistory.add(_ChatEntry.assistant(text: t['no_results']!));

      });

      return;

    }

    final summary = describeMemoryQuery(query, localeCode: localeCode);

    setState(() {

      if (_chatHistory.isNotEmpty && !_chatHistory.last.isUser) {

        _chatHistory.removeLast();

      }

      _chatHistory.add(_ChatEntry.assistant(

        text: summary,

        results: matches,

        searchQuery: _lastSearchText,

      ));

    });

    final keyword = primaryKeywordForMemories(matches, _lastSearchText);

    ref.read(highlightedEntitiesProvider.notifier).state =

        keyword != null && keyword.isNotEmpty ? [keyword] : [];

  }



  void _onRemoveFilterChip(String chipId) {

    if (_activeQuery == null) return;

    setState(() => _activeQuery = _activeQuery!.removeChip(chipId));

    _refineWithActiveQuery();

  }



  void _onClearFilters() {

    setState(() => _activeQuery = null);

    if (_lastSearchText.isNotEmpty) {

      _searchController.text = _lastSearchText;

      _performSearch();

    }

  }



  Future<void> _performSearch() async {

    final query = _searchController.text.trim();

    if (query.isEmpty) return;

    if (!mounted) return;



    final localeCode = ref.read(languageProvider).languageCode;

    _activeQuery = parseNaturalLanguageQuery(query, localeCode: localeCode);

    _lastSearchText = query;



    if (requiresProForMemoryQuery(_activeQuery!) &&

        requiresProCloudForCloudFeatures &&

        !hasProEntitlement(ref.read(subscriptionStatusProvider))) {

      final unlocked = await requireProOrShowPaywall(

        context,

        ref,

        reasonKey: 'pro_reason_composite',

      );

      if (!mounted) return;

      if (!unlocked) return;

    }



    setState(() {

      _isLoading = true;

      _chatHistory.add(_ChatEntry.user(query));

    });

    _searchController.clear();



    try {

      final t = ref.read(translationsProvider);

      final useLocalSearch = isLocalOnlyMode(

        ref.read(preferencesProvider),

        privacyMode: ref.read(privacyLocalModeProvider),

        guestMode: ref.read(guestModeProvider),

      );



      if (!useLocalSearch && !AppEnv.isConfigured) {

        if (!requiresProCloudForCloudFeatures) {

          await _runGraphFirstSearch(query, t, useCloudEmbedding: false);

          return;

        }

        if (!mounted) return;

        setState(() {

          _chatHistory.add(_ChatEntry.assistant(text: t['search_requires_account']!));

        });

        return;

      }



      if (useLocalSearch) {

        _runLocalSearch(query, t);

        return;

      }



      final hasCloud = canUseCloudFeatures(

        ref.read(preferencesProvider),

        subscription: ref.read(subscriptionStatusProvider),

        privacyMode: ref.read(privacyLocalModeProvider),

        guestMode: ref.read(guestModeProvider),

      );



      if (!hasCloud) {

        if (!requiresProCloudForCloudFeatures) {

          await _runGraphFirstSearch(query, t, useCloudEmbedding: false);

          return;

        }

        _runLocalSearch(query, t, note: t['search_local_only_note']);

        return;
      }

      await _runGraphFirstSearch(query, t, useCloudEmbedding: true);

    } catch (e, stack) {

      await CrashReporting.recordError(e, stack, reason: 'vector_search');

      if (!mounted) return;

      final t = ref.read(translationsProvider);

      final msg = e is SubscriptionRequiredException

          ? t['pro_reason_search']!

          : e is QuotaExceededException

              ? t['pro_quota_exceeded']!

              : '${t['ocr_error']!} ($e)';

      setState(() {

        _chatHistory.add(_ChatEntry.assistant(text: msg));

      });

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  /// 그래프 DB 우선 → 필요 시 AI는 짧은 요약만.

  Future<void> _runGraphFirstSearch(

    String query,

    Map<String, String> t, {

    required bool useCloudEmbedding,

  }) async {

    final result = await SearchAnswerService.instance.answer(

      ref: ref,

      query: query,

      allMemories: ref.read(memoryListProvider),

      useCloudEmbedding: useCloudEmbedding,

      localeCode: ref.read(languageProvider).languageCode,

      languageName: languageNameForLocale(ref.read(languageProvider)),

    );



    if (!mounted) return;

    if (result.isEmpty) {

      setState(() {

        _chatHistory.add(_ChatEntry.assistant(text: t['no_results']!));

      });

      return;

    }



    if (result.parsedQuery != null) {

      _activeQuery = result.parsedQuery;

    }



    _pushResults(result.memories, aiText: result.answerText, searchQuery: query);

  }



  @override

  Widget build(BuildContext context) {

    final t = ref.watch(translationsProvider);

    final colorScheme = Theme.of(context).colorScheme;

    final imagePaths = ref.watch(memoryImagePathsProvider);

    final localeCode = ref.watch(languageProvider).languageCode;

    final highlighted = ref.watch(highlightedEntitiesProvider);



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

                  onSubmitted: (_) => _performSearch(),

                ),

              ),

              if (_chatHistory.isNotEmpty || _activeQuery != null)

                IconButton(

                  tooltip: t['clear_chat']!,

                  onPressed: () {

                    setState(() {

                      _chatHistory.clear();

                      _activeQuery = null;

                      _lastSearchText = '';

                    });

                    ref.read(highlightedEntitiesProvider.notifier).state = [];

                  },

                  icon: const Icon(Icons.delete_sweep_outlined),

                ),

            ],

          ),

        ),

        if (_activeQuery != null && _activeQuery!.isComposite)

          SearchFilterChipsBar(

            query: _activeQuery!,

            localeCode: localeCode,

            onRemoveChip: _onRemoveFilterChip,

            onClearAll: _onClearFilters,

          ),

        if (highlighted.isNotEmpty)

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),

            child: Align(

              alignment: Alignment.centerLeft,

              child: Wrap(

                spacing: 8,

                runSpacing: 6,

                children: highlighted.map((entity) {

                  return ActionChip(

                    avatar: const Icon(Icons.hub_outlined, size: 16),

                    label: Text(entity),

                    onPressed: () => openGraphKeywordFocus(ref, entity),

                  );

                }).toList(),

              ),

            ),

          ),

        if (_isLoading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),

        Expanded(

          child: _chatHistory.isEmpty

              ? _SearchCompositeHints(

                  localeCode: localeCode,

                  t: t,

                  onExampleTap: (example) {

                    _searchController.text = example;

                    _performSearch();

                  },

                )

              : ListView.builder(

            padding: const EdgeInsets.all(16),

            itemCount: _chatHistory.length,

            itemBuilder: (context, index) {

              final entry = _chatHistory[index];

              final isUser = entry.isUser;

              return Align(

                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

                child: Container(

                  margin: const EdgeInsets.only(bottom: 10),

                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),

                  decoration: BoxDecoration(

                    color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,

                    borderRadius: BorderRadius.circular(16),

                  ),

                  child: isUser

                      ? Text(entry.text ?? '')

                      : entry.results != null && entry.results!.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (entry.isLocalFallback) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.offline_bolt_outlined, size: 16, color: colorScheme.tertiary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            t['search_local_fallback_banner']!,
                                            style: TextStyle(fontSize: 11, height: 1.35, color: colorScheme.onTertiaryContainer),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                SearchMemoryResultsList(
                                  memories: entry.results!,
                                  imagePaths: imagePaths,
                                  localeCode: localeCode,
                                  header: entry.text,
                                  searchQuery: entry.searchQuery ?? '',
                                ),
                              ],
                            )

                          : Text(entry.text ?? ''),

                ),

              );

            },

          ),

        ),

      ],

    );

  }

}



class _SearchCompositeHints extends StatelessWidget {

  const _SearchCompositeHints({

    required this.localeCode,

    required this.t,

    required this.onExampleTap,

  });



  final String localeCode;

  final Map<String, String> t;

  final void Function(String query) onExampleTap;



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final examples = graphCompositeQueryHints(localeCode, count: 6);



    return ListView(

      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),

      children: [

        Icon(Icons.psychology_alt_rounded, size: 48, color: colorScheme.primary.withValues(alpha: 0.85)),

        const SizedBox(height: 12),

        Text(

          t['search_hint']!,

          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.35),

        ),

        const SizedBox(height: 20),

        Row(

          children: [

            Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.amber.shade700),

            const SizedBox(width: 6),

            Expanded(

              child: Text(

                t['search_composite_hint_title']!,

                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),

              ),

            ),

          ],

        ),

        const SizedBox(height: 6),

        Text(

          t['search_composite_pro_note']!,

          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),

        ),

        const SizedBox(height: 12),

        Wrap(

          spacing: 8,

          runSpacing: 8,

          children: examples.map((q) {

            return ActionChip(

              avatar: Icon(Icons.search_rounded, size: 16, color: colorScheme.primary),

              label: Text(q, style: theme.textTheme.bodySmall),

              onPressed: () => onExampleTap(q),

            );

          }).toList(),

        ),

      ],

    );

  }

}


