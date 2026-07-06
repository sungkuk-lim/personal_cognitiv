import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/graph_hub_config.dart';
import '../../core/graph_scale_config.dart';
import '../../core/prefs.dart';
import '../../services/graph_achievements_service.dart';
import '../../services/graph_ai_orchestrator.dart';
import '../../services/graph_insights_service.dart';
import '../../widgets/achievement_unlock_dialog.dart';
import '../../services/local_memory_store.dart';
import '../../features/memory/memory_media_hero.dart';
import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/person_avatar_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import '../../utils/semantic_search.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_time_filter.dart';
import '../../utils/memory_content_edit.dart';
import '../../widgets/person_node_avatar.dart';
import 'graph_chat_save.dart';
import 'graph_event_layout.dart';
import 'graph_help_sheet.dart';
import 'graph_layout.dart';
import 'graph_onboarding.dart';
import 'graph_node_ai_sheet.dart';
import 'graph_node_context.dart';
import 'graph_satellite_tap.dart';

class RelationshipGraphScreen extends ConsumerStatefulWidget {
  const RelationshipGraphScreen({super.key});

  @override
  ConsumerState<RelationshipGraphScreen> createState() => _RelationshipGraphScreenState();
}

class _RelationshipGraphScreenState extends ConsumerState<RelationshipGraphScreen> with WidgetsBindingObserver {
  final TransformationController _transformController = TransformationController();
  bool _draggingNode = false;
  Map<String, Offset>? _livePositions;
  int? _activePointer;
  String? _dragNodeId;
  Set<String> _dragGroup = {};
  bool _moveCluster = false;
  Offset? _lastCanvasPosition;
  bool _moved = false;
  Map<String, GraphSatelliteExpandMode> _satelliteExpansions = {};
  final Set<String> _collapsedSatelliteMemoryIds = {};
  ProviderSubscription<List<Memory>>? _achievementSub;
  ProviderSubscription<List<Memory>>? _memoryLayoutSub;
  ProviderSubscription<int>? _graphTabSub;
  String? _lastMemoryLayoutSignature;
  String? _layoutFingerprint;
  GraphLayout? _cachedLayout;
  Size? _cachedCanvasSize;
  Map<String, Offset>? _cachedDefaults;
  KeywordFocusGraphResult? _cachedFocusResult;
  MemoryFocusGraphResult? _cachedMemoryFocusResult;
  Map<String, Offset> _focusDragPositions = {};
  String? _focusDragScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    warmMemoryImagesDirectoryCache();
    warmMemoryVideosDirectoryCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAchievements();
      _warmContactAvatars();
      if (ref.read(mainNavigationTabProvider) == 2) {
        showGraphOnboardingIfNeeded(context, ref);
      }
    });
    _graphTabSub = ref.listenManual<int>(mainNavigationTabProvider, (prev, next) {
      if (next == 2 && mounted) {
        showGraphOnboardingIfNeeded(context, ref);
      }
    });
    _achievementSub = ref.listenManual<List<Memory>>(memoryListProvider, (_, _) => _checkAchievements());
    _memoryLayoutSub = ref.listenManual<List<Memory>>(memoryListProvider, (prev, next) {
      final sig = graphMemoryLayoutSignature(next.where(isUserFacingMemory));
      if (_lastMemoryLayoutSignature == sig) return;
      _lastMemoryLayoutSignature = sig;
      if (!mounted) return;
      setState(() {
        _layoutFingerprint = null;
        _cachedLayout = null;
        _cachedCanvasSize = null;
        _cachedDefaults = null;
        _cachedFocusResult = null;
        _cachedMemoryFocusResult = null;
      });
    });
    ref.listenManual<bool>(contactPersonAvatarsEnabledProvider, (prev, next) {
      if (next) {
        ref.read(personAvatarCacheProvider.notifier).reload();
      } else {
        ref.read(personAvatarCacheProvider.notifier).clearContactPhotos();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _achievementSub?.close();
    _memoryLayoutSub?.close();
    _graphTabSub?.close();
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _warmContactAvatars();
    }
  }

  void _warmContactAvatars() {
    if (!ref.read(contactPersonAvatarsEnabledProvider)) return;
    final cache = ref.read(personAvatarCacheProvider);
    if (!cache.loaded || cache.photos.isEmpty) {
      ref.read(personAvatarCacheProvider.notifier).reload();
    }
  }

  Future<void> _checkAchievements() async {
    if (!mounted) return;
    final prefs = ref.read(preferencesProvider);
    final memories = ref.read(memoryListProvider);
    if (memories.isEmpty) return;
    final fragments = ref.read(memoryGraphFragmentsProvider);
    final newly = await checkAndUnlockGraphAchievements(
      prefs: prefs,
      memories: memories,
      fragments: fragments,
    );
    if (!mounted) return;
    final localeCode = ref.read(languageProvider).languageCode;
    for (final achievement in newly) {
      if (!mounted) return;
      await showAchievementUnlockDialog(context, achievement: achievement, localeCode: localeCode);
    }
    if (newly.isNotEmpty && mounted) setState(() {});
  }

  void _toggleSatelliteExpansion(
    String memoryId,
    GraphSatelliteExpandMode mode, {
    required List<Memory> memories,
    required Map<String, GraphMemoryFragment> fragments,
    required String localeCode,
  }) {
    final resolved = mergeDefaultSatelliteExpansions(
      memories: memories,
      userExpansions: _satelliteExpansions,
      collapsedMemoryIds: _collapsedSatelliteMemoryIds,
      graphFragments: fragments,
      localeCode: localeCode,
    );
    final activeMode = resolved[memoryId];

    setState(() {
      final collapsed = Set<String>.from(_collapsedSatelliteMemoryIds);
      final expansions = Map<String, GraphSatelliteExpandMode>.from(_satelliteExpansions);

      if (shouldCollapseSatellitesOnBadgeTap(activeMode: activeMode, tappedMode: mode)) {
        collapsed.add(memoryId);
        expansions.remove(memoryId);
      } else {
        collapsed.remove(memoryId);
        expansions[memoryId] = mode;
      }
      _collapsedSatelliteMemoryIds
        ..clear()
        ..addAll(collapsed);
      _satelliteExpansions = expansions;
      _layoutFingerprint = null;
      _livePositions = null;
    });
  }

  void _expandSatelliteAll(String memoryId) {
    setState(() {
      _collapsedSatelliteMemoryIds.remove(memoryId);
      _satelliteExpansions = {
        ..._satelliteExpansions,
        memoryId: GraphSatelliteExpandMode.all,
      };
      _layoutFingerprint = null;
      _livePositions = null;
    });
  }

  void _onGraphChatSaved(String memoryId) {
    if (!mounted) return;
    final memories = ref.read(memoryListProvider);
    final saved = memories.where((m) => m.id == memoryId).firstOrNull;
    final expandId = saved != null && isGraphNoteMemory(saved)
        ? (graphNoteRelatedMemoryId(saved) ?? memoryId)
        : memoryId;
    _expandSatelliteAll(expandId);
    if (saved != null && isGraphNoteMemory(saved)) {
      final anchorId = canonicalGraphAnchorNodeId(
        graphNoteAnchorNodeId(saved) ?? '',
        anchorLabel: graphNoteAnchorLabel(saved),
      );
      if (anchorId.isNotEmpty) {
        ref.read(selectedGraphNodeProvider.notifier).state = anchorId;
      }
    }
    final t = ref.read(translationsProvider);
    final anchorLabel = saved != null ? graphNoteAnchorLabel(saved) : null;
    final message = anchorLabel != null && anchorLabel.isNotEmpty
        ? t['graph_node_ai_saved_graph_anchor']!.replaceAll('{anchor}', anchorLabel)
        : t['graph_node_ai_saved_graph']!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  GraphChatSavedCallback get _graphChatSavedHandler => _onGraphChatSaved;

  void _collapseAllSatellites(List<Memory> memories) {
    setState(() {
      _satelliteExpansions = {};
      _collapsedSatelliteMemoryIds
        ..clear()
        ..addAll(memories.where(isLayoutPrimaryMemory).map((m) => m.id));
      _layoutFingerprint = null;
    });
  }

  String? _nodeAt(Offset canvasPos, List<GraphNodeData> nodes, Map<String, Offset> positions) {
    final sorted = [...nodes]
      ..sort((a, b) {
        if (a.isMemory == b.isMemory) return 0;
        return a.isMemory ? -1 : 1;
      });
    for (final node in sorted.reversed) {
      final center = positions[node.id];
      if (center == null) continue;
      final slop = node.isMemory ? 14.0 : 18.0;
      final rect = Rect.fromCenter(
        center: center,
        width: node.size.width + slop * 2,
        height: node.size.height + slop * 2,
      );
      if (rect.contains(canvasPos)) return node.id;
    }
    return null;
  }

  void _beginDrag(Map<String, Offset> positions) {
    _livePositions = Map<String, Offset>.from(positions);
  }

  void _applyDragDelta({
    required String primaryNodeId,
    required Offset delta,
  }) {
    if (delta == Offset.zero || _livePositions == null) return;
    if (_moveCluster) {
      for (final id in _dragGroup) {
        final base = _livePositions![id];
        if (base != null) _livePositions![id] = base + delta;
      }
    } else {
      final base = _livePositions![primaryNodeId];
      if (base != null) _livePositions![primaryNodeId] = base + delta;
    }
  }

  void _finishDrag(WidgetRef ref) {
    final live = _livePositions;
    if (live != null && _moved) {
      final focusMemoryId = ref.read(graphFocusMemoryIdProvider)?.trim();
      final focusKeyword = ref.read(graphFocusKeywordProvider)?.trim();
      if ((focusMemoryId != null && focusMemoryId.isNotEmpty) ||
          (focusKeyword != null && focusKeyword.isNotEmpty)) {
        setState(() {
          _focusDragPositions = {..._focusDragPositions, ...live};
        });
      } else {
        ref.read(graphNodePositionsProvider.notifier).state = {
          ...ref.read(graphNodePositionsProvider),
          ...live,
        };
        saveGraphPositions(ref.read(preferencesProvider), ref.read(graphNodePositionsProvider));
      }
    }
    _livePositions = null;
  }

  void _resetPointerState() {
    _activePointer = null;
    _dragNodeId = null;
    _dragGroup = {};
    _moveCluster = false;
    _lastCanvasPosition = null;
    _moved = false;
    _draggingNode = false;
  }

  void _handlePointerDown(
    PointerDownEvent event,
    List<GraphNodeData> nodes,
    List<GraphEdgeData> edges,
    Map<String, Offset> positions,
  ) {
    _activePointer = event.pointer;
    _lastCanvasPosition = _transformController.toScene(event.localPosition);
    _moved = false;
    final nodeId = _nodeAt(_lastCanvasPosition!, nodes, positions);
    if (nodeId == null) return;

    _dragNodeId = nodeId;
    _dragGroup = dragGroupForNode(nodeId, edges, nodes);
    _moveCluster = false;
    _beginDrag(positions);
    setState(() => _draggingNode = true);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _dragNodeId == null || _livePositions == null) return;
    final canvasPos = _transformController.toScene(event.localPosition);
    final last = _lastCanvasPosition;
    if (last == null) return;
    final delta = canvasPos - last;
    _lastCanvasPosition = canvasPos;
    if (delta == Offset.zero) return;
    _moved = true;
    setState(() {
      _applyDragDelta(primaryNodeId: _dragNodeId!, delta: delta);
    });
  }

  void _handlePointerEnd(
    PointerEvent event,
    WidgetRef ref,
    List<Memory> memories,
    Map<String, List<String>> imagePaths,
    Map<String, List<String>> videoPaths,
    List<GraphNodeData> nodes,
    List<GraphEdgeData> edges,
    Map<String, Offset> positions,
  ) {
    if (_activePointer != event.pointer) return;
    if (_dragNodeId != null && !_moved) {
      ref.read(selectedGraphNodeProvider.notifier).state = _dragNodeId;
      final nodeId = _dragNodeId!;
      final localeCode = ref.read(languageProvider).languageCode;
      final graphAiOn = isGraphAiActive(
        prefs: ref.read(preferencesProvider),
        graphAiEnabled: ref.read(graphAiEnabledProvider),
        privacyMode: ref.read(privacyLocalModeProvider),
        guestMode: isLocalOnlyMode(
          ref.read(preferencesProvider),
          privacyMode: ref.read(privacyLocalModeProvider),
          guestMode: ref.read(guestModeProvider),
        ),
        subscription: ref.read(subscriptionStatusProvider),
      );
      final fragments = graphAiOn ? ref.read(memoryGraphFragmentsProvider) : const <String, GraphMemoryFragment>{};
      GraphNodeData? tappedNode;
      for (final n in nodes) {
        if (n.id == nodeId) {
          tappedNode = n;
          break;
        }
      }
      if (nodeId.startsWith('memory_')) {
        final memoryId = nodeId.replaceFirst('memory_', '');
        final badge = tappedNode?.satelliteBadge;
        final center = positions[nodeId];
        final canvasPos = _lastCanvasPosition;

        if (badge != null && badge.isNotEmpty && tappedNode != null && center != null && canvasPos != null) {
          final badgeMode = satelliteModeFromRailTap(
            canvasPos: canvasPos,
            nodeCenter: center,
            nodeSize: tappedNode.size,
            badgeText: badge,
            localeCode: localeCode,
          );
          if (badgeMode != null) {
            _toggleSatelliteExpansion(
              memoryId,
              badgeMode,
              memories: memories,
              fragments: fragments,
              localeCode: localeCode,
            );
            _finishDrag(ref);
            _resetPointerState();
            return;
          }
        }

        if (tappedNode != null && mounted) {
          showGraphNodeAiSheet(
            context,
            ref,
            node: tappedNode,
            edges: edges,
            imagePaths: imagePaths,
            videoPaths: videoPaths,
            onSaved: _graphChatSavedHandler,
          );
        }
      } else if (nodeId.startsWith('group_') || nodeId.startsWith('focus_hub_') || nodeId.startsWith('event_hub_')) {
        if (tappedNode != null && mounted) {
          showGraphNodeAiSheet(
            context,
            ref,
            node: tappedNode,
            edges: edges,
            imagePaths: imagePaths,
            videoPaths: videoPaths,
            onSaved: _graphChatSavedHandler,
          );
        }
      } else if (tappedNode != null && mounted) {
        final kind = tappedNode.kind;
        if (kind == GraphNodeKind.person ||
            kind == GraphNodeKind.place ||
            kind == GraphNodeKind.activity) {
          showGraphEntityMediaSheet(
            context,
            ref,
            node: tappedNode,
            imagePaths: imagePaths,
          );
        } else {
          showGraphNodeAiSheet(
            context,
            ref,
            node: tappedNode,
            edges: edges,
            imagePaths: imagePaths,
            videoPaths: videoPaths,
            onSaved: _graphChatSavedHandler,
          );
        }
      }
    }
    if (_dragNodeId != null) _finishDrag(ref);
    setState(_resetPointerState);
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryListProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final videoPaths = ref.watch(memoryVideoPathsProvider);
    final highlightedEntities = ref.watch(highlightedEntitiesProvider);
    final selectedNodeId = ref.watch(selectedGraphNodeProvider);
    final storedPositions = ref.watch(graphNodePositionsProvider);
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (memories.isEmpty) {
      return Center(child: Text(t['no_graph']!));
    }

    final focusMemoryId = ref.watch(graphFocusMemoryIdProvider);
    final focusKeyword = ref.watch(graphFocusKeywordProvider);
    final isMemoryFocusMode = focusMemoryId != null && focusMemoryId.trim().isNotEmpty;
    final isKeywordFocusMode =
        !isMemoryFocusMode && focusKeyword != null && focusKeyword.trim().isNotEmpty;
    final isFocusMode = isMemoryFocusMode || isKeywordFocusMode;
    final focusScope = isMemoryFocusMode
        ? 'mem:${focusMemoryId!.trim()}'
        : (isKeywordFocusMode ? 'kw:${focusKeyword!.trim()}' : null);
    if (_focusDragScope != focusScope) {
      _focusDragScope = focusScope;
      _focusDragPositions = {};
    }
    final graphTabActive = ref.watch(mainNavigationTabProvider) == 2;
    final graphSearchQuery = ref.watch(graphEntitySearchProvider).trim().toLowerCase();
    final landscapeImmersive =
        graphTabActive && MediaQuery.orientationOf(context) == Orientation.landscape;
    final timeRange = ref.watch(graphTimeRangeProvider);
    final totalMemoryCount = memories.length;
    final visibleMemories = isFocusMode
        ? memories
        : filterMemoriesForGraphRange(memories, timeRange);
    var layoutMemories = visibleMemories;
    var layoutCapApplied = false;
    if (!isFocusMode && layoutMemories.length > GraphScaleConfig.maxLayoutMemories) {
      layoutMemories = [...layoutMemories]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      layoutMemories = layoutMemories.take(GraphScaleConfig.maxLayoutMemories).toList();
      layoutCapApplied = true;
    }
    final showScaleBanner = !isFocusMode &&
        totalMemoryCount >= GraphScaleConfig.performanceBannerThreshold &&
        timeRange == GraphTimeRange.all;

    if (!isFocusMode && visibleMemories.isEmpty) {
      return Column(
        children: [
          _GraphTimeRangeBar(
            timeRange: timeRange,
            totalCount: totalMemoryCount,
            visibleCount: 0,
            onRangeChanged: (range) {
              ref.read(graphTimeRangeProvider.notifier).state = range;
              writeGraphTimeRange(ref.read(preferencesProvider), range);
            },
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  t['graph_range_empty']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                ),
              ),
            ),
          ),
          if (!landscapeImmersive) _GraphTrustHintBar(graphAiOn: false),
        ],
      );
    }

    final prefs = ref.watch(preferencesProvider);
    final graphAiOn = isGraphAiActive(
      prefs: prefs,
      graphAiEnabled: ref.watch(graphAiEnabledProvider),
      privacyMode: ref.watch(privacyLocalModeProvider),
      guestMode: isLocalOnlyMode(
        prefs,
        privacyMode: ref.watch(privacyLocalModeProvider),
        guestMode: ref.watch(guestModeProvider),
      ),
      subscription: ref.watch(subscriptionStatusProvider),
    );
    final localeCode = ref.watch(languageProvider).languageCode;
    final hubViewMode = ref.watch(graphHubViewModeProvider);
    final Map<String, GraphMemoryFragment> fragments =
        graphAiOn ? ref.watch(memoryGraphFragmentsProvider) : const {};
    final placeCache = ref.watch(memoryPlaceNamesProvider);
    final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);

    late final GraphLayout layout;
    late final Size canvasSize;
    late final Map<String, Offset> defaults;
    KeywordFocusGraphResult? focusResult;
    MemoryFocusGraphResult? memoryFocusResult;
    final keyword = focusKeyword?.trim() ?? '';
    final mergedExpansions = isFocusMode
        ? const <String, GraphSatelliteExpandMode>{}
        : mergeDefaultSatelliteExpansions(
            memories: layoutMemories,
            userExpansions: _satelliteExpansions,
            collapsedMemoryIds: _collapsedSatelliteMemoryIds,
            graphFragments: fragments,
            localeCode: localeCode,
          );
    final memoryKey = graphMemoryLayoutSignature(layoutMemories);
    final expansionKey = mergedExpansions.entries.map((e) => '${e.key}:${e.value.name}').join('|');
    final collapseKey = _collapsedSatelliteMemoryIds.join(',');
    final fragmentKey = fragments.entries.map((e) => '${e.key}:${e.value.meaningTitle}').join('|');
    final fingerprint = isMemoryFocusMode
        ? 'memfocus:${focusMemoryId!.trim()}:$memoryKey:$localeCode:$fragmentKey'
        : isKeywordFocusMode
            ? 'focus:$keyword:$memoryKey:$localeCode'
            : 'full:$memoryKey:$expansionKey:$collapseKey:$localeCode:$graphAiOn:${hubViewMode.name}:$fragmentKey';

    if (_layoutFingerprint == fingerprint &&
        _cachedLayout != null &&
        _cachedCanvasSize != null &&
        _cachedDefaults != null) {
      layout = _cachedLayout!;
      canvasSize = _cachedCanvasSize!;
      defaults = _cachedDefaults!;
      focusResult = _cachedFocusResult;
      memoryFocusResult = _cachedMemoryFocusResult;
    } else if (isMemoryFocusMode) {
      Memory? focusMemory;
      for (final m in memories) {
        if (m.id == focusMemoryId!.trim()) {
          focusMemory = m;
          break;
        }
      }
      if (focusMemory == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t['graph_memory_focus_missing']!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => clearGraphFocus(ref),
                  child: Text(t['graph_focus_show_all']!),
                ),
              ],
            ),
          ),
        );
      }
      memoryFocusResult = buildMemoryFocusGraphLayout(
        focusMemory,
        placeCache: placeCache,
        fullAddressCache: fullAddressCache,
        graphFragments: fragments,
        localeCode: localeCode,
        photoCountFor: (id) => imageCountForMemoryId(id, imagePaths),
        hasVideoFor: (id) => memoryHasVideo(id, videoPaths),
      );
      layout = memoryFocusResult.layout;
      canvasSize = memoryFocusCanvasSize(layout.nodes.length);
      defaults = initialGraphPositions(layout.nodes, layout.edges, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = null;
      _cachedMemoryFocusResult = memoryFocusResult;
    } else if (isKeywordFocusMode) {
      focusResult = buildKeywordFocusGraphLayout(
        keyword,
        visibleMemories,
        placeCache: placeCache,
        fullAddressCache: fullAddressCache,
        graphFragments: fragments,
        localeCode: localeCode,
      );
      layout = focusResult.layout;
      canvasSize = keywordFocusCanvasSize(focusResult.shownCount);
      defaults = initialKeywordFocusPositions(layout.nodes, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = focusResult;
      _cachedMemoryFocusResult = null;
    } else if (hubViewMode == GraphHubViewMode.eventHub) {
      layout = buildEventGraphLayout(
        layoutMemories,
        placeCache: placeCache,
        fullAddressCache: fullAddressCache,
        graphFragments: fragments,
        localeCode: localeCode,
      );
      final eventCount = layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub).length;
      canvasSize = eventGraphCanvasSize(eventCount);
      defaults = initialEventGraphPositions(layout.nodes, layout.edges, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = null;
      _cachedMemoryFocusResult = null;
    } else {
      layout = buildMemoryGraphLayout(
        layoutMemories,
        placeCache: placeCache,
        fullAddressCache: fullAddressCache,
        graphFragments: fragments,
        graphClusters: graphAiOn ? ref.watch(memoryGraphClustersProvider) : const <String, GraphClusterSnapshot>{},
        localeCode: localeCode,
        photoCountFor: (id) => imageCountForMemoryId(id, imagePaths),
        hasVideoFor: (id) => memoryHasVideo(id, videoPaths),
        satelliteExpansions: mergedExpansions,
        collapseSatellitesByDefault: true,
      );
      final layoutClusterCount = layout.nodes.map((n) => n.layoutClusterId).toSet().length;
      canvasSize = graphCanvasSize(layoutClusterCount);
      defaults = initialGraphPositions(layout.nodes, layout.edges, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = null;
    }

    if (isKeywordFocusMode && focusResult!.totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t['graph_focus_empty']!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => clearGraphFocus(ref),
                child: Text(t['graph_focus_show_all']!),
              ),
            ],
          ),
        ),
      );
    }

    final nodeMap = {for (final node in layout.nodes) node.id: node};
    final basePositions = <String, Offset>{};
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    for (final node in layout.nodes) {
      basePositions[node.id] = isFocusMode
          ? (_focusDragPositions[node.id] ?? defaults[node.id] ?? center)
          : (storedPositions[node.id] ?? defaults[node.id] ?? center);
    }
    final positions = _livePositions ?? basePositions;

    int paintOrder(GraphNodeData node) {
      if (node.isMemory) return 0;
      if (node.kind == GraphNodeKind.eventHub) return 2;
      if (node.id.startsWith('group_')) return 3;
      if (node.id.startsWith('entity_note_')) return 2;
      return 1;
    }

    final sortedNodes = [...layout.nodes]..sort((a, b) => paintOrder(a).compareTo(paintOrder(b)));

    final memoryById = {for (final m in visibleMemories) m.id: m};
    final insights = generateGraphInsights(
      memories: layoutMemories,
      fragments: fragments,
      localeCode: localeCode,
    );

    final graphCanvas = Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _handlePointerDown(event, layout.nodes, layout.edges, positions),
          onPointerMove: _handlePointerMove,
          onPointerUp: (event) =>
              _handlePointerEnd(event, ref, visibleMemories, imagePaths, videoPaths, layout.nodes, layout.edges, positions),
          onPointerCancel: (event) =>
              _handlePointerEnd(event, ref, visibleMemories, imagePaths, videoPaths, layout.nodes, layout.edges, positions),
          child: InteractiveViewer(
            transformationController: _transformController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1000),
            minScale: 0.01,
            maxScale: 5.0,
            panEnabled: !_draggingNode,
            scaleEnabled: !_draggingNode,
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: canvasSize,
                    painter: GraphEdgesPainter(
                      edges: layout.edges,
                      positions: positions,
                      nodeMap: nodeMap,
                      isDark: isDark,
                    ),
                  ),
                  ...sortedNodes.map((node) {
                    final position = positions[node.id]!;
                    final entityName = node.isMemory ? null : node.title;
                    final linkedMemory = node.id.startsWith('memory_')
                        ? memoryById[node.id.replaceFirst('memory_', '')]
                        : null;
                    final isHighlighted = isFocusMode
                        ? (isMemoryFocusMode ||
                            node.id.startsWith('focus_hub_') ||
                            node.isMemory)
                        : node.isMemory
                            ? linkedMemory != null && memoryMatchesAnyEntity(linkedMemory, highlightedEntities)
                            : highlightedEntities.contains(entityName) || highlightedEntities.contains(node.title);
                    final matchesGraphSearch = graphSearchQuery.isEmpty ||
                        node.title.toLowerCase().contains(graphSearchQuery) ||
                        node.placeLabel.toLowerCase().contains(graphSearchQuery) ||
                        node.subtitle.toLowerCase().contains(graphSearchQuery);
                    final isDimmed = graphSearchQuery.isNotEmpty && !matchesGraphSearch;
                    final showHighlight = isHighlighted || (graphSearchQuery.isNotEmpty && matchesGraphSearch);
                    final isSelected = selectedNodeId == node.id;
                    final isDragging = _draggingNode && _dragGroup.contains(node.id);

                    final thumbPath = primaryMediaThumbForGraphNode(
                      node: node,
                      memories: visibleMemories,
                      imagePaths: imagePaths,
                      videoPaths: videoPaths,
                    );
                    final photoCount = photoCountForGraphNode(
                      node: node,
                      memories: visibleMemories,
                      imagePaths: imagePaths,
                    );
                    final showVideoBadge = graphNodeHasVideo(
                      node: node,
                      memories: visibleMemories,
                      videoPaths: videoPaths,
                    );

                    final memoryId = node.id.startsWith('memory_') ? node.id.replaceFirst('memory_', '') : null;
                    final satellitesExpanded =
                        memoryId != null && mergedExpansions.containsKey(memoryId);

                    return Positioned(
                      key: ValueKey('${node.id}_${thumbPath ?? ''}'),
                      left: position.dx - node.size.width / 2,
                      top: position.dy - node.size.height / 2,
                      child: Opacity(
                        opacity: isDimmed ? 0.28 : 1,
                        child: Semantics(
                          label: node.title,
                          hint: node.satelliteBadge,
                          button: true,
                          child: _GraphNodeCard(
                            node: node,
                            isHighlighted: showHighlight,
                            isSelected: isSelected,
                            isDragging: isDragging,
                            isDark: isDark,
                            thumbnailPath: thumbPath,
                            photoCount: photoCount,
                            showVideoBadge: showVideoBadge,
                            satelliteBadge: node.satelliteBadge,
                            satellitesExpanded: satellitesExpanded,
                            localeCode: localeCode,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        if (!landscapeImmersive && !isFocusMode && _satelliteExpansions.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: _GraphSatelliteChip(
              count: _satelliteExpansions.length,
              collapseLabel: t['graph_satellite_collapse']!,
              onCollapse: () => _collapseAllSatellites(visibleMemories),
            ),
          ),
      ],
    );

    return Column(
      children: [
        if (!landscapeImmersive && !isFocusMode)
          _GraphHubModeBar(
            mode: hubViewMode,
            memoryHubLabel: t['graph_hub_memory']!,
            eventHubLabel: t['graph_hub_event']!,
            onModeChanged: (mode) {
              ref.read(graphHubViewModeProvider.notifier).state = mode;
              writeGraphHubViewMode(ref.read(preferencesProvider), mode);
              setState(() {
                _layoutFingerprint = null;
                _cachedLayout = null;
              });
              _collapseAllSatellites(visibleMemories);
            },
          ),
        if (!landscapeImmersive && !isFocusMode && showScaleBanner)
          _GraphScaleHintBanner(
            total: totalMemoryCount,
            onPickRange: (range) {
              ref.read(graphTimeRangeProvider.notifier).state = range;
              writeGraphTimeRange(ref.read(preferencesProvider), range);
              _collapseAllSatellites(layoutMemories);
            },
          ),
        if (!landscapeImmersive && !isFocusMode && layoutCapApplied)
          _GraphLayoutCapBanner(cap: GraphScaleConfig.maxLayoutMemories),
        if (!landscapeImmersive && !isFocusMode)
          _GraphTimeRangeBar(
            timeRange: timeRange,
            totalCount: totalMemoryCount,
            visibleCount: layoutMemories.length,
            insights: insights,
            onRangeChanged: (range) {
              ref.read(graphTimeRangeProvider.notifier).state = range;
              writeGraphTimeRange(ref.read(preferencesProvider), range);
              _collapseAllSatellites(visibleMemories);
            },
          ),
        if (!landscapeImmersive && isMemoryFocusMode && memoryFocusResult != null)
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                children: [
                  Icon(Icons.memory_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t['graph_memory_focus_banner']!
                          .replaceAll('{title}', memoryFocusResult.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => clearGraphFocus(ref),
                    child: Text(t['graph_focus_show_all']!),
                  ),
                ],
              ),
            ),
          ),
        if (!landscapeImmersive && isKeywordFocusMode && focusResult != null)
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                children: [
                  Icon(Icons.filter_center_focus, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t['graph_focus_banner']!
                          .replaceAll('{keyword}', keyword)
                          .replaceAll('{count}', '${focusResult.totalCount}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (focusResult.hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        t['graph_focus_more']!.replaceAll('{n}', '${focusResult.hiddenCount}'),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => clearGraphFocus(ref),
                    child: Text(t['graph_focus_show_all']!),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: landscapeImmersive
              ? SafeArea(top: false, bottom: false, child: graphCanvas)
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    graphCanvas,
                    if (!isFocusMode)
                      _GraphDraggableSearchFab(
                        hint: t['graph_entity_search_hint']!,
                        query: ref.watch(graphEntitySearchProvider),
                        onChanged: (v) => ref.read(graphEntitySearchProvider.notifier).state = v,
                        onClear: () => ref.read(graphEntitySearchProvider.notifier).state = '',
                      ),
                  ],
                ),
        ),
        if (!landscapeImmersive) _GraphTrustHintBar(graphAiOn: graphAiOn),
      ],
    );
  }
}

class _GraphSatelliteChip extends StatelessWidget {
  const _GraphSatelliteChip({
    required this.count,
    required this.collapseLabel,
    required this.onCollapse,
  });

  final int count;
  final String collapseLabel;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onCollapse,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
              Text('$count', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(collapseLabel, style: theme.textTheme.labelSmall),
              const SizedBox(width: 2),
              Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphDraggableSearchFab extends StatefulWidget {
  const _GraphDraggableSearchFab({
    required this.hint,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String hint;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_GraphDraggableSearchFab> createState() => _GraphDraggableSearchFabState();
}

class _GraphDraggableSearchFabState extends State<_GraphDraggableSearchFab> {
  bool _expanded = false;
  Offset _fabOffset = const Offset(12, 12);
  final _focusNode = FocusNode();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _GraphDraggableSearchFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
      } else {
        _focusNode.unfocus();
        widget.onClear();
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const fabSize = 48.0;
        final maxX = (constraints.maxWidth - fabSize - 8).clamp(8.0, double.infinity);
        final maxY = (constraints.maxHeight - fabSize - 8).clamp(8.0, double.infinity);
        final dx = _fabOffset.dx.clamp(8.0, maxX);
        final dy = _fabOffset.dy.clamp(8.0, maxY);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_expanded)
              Positioned(
                left: 12,
                right: fabSize + 24,
                top: dy,
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  color: colorScheme.surfaceContainerHighest,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: widget.query.isEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _toggleExpanded,
                            )
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                widget.onClear();
                                _controller.clear();
                              },
                            ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: dx,
              top: dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _fabOffset += details.delta;
                  });
                },
                child: FloatingActionButton.small(
                  heroTag: 'graph_entity_search_fab',
                  elevation: _expanded ? 8 : 4,
                  backgroundColor: _expanded ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  foregroundColor: _expanded ? colorScheme.onPrimary : colorScheme.primary,
                  onPressed: _toggleExpanded,
                  child: Icon(_expanded ? Icons.close_rounded : Icons.search_rounded),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GraphHubModeBar extends StatelessWidget {
  const _GraphHubModeBar({
    required this.mode,
    required this.memoryHubLabel,
    required this.eventHubLabel,
    required this.onModeChanged,
  });

  final GraphHubViewMode mode;
  final String memoryHubLabel;
  final String eventHubLabel;
  final ValueChanged<GraphHubViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: _HubModeTile(
                selected: mode == GraphHubViewMode.memoryHub,
                label: memoryHubLabel,
                icon: Icons.auto_stories_rounded,
                onTap: () => onModeChanged(GraphHubViewMode.memoryHub),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HubModeTile(
                selected: mode == GraphHubViewMode.eventHub,
                label: eventHubLabel,
                icon: Icons.event_rounded,
                onTap: () => onModeChanged(GraphHubViewMode.eventHub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubModeTile extends StatelessWidget {
  const _HubModeTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final fg = selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface.withValues(alpha: 0.75);
    final borderSide = selected
        ? BorderSide(color: colorScheme.primary.withValues(alpha: 0.45), width: 1.5)
        : BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.35));

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: borderSide),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphTimeRangeBar extends ConsumerWidget {
  const _GraphTimeRangeBar({
    required this.timeRange,
    required this.totalCount,
    required this.visibleCount,
    required this.onRangeChanged,
    this.insights = const [],
  });

  final GraphTimeRange timeRange;
  final int totalCount;
  final int visibleCount;
  final ValueChanged<GraphTimeRange> onRangeChanged;
  final List<GraphInsight> insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    String labelFor(GraphTimeRange r) => switch (r) {
          GraphTimeRange.days7 => t['graph_range_7d']!,
          GraphTimeRange.days30 => t['graph_range_30d']!,
          GraphTimeRange.days90 => t['graph_range_90d']!,
          GraphTimeRange.all => t['graph_range_all']!,
        };

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 4, 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              tooltip: t['graph_help_title']!,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => showGraphHelpSheet(
                context,
                t: t,
                timeRange: timeRange,
                totalCount: totalCount,
                visibleCount: visibleCount,
                insights: insights,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: GraphTimeRange.values.map((range) {
                    final selected = range == timeRange;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(labelFor(range), style: const TextStyle(fontSize: 13)),
                        selected: selected,
                        onSelected: (_) => onRangeChanged(range),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// 기억 허브 왼쪽 위성 레일 — 탭 영역이 넓고 내용과 겹치지 않습니다.
class _GraphSatelliteRail extends StatelessWidget {
  const _GraphSatelliteRail({
    required this.badgeText,
    required this.expanded,
    required this.localeCode,
    required this.isDark,
    required this.hasThumb,
  });

  final String badgeText;
  final bool expanded;
  final String localeCode;
  final bool isDark;
  final bool hasThumb;

  @override
  Widget build(BuildContext context) {
    final segments = parseSatelliteRailSegments(badgeText, localeCode: localeCode);
    final railColor = hasThumb
        ? Colors.black.withValues(alpha: 0.55)
        : (isDark ? Colors.black.withValues(alpha: 0.42) : Colors.black.withValues(alpha: 0.28));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: railColor,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.28), width: 1),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          segments[i].icon,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 1),
                        Text(
                          '${segments[i].count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphNodeCard extends StatelessWidget {
  final GraphNodeData node;
  final bool isHighlighted;
  final bool isSelected;
  final bool isDragging;
  final bool isDark;
  final String? thumbnailPath;
  final int photoCount;
  final bool showVideoBadge;
  final String? satelliteBadge;
  final bool satellitesExpanded;
  final String localeCode;

  const _GraphNodeCard({
    required this.node,
    required this.isHighlighted,
    required this.isSelected,
    required this.isDragging,
    required this.isDark,
    this.thumbnailPath,
    this.photoCount = 0,
    this.showVideoBadge = false,
    this.satelliteBadge,
    this.satellitesExpanded = false,
    this.localeCode = 'ko',
  });

  bool get _hasSatelliteRail =>
      node.isMemory && satelliteBadge != null && satelliteBadge!.trim().isNotEmpty;

  bool get _isPersonNode => node.kind == GraphNodeKind.person;

  double get _railWidth => memorySatelliteRailWidth(node.size);

  @override
  Widget build(BuildContext context) {
    final accent = isHighlighted ? Colors.amber : node.color;
    final borderColor = isSelected || isDragging ? Colors.white : accent.withValues(alpha: 0.85);
    final hasThumb = thumbnailPath != null && File(thumbnailPath!).existsSync();

    return IgnorePointer(
      child: AnimatedContainer(
        duration: isDragging ? Duration.zero : const Duration(milliseconds: 180),
        width: node.size.width,
        height: node.size.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(node.isMemory ? 22 : 18),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: isDark ? 0.35 : 0.25), blurRadius: isHighlighted || isDragging ? 22 : 14, spreadRadius: isHighlighted || isDragging ? 1 : 0, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              node.isMemory
                  ? MemoryMediaHeroImage(
                      memoryId: node.id.replaceFirst('memory_', ''),
                      photoIndex: 0,
                      path: thumbnailPath!,
                      width: node.size.width,
                      height: node.size.height,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(thumbnailPath!),
                      width: node.size.width,
                      height: node.size.height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            if (hasThumb)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: node.size.height * (node.isMemory ? 0.55 : 0.45),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(node.isMemory ? 22 : 18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(node.isMemory ? 22 : 18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: node.isMemory
                        ? [accent.withValues(alpha: isDark ? 0.55 : 0.82), accent.withValues(alpha: isDark ? 0.28 : 0.55)]
                        : [Colors.white.withValues(alpha: isDark ? 0.14 : 0.92), accent.withValues(alpha: isDark ? 0.22 : 0.18)],
                  ),
                ),
              ),
            if (_isPersonNode)
              _buildPersonNodeBody(hasThumb: hasThumb, accent: accent)
            else
              Padding(
              padding: EdgeInsets.fromLTRB(
                _hasSatelliteRail ? _railWidth + 6 : 10,
                8,
                10,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: hasThumb ? MainAxisAlignment.end : MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTheme.graphNodeTitle(context, onPhoto: hasThumb, primary: node.isPrimaryCard),
                    ),
                  ),
                  if (node.isPrimaryCard) ...[
                    if (node.dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          node.dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.graphNodeMeta(context, onPhoto: hasThumb),
                        ),
                      ),
                    ],
                    if (node.placeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          node.placeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.15,
                            fontWeight: FontWeight.w400,
                            color: hasThumb
                                ? Colors.white.withValues(alpha: 0.82)
                                : Colors.white.withValues(alpha: isDark ? 0.78 : 0.68),
                          ),
                        ),
                      ),
                    ],
                  ] else if (node.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        node.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showVideoBadge)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            if (photoCount > 1)
              Positioned(
                top: 6,
                right: 6,
                child: BouncingPhotoCountBadge(
                  count: photoCount,
                  label: '$photoCount',
                  style: BouncingPhotoCountBadgeStyle.compact,
                ),
              ),
            if (_hasSatelliteRail)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _railWidth,
                child: _GraphSatelliteRail(
                  badgeText: satelliteBadge!,
                  expanded: satellitesExpanded,
                  localeCode: localeCode,
                  isDark: isDark,
                  hasThumb: hasThumb,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonNodeBody({required bool hasThumb, required Color accent}) {
    final titleColor = hasThumb ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subtitleColor = Colors.white.withValues(alpha: isDark ? 0.85 : 0.75);
    final avatarSize = node.size.height;
    final cornerRadius = node.isMemory ? 22.0 : 18.0;
    final titleStyle = TextStyle(
      fontSize: node.isPrimaryCard ? 11.5 : 11,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: titleColor,
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(cornerRadius),
            bottomLeft: Radius.circular(cornerRadius),
          ),
          child: PersonNodeAvatar(
            name: node.title,
            size: avatarSize,
            accent: accent,
            onDarkBackground: isDark || hasThumb,
            square: true,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                if (node.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    node.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphScaleHintBanner extends ConsumerWidget {
  const _GraphScaleHintBanner({required this.total, required this.onPickRange});

  final int total;
  final ValueChanged<GraphTimeRange> onPickRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.speed_rounded, size: 18, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t['graph_scale_banner']!.replaceAll('{total}', '$total'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => onPickRange(GraphTimeRange.days30),
              child: Text(t['graph_range_30d']!),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphLayoutCapBanner extends ConsumerWidget {
  const _GraphLayoutCapBanner({required this.cap});

  final int cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t['graph_scale_layout_cap']!.replaceAll('{cap}', '$cap'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 관계망 하단 신뢰 안내 — 네비게이션 바로 위, 그래프 제스처와 겹치지 않게 얇게 표시.
class _GraphTrustHintBar extends ConsumerWidget {
  const _GraphTrustHintBar({required this.graphAiOn});

  final bool graphAiOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = graphAiOn
        ? '${t['graph_trust_hint']!} ${t['graph_trust_hint_ai_extra']!}'
        : t['graph_trust_hint']!;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                graphAiOn ? Icons.auto_awesome_outlined : Icons.info_outline,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  maxLines: graphAiOn ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                        height: 1.35,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
