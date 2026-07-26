import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/graph_display_mode.dart';
import '../../core/graph_hub_config.dart';
import '../../core/graph_view_lens.dart';
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
import '../../utils/graph_viewport.dart';
import '../../utils/graph_context_lens.dart';
import '../../utils/graph_viewport_cull.dart';
import '../../utils/memory_content_edit.dart';
import '../../widgets/person_node_avatar.dart';
import '../../widgets/app_empty_state.dart';
import 'graph_chat_save.dart';
import 'graph_context_lens_bar.dart';
import 'graph_pro_value_banner.dart';
import 'graph_event_layout.dart';
import 'graph_interactive_canvas.dart';
import 'graph_help_sheet.dart';
import 'graph_trust_sheet.dart';
import 'graph_lens_mode_bar.dart';
import 'graph_list_view.dart';
import 'graph_person_layout.dart';
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
  /// 드래그 중 맵 복사 없이 tick만 올려 경량 페인터를 갱신합니다.
  final ValueNotifier<int> _dragTick = ValueNotifier(0);
  Timer? _longPressTimer;
  int? _activePointer;
  String? _dragNodeId;
  Set<String> _dragGroup = {};
  bool _moveCluster = false;
  Offset? _lastCanvasPosition;
  bool _moved = false;
  /// 팬/줌 중 컬링 재계산을 프레임마다 하지 않도록 고정합니다.
  Set<String>? _frozenVisibleIds;
  Map<String, GraphSatelliteExpandMode> _satelliteExpansions = {};
  final Set<String> _collapsedSatelliteMemoryIds = {};
  final Set<String> _collapsedClusterIds = {};
  String? _clusterCollapseFingerprint;
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
  bool _pendingLayoutInvalidation = false;
  Map<String, GraphSatelliteExpandMode>? _cachedMergedExpansions;
  String? _cachedExpansionFingerprint;
  String? _lastFitFingerprint;
  Timer? _cullRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    warmMemoryImagesDirectoryCache();
    warmMemoryVideosDirectoryCache();
    _transformController.addListener(_onTransformChanged);
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
        if (_pendingLayoutInvalidation) {
          _pendingLayoutInvalidation = false;
          setState(() {
            _layoutFingerprint = null;
            _cachedLayout = null;
            _cachedCanvasSize = null;
            _cachedDefaults = null;
            _cachedFocusResult = null;
            _cachedMemoryFocusResult = null;
          });
        }
      }
    });
    _achievementSub = ref.listenManual<List<Memory>>(memoryListProvider, (_, _) => _checkAchievements());
    _memoryLayoutSub = ref.listenManual<List<Memory>>(memoryListProvider, (prev, next) {
      final sig = graphMemoryLayoutSignature(next.where(isUserFacingMemory));
      if (_lastMemoryLayoutSignature == sig) return;
      _lastMemoryLayoutSignature = sig;
      if (!mounted) return;
      if (ref.read(mainNavigationTabProvider) != 2) {
        _pendingLayoutInvalidation = true;
        return;
      }
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
    _longPressTimer?.cancel();
    _cullRefreshTimer?.cancel();
    _transformController.removeListener(_onTransformChanged);
    _dragTick.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (_draggingNode) return;
    // 팬/줌 중에는 매 프레임 재빌드하지 않고, 멈춘 뒤에만 가시 노드를 갱신
    _cullRefreshTimer?.cancel();
    _cullRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _draggingNode) return;
      _frozenVisibleIds = null;
      setState(() {});
    });
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

  void _onContextLensChanged(WidgetRef ref, GraphContextLens lens, List<Memory> memories) {
    applyGraphContextLens(ref, lens);
    if (!mounted) return;
    setState(() {
      _layoutFingerprint = null;
      _cachedLayout = null;
      _cachedCanvasSize = null;
      _cachedDefaults = null;
    });
    _collapseAllSatellites(memories);
  }

  GraphViewLens _effectiveViewLens(GraphViewLens lens) {
    // AI 렌즈는 설정「관계망 AI」토글로 대체 — 저장된 ai는 기억 렌즈로 매핑.
    if (lens == GraphViewLens.timeline || lens == GraphViewLens.aiInsight) {
      return GraphViewLens.memory;
    }
    return lens;
  }

  void _onGraphViewLensChanged(WidgetRef ref, GraphViewLens lens, List<Memory> memories) {
    final effective = _effectiveViewLens(lens);
    ref.read(graphViewLensProvider.notifier).state = effective;
    writeGraphViewLens(ref.read(preferencesProvider), effective);
    setState(() {
      _layoutFingerprint = null;
      _cachedLayout = null;
      _lastFitFingerprint = null;
    });
    _collapseAllSatellites(memories);
  }

  void _onGraphTimeRangeChanged(WidgetRef ref, GraphTimeRange range, List<Memory> memories) {
    ref.read(graphTimeRangeProvider.notifier).state = range;
    writeGraphTimeRange(ref.read(preferencesProvider), range);
    _collapseAllSatellites(memories);
  }

  void _setGraphDisplayMode(GraphDisplayMode mode) {
    ref.read(graphDisplayModeProvider.notifier).state = mode;
    writeGraphDisplayMode(ref.read(preferencesProvider), mode);
  }

  bool _isClusterHubNode(GraphNodeData node) {
    if (node.id == 'person_hub_self') return true;
    if (node.id.startsWith('person_overview_')) return true;
    if (node.kind == GraphNodeKind.eventHub && (node.hubDepth == null || node.hubDepth == 0)) return true;
    if (node.kind == GraphNodeKind.memory) return true;
    return false;
  }

  void _seedClusterCollapseIfNeeded(GraphLayout layout, String fingerprint) {
    if (_clusterCollapseFingerprint == fingerprint) return;
    _clusterCollapseFingerprint = fingerprint;
    _collapsedClusterIds.clear();
    if (layout.nodes.length < GraphScaleConfig.autoCollapseClusterNodeThreshold) return;
    for (final node in layout.nodes) {
      if (node.layoutClusterId.isNotEmpty) _collapsedClusterIds.add(node.layoutClusterId);
    }
  }

  GraphLayout _applyCollapsedClusters(GraphLayout layout) {
    if (_collapsedClusterIds.isEmpty) return layout;
    final nodes = layout.nodes.where((n) {
      if (!_collapsedClusterIds.contains(n.layoutClusterId)) return true;
      return _isClusterHubNode(n);
    }).toList();
    final ids = nodes.map((n) => n.id).toSet();
    final edges = layout.edges.where((e) => ids.contains(e.fromId) && ids.contains(e.toId)).toList();
    return GraphLayout(nodes: nodes, edges: edges);
  }

  Widget _buildGraphLensModeBar({
    required Map<String, String> t,
    required GraphViewLens viewLens,
    required GraphTimeRange timeRange,
    required int totalMemoryCount,
    required int visibleCount,
    required List<Memory> collapseMemories,
    List<GraphInsight> insights = const [],
    GraphDisplayMode? displayMode,
  }) {
    return GraphLensModeBar(
      lens: viewLens,
      timeRange: timeRange,
      personLabel: t['graph_lens_person']!,
      memoryLabel: t['graph_lens_memory']!,
      viewTitle: t['graph_view_title']!,
      range7dLabel: t['graph_range_7d']!,
      range30dLabel: t['graph_range_30d']!,
      range90dLabel: t['graph_range_90d']!,
      rangeAllLabel: t['graph_range_all']!,
      helpTooltip: t['graph_help_title']!,
      onHelpPressed: () => showGraphHelpSheet(
        context,
        t: t,
        timeRange: timeRange,
        totalCount: totalMemoryCount,
        visibleCount: visibleCount,
        insights: insights,
      ),
      onLensChanged: (lens) => _onGraphViewLensChanged(ref, lens, collapseMemories),
      onTimeRangeChanged: (range) => _onGraphTimeRangeChanged(ref, range, collapseMemories),
      displayMode: displayMode,
      onDisplayModeChanged: displayMode == null
          ? null
          : (mode) => setState(() => _setGraphDisplayMode(mode)),
      graphModeTooltip: t['graph_view_mode_graph'],
      listModeTooltip: t['graph_view_mode_list'],
    );
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
    _dragTick.value++;
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
    // 맵 복사·전체 위젯 재빌드 없이 tick만 통지
    _dragTick.value++;
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

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _armLongPressClusterDrag(List<GraphNodeData> nodes) {
    _cancelLongPressTimer();
    final nodeId = _dragNodeId;
    if (nodeId == null) return;
    GraphNodeData? node;
    for (final n in nodes) {
      if (n.id == nodeId) {
        node = n;
        break;
      }
    }
    if (node == null || !isGraphHubLikeNode(node)) return;

    _longPressTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted || _dragNodeId != nodeId || _moved) return;
      _moveCluster = true;
      HapticFeedback.mediumImpact();
      // 그룹 하이라이트만 경량 tick으로 반영 (전체 setState 회피)
      _dragTick.value++;
    });
  }

  void _resetPointerState() {
    _cancelLongPressTimer();
    _activePointer = null;
    _dragNodeId = null;
    _dragGroup = {};
    _moveCluster = false;
    _lastCanvasPosition = null;
    _moved = false;
    _draggingNode = false;
    _livePositions = null;
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
    _moveCluster = false;
    final nodeId = _nodeAt(_lastCanvasPosition!, nodes, positions);
    if (nodeId == null) return;

    _dragNodeId = nodeId;
    _dragGroup = dragGroupForNode(nodeId, edges, nodes);
    _beginDrag(positions);
    _armLongPressClusterDrag(nodes);
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
    if (!_moved && delta.distance > 2.5) {
      _moved = true;
      // 롱프레스 전에 움직이면 단일 노드 드래그
      if (!_moveCluster) _cancelLongPressTimer();
    }
    if (!_moved) return;
    _applyDragDelta(primaryNodeId: _dragNodeId!, delta: delta);
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
      if (tappedNode != null) {
        final cid = tappedNode.layoutClusterId;
        if (_collapsedClusterIds.contains(cid) && _isClusterHubNode(tappedNode)) {
          GraphSatelliteExpandMode? railMode;
          if (nodeId.startsWith('memory_')) {
            final badge = tappedNode.satelliteBadge;
            final center = positions[nodeId];
            final canvasPos = _lastCanvasPosition;
            if (badge != null &&
                badge.isNotEmpty &&
                center != null &&
                canvasPos != null) {
              railMode = satelliteModeFromRailTap(
                canvasPos: canvasPos,
                nodeCenter: center,
                nodeSize: tappedNode.size,
                badgeText: badge,
                localeCode: localeCode,
              );
            }
          }
          setState(() {
            _collapsedClusterIds.remove(cid);
            _layoutFingerprint = null;
            _cachedLayout = null;
          });
          // 접힌 클러스터에서 왼쪽 레일을 누르면 묶음 해제 + 위성도 함께 펼침.
          if (railMode != null && nodeId.startsWith('memory_')) {
            _toggleSatelliteExpansion(
              nodeId.replaceFirst('memory_', ''),
              railMode,
              memories: memories,
              fragments: fragments,
              localeCode: localeCode,
            );
          }
          _finishDrag(ref);
          _resetPointerState();
          return;
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
            kind == GraphNodeKind.pet ||
            kind == GraphNodeKind.place ||
            kind == GraphNodeKind.activity ||
            kind == GraphNodeKind.event ||
            kind == GraphNodeKind.eventHub ||
            kind == GraphNodeKind.organization) {
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
    setState(_resetPointerState    );
  }

  Widget _buildIdleGraphLayer({
    required Size effectiveCanvas,
    required List<GraphNodeData> sortedNodes,
    required Map<String, Offset> anchoredBase,
    required Map<String, GraphNodeData> nodeMap,
    required bool isDark,
    required bool cullNodes,
    required Size viewportSize,
    required GraphLayout layout,
    required Map<String, Memory> memoryById,
    required Map<String, GraphNodeMediaInfo> nodeMediaIndex,
    required bool isFocusMode,
    required bool isMemoryFocusMode,
    required List<String> highlightedEntities,
    required String graphSearchQuery,
    required String? selectedNodeId,
    required Map<String, GraphSatelliteExpandMode> mergedExpansions,
    required String localeCode,
  }) {
    // 팬/줌은 InteractiveViewer가 처리. 컬링은 프레임마다 하지 않고 고정 집합만 사용.
    if (cullNodes && _frozenVisibleIds == null) {
      _frozenVisibleIds = visibleGraphNodeIds(
        nodes: sortedNodes,
        positions: anchoredBase,
        transform: _transformController.value,
        viewportSize: viewportSize,
      );
    }
    if (!cullNodes) _frozenVisibleIds = null;

    return _buildGraphStack(
      effectiveCanvas: effectiveCanvas,
      sortedNodes: sortedNodes,
      positions: anchoredBase,
      nodeMap: nodeMap,
      isDark: isDark,
      visibleIds: _frozenVisibleIds,
      cullNodes: cullNodes,
      layout: layout,
      memoryById: memoryById,
      nodeMediaIndex: nodeMediaIndex,
      isFocusMode: isFocusMode,
      isMemoryFocusMode: isMemoryFocusMode,
      highlightedEntities: highlightedEntities,
      graphSearchQuery: graphSearchQuery,
      selectedNodeId: selectedNodeId,
      mergedExpansions: mergedExpansions,
      localeCode: localeCode,
      declutter: sortedNodes.length > 28,
      hideLabels: false,
    );
  }

  Widget _buildGraphStack({
    required Size effectiveCanvas,
    required List<GraphNodeData> sortedNodes,
    required Map<String, Offset> positions,
    required Map<String, GraphNodeData> nodeMap,
    required bool isDark,
    required Set<String>? visibleIds,
    required bool cullNodes,
    required GraphLayout layout,
    required Map<String, Memory> memoryById,
    required Map<String, GraphNodeMediaInfo> nodeMediaIndex,
    required bool isFocusMode,
    required bool isMemoryFocusMode,
    required List<String> highlightedEntities,
    required String graphSearchQuery,
    required String? selectedNodeId,
    required Map<String, GraphSatelliteExpandMode> mergedExpansions,
    required String localeCode,
    required bool declutter,
    required bool hideLabels,
  }) {
    final nodesToRender = cullNodes && visibleIds != null
        ? sortedNodes.where((n) => visibleIds.contains(n.id))
        : sortedNodes;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: effectiveCanvas,
          painter: GraphEdgesPainter(
            edges: layout.edges,
            positions: positions,
            nodeMap: nodeMap,
            isDark: isDark,
            visibleNodeIds: visibleIds,
            declutter: declutter,
            hideLabels: hideLabels,
          ),
        ),
        ...nodesToRender.map((node) {
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
          final isDragging = _draggingNode && (_moveCluster ? _dragGroup.contains(node.id) : node.id == _dragNodeId);

          final media = nodeMediaIndex[node.id] ?? GraphNodeMediaInfo.empty;
          final thumbPath = media.thumbnailPath;
          final photoCount = media.photoCount;
          final showVideoBadge = media.hasVideo;

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
    );
  }

  void _handleGraphNodeTap({
    required WidgetRef ref,
    required String nodeId,
    required Offset canvasPos,
    required List<Memory> memories,
    required Map<String, List<String>> imagePaths,
    required Map<String, List<String>> videoPaths,
    required List<GraphNodeData> nodes,
    required List<GraphEdgeData> edges,
    required Map<String, Offset> positions,
  }) {
    ref.read(selectedGraphNodeProvider.notifier).state = nodeId;
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
    final fragments =
        graphAiOn ? ref.read(memoryGraphFragmentsProvider) : const <String, GraphMemoryFragment>{};
    GraphNodeData? tappedNode;
    for (final n in nodes) {
      if (n.id == nodeId) {
        tappedNode = n;
        break;
      }
    }
    if (tappedNode == null || !mounted) return;

    final cid = tappedNode.layoutClusterId;
    if (_collapsedClusterIds.contains(cid) && _isClusterHubNode(tappedNode)) {
      GraphSatelliteExpandMode? railMode;
      if (nodeId.startsWith('memory_')) {
        final badge = tappedNode.satelliteBadge;
        final center = positions[nodeId];
        if (badge != null && badge.isNotEmpty && center != null) {
          railMode = satelliteModeFromRailTap(
            canvasPos: canvasPos,
            nodeCenter: center,
            nodeSize: tappedNode.size,
            badgeText: badge,
            localeCode: localeCode,
          );
        }
      }
      setState(() {
        _collapsedClusterIds.remove(cid);
        _layoutFingerprint = null;
        _cachedLayout = null;
      });
      if (railMode != null && nodeId.startsWith('memory_')) {
        _toggleSatelliteExpansion(
          nodeId.replaceFirst('memory_', ''),
          railMode,
          memories: memories,
          fragments: fragments,
          localeCode: localeCode,
        );
      }
      return;
    }

    if (nodeId.startsWith('memory_')) {
      final memoryId = nodeId.replaceFirst('memory_', '');
      final badge = tappedNode.satelliteBadge;
      final center = positions[nodeId];
      if (badge != null && badge.isNotEmpty && center != null) {
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
          return;
        }
      }
      showGraphNodeAiSheet(
        context,
        ref,
        node: tappedNode,
        edges: edges,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        onSaved: _graphChatSavedHandler,
      );
      return;
    }

    if (nodeId.startsWith('group_') ||
        nodeId.startsWith('focus_hub_') ||
        nodeId.startsWith('event_hub_')) {
      showGraphNodeAiSheet(
        context,
        ref,
        node: tappedNode,
        edges: edges,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        onSaved: _graphChatSavedHandler,
      );
      return;
    }

    final kind = tappedNode.kind;
    if (kind == GraphNodeKind.person ||
        kind == GraphNodeKind.pet ||
        kind == GraphNodeKind.place ||
        kind == GraphNodeKind.activity ||
        kind == GraphNodeKind.event ||
        kind == GraphNodeKind.eventHub ||
        kind == GraphNodeKind.organization) {
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
      return AppEmptyState(
        icon: Icons.hub_outlined,
        title: t['no_graph']!,
        subtitle: t['empty_hint'],
      );
    }

    final graphTabActive = ref.watch(mainNavigationTabProvider) == 2;
    if (!graphTabActive) {
      return const SizedBox.shrink();
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
    final graphSearchQuery = ref.watch(graphEntitySearchProvider).trim().toLowerCase();
    final landscapeImmersive =
        graphTabActive && MediaQuery.orientationOf(context) == Orientation.landscape;
    final timeRange = ref.watch(graphTimeRangeProvider);
    final contextLens = ref.watch(graphContextLensProvider);
    final viewLens = ref.watch(graphViewLensProvider);
    final effectiveViewLens = _effectiveViewLens(viewLens);
    final localeCode = ref.watch(languageProvider).languageCode;
    final totalMemoryCount = memories.length;
    final rangeMemories = isFocusMode
        ? memories
        : filterMemoriesForGraphRange(memories, timeRange);
    final visibleMemories = (!isFocusMode && contextLens != GraphContextLens.all)
        ? filterMemoriesForGraphLens(rangeMemories, contextLens, localeCode)
        : rangeMemories;
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

    if (!isFocusMode && rangeMemories.isEmpty) {
      return Column(
        children: [
          GraphContextLensBar(
            lens: contextLens,
            visibleCount: 0,
            rangeCount: 0,
            onLensChanged: (lens) => _onContextLensChanged(ref, lens, memories),
          ),
          _buildGraphLensModeBar(
            t: t,
            viewLens: viewLens,
            timeRange: timeRange,
            totalMemoryCount: totalMemoryCount,
            visibleCount: 0,
            collapseMemories: memories,
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.date_range_outlined,
              title: t['graph_range_empty']!,
            ),
          ),
          if (!landscapeImmersive) _GraphTrustHintBar(graphAiOn: false),
        ],
      );
    }

    if (!isFocusMode && visibleMemories.isEmpty) {
      return Column(
        children: [
          GraphContextLensBar(
            lens: contextLens,
            visibleCount: 0,
            rangeCount: rangeMemories.length,
            onLensChanged: (lens) => _onContextLensChanged(ref, lens, memories),
          ),
          if (!landscapeImmersive && effectiveViewLens != GraphViewLens.person)
            _GraphHubModeBar(
              mode: ref.watch(graphHubViewModeProvider),
              memoryHubLabel: t['graph_hub_memory']!,
              eventHubLabel: t['graph_hub_event']!,
              onModeChanged: (mode) {
                ref.read(graphHubViewModeProvider.notifier).state = mode;
                writeGraphHubViewMode(ref.read(preferencesProvider), mode);
              },
            ),
          _buildGraphLensModeBar(
            t: t,
            viewLens: viewLens,
            timeRange: timeRange,
            totalMemoryCount: totalMemoryCount,
            visibleCount: 0,
            collapseMemories: memories,
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.filter_alt_outlined,
                    title: t['graph_lens_empty']!,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: FilledButton.tonal(
                    onPressed: () => _onContextLensChanged(ref, GraphContextLens.all, memories),
                    child: Text(t['graph_lens_show_all']!),
                  ),
                ),
              ],
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
    final hubViewMode = ref.watch(graphHubViewModeProvider);
    final Map<String, GraphMemoryFragment> fragments =
        graphAiOn ? ref.watch(memoryGraphFragmentsProvider) : const {};
    final placeCache = ref.watch(memoryPlaceNamesProvider);
    final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);

    late GraphLayout layout;
    late final Size canvasSize;
    late final Map<String, Offset> defaults;
    KeywordFocusGraphResult? focusResult;
    MemoryFocusGraphResult? memoryFocusResult;
    final keyword = focusKeyword?.trim() ?? '';
    final memoryKey = graphMemoryLayoutSignature(layoutMemories);
    final collapseKey = _collapsedSatelliteMemoryIds.join(',');
    final expansionFingerprint =
        '$memoryKey:$collapseKey:$localeCode:${_satelliteExpansions.entries.map((e) => '${e.key}:${e.value.name}').join('|')}';
    late final Map<String, GraphSatelliteExpandMode> mergedExpansions;
    if (isFocusMode) {
      mergedExpansions = const <String, GraphSatelliteExpandMode>{};
    } else if (_cachedExpansionFingerprint == expansionFingerprint &&
        _cachedMergedExpansions != null) {
      mergedExpansions = _cachedMergedExpansions!;
    } else {
      mergedExpansions = mergeDefaultSatelliteExpansions(
        memories: layoutMemories,
        userExpansions: _satelliteExpansions,
        collapsedMemoryIds: _collapsedSatelliteMemoryIds,
        graphFragments: fragments,
        localeCode: localeCode,
      );
      _cachedExpansionFingerprint = expansionFingerprint;
      _cachedMergedExpansions = mergedExpansions;
    }
    final expansionKey = mergedExpansions.entries.map((e) => '${e.key}:${e.value.name}').join('|');
    final fragmentKey = fragments.entries.map((e) => '${e.key}:${e.value.meaningTitle}').join('|');
    final fingerprint = isMemoryFocusMode
        ? 'memfocus:${focusMemoryId!.trim()}:$memoryKey:$localeCode:$fragmentKey'
        : isKeywordFocusMode
            ? 'focus:$keyword:$memoryKey:$localeCode'
            : 'full:$memoryKey:$expansionKey:$collapseKey:$localeCode:$graphAiOn:${hubViewMode.name}:${effectiveViewLens.name}:$fragmentKey';

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
      if (memoriesHaveOrganizationHierarchy([focusMemory], localeCode: localeCode)) {
        layout = buildEventGraphLayout(
          [focusMemory],
          placeCache: placeCache,
          fullAddressCache: fullAddressCache,
          graphFragments: fragments,
          localeCode: localeCode,
        );
        final eventCount = layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub).length;
        final hierarchyCount = layout.nodes.where((n) => n.hubDepth != null).length;
        canvasSize = eventGraphCanvasSize(eventCount, hierarchyNodeCount: hierarchyCount);
        defaults = initialEventGraphPositions(layout.nodes, layout.edges, canvasSize);
        memoryFocusResult = null;
      } else {
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
      }
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
      canvasSize = keywordFocusCanvasSize(layout.nodes.length);
      defaults = initialKeywordFocusPositions(layout.nodes, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = focusResult;
      _cachedMemoryFocusResult = null;
    } else if (effectiveViewLens == GraphViewLens.person) {
      final personResult = buildPersonOverviewGraphLayout(layoutMemories, localeCode: localeCode);
      layout = personResult.layout;
      canvasSize = personOverviewCanvasSize(layout.nodes.length);
      defaults = initialPersonOverviewPositions(layout.nodes, canvasSize);
      _layoutFingerprint = fingerprint;
      _cachedLayout = layout;
      _cachedCanvasSize = canvasSize;
      _cachedDefaults = defaults;
      _cachedFocusResult = null;
      _cachedMemoryFocusResult = null;
    } else if (hubViewMode == GraphHubViewMode.eventHub ||
        memoriesHaveOrganizationHierarchy(layoutMemories, localeCode: localeCode)) {
      // 기업 조직 계층은 이벤트 레이아웃의 depth tree에서만 완전 렌더된다.
      // 기본(기억 허브)에서도 조직도가 보이도록 자동으로 이벤트 레이아웃을 쓴다.
      layout = buildEventGraphLayout(
        layoutMemories,
        placeCache: placeCache,
        fullAddressCache: fullAddressCache,
        graphFragments: fragments,
        localeCode: localeCode,
      );
      final eventCount = layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub).length;
      final hierarchyCount = layout.nodes.where((n) => n.hubDepth != null).length;
      canvasSize = eventGraphCanvasSize(eventCount, hierarchyNodeCount: hierarchyCount);
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
              AppEmptyState(
                icon: Icons.center_focus_weak_rounded,
                title: t['graph_focus_empty']!,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => clearGraphFocus(ref),
                child: Text(t['graph_focus_show_all']!),
              ),
            ],
          ),
        ),
      );
    }

    if (!isFocusMode) {
      _seedClusterCollapseIfNeeded(layout, fingerprint);
      layout = _applyCollapsedClusters(layout);
    }

    final displayMode = ref.watch(graphDisplayModeProvider);
    final nodeMap = {for (final node in layout.nodes) node.id: node};
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final Map<String, Offset> basePositions;
    if (isFocusMode) {
      basePositions = mergeStoredGraphPositions(
        nodes: layout.nodes,
        edges: layout.edges,
        defaults: defaults,
        stored: _focusDragPositions,
        fallback: center,
      );
    } else {
      basePositions = mergeStoredGraphPositions(
        nodes: layout.nodes,
        edges: layout.edges,
        defaults: defaults,
        stored: storedPositions,
        fallback: center,
      );
    }

    int paintOrder(GraphNodeData node) {
      if (node.isMemory) return 0;
      if (node.kind == GraphNodeKind.eventHub) return 2;
      if (node.id.startsWith('group_')) return 3;
      if (node.id.startsWith('entity_note_')) return 2;
      return 1;
    }

    final sortedNodes = [...layout.nodes]..sort((a, b) => paintOrder(a).compareTo(paintOrder(b)));

    var effectiveCanvas = canvasSize;
    final contentBounds = graphContentBounds(sortedNodes, basePositions);
    effectiveCanvas = expandCanvasForContent(effectiveCanvas, contentBounds);
    final anchoredBase = shiftPositionsIntoCanvas(basePositions, contentBounds, effectiveCanvas);

    final memoryById = {for (final m in visibleMemories) m.id: m};
    final nodeMediaIndex = buildGraphNodeMediaIndex(
      nodes: layout.nodes,
      memories: visibleMemories,
      imagePaths: imagePaths,
      videoPaths: videoPaths,
      edges: layout.edges,
      localeCode: localeCode,
    );
    final insights = generateGraphInsights(
      memories: layoutMemories,
      fragments: fragments,
      localeCode: localeCode,
    );

    final graphCanvas = Stack(
      clipBehavior: Clip.none,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_lastFitFingerprint != fingerprint) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                fitGraphToViewport(
                  controller: _transformController,
                  contentBounds: graphContentBounds(sortedNodes, anchoredBase),
                  viewportSize: viewportSize,
                );
                _lastFitFingerprint = fingerprint;
              });
            }
            return GraphInteractiveCanvas(
              canvasSize: effectiveCanvas,
              nodes: sortedNodes,
              edges: layout.edges,
              basePositions: anchoredBase,
              nodeMap: nodeMap,
              isDark: isDark,
              transformationController: _transformController,
              memoryById: memoryById,
              nodeMediaIndex: nodeMediaIndex,
              isFocusMode: isFocusMode,
              isMemoryFocusMode: isMemoryFocusMode,
              highlightedEntities: highlightedEntities,
              graphSearchQuery: graphSearchQuery,
              selectedNodeId: selectedNodeId,
              mergedExpansions: mergedExpansions,
              localeCode: localeCode,
              onDragEnd: (positions) {
                final focusMemoryId = ref.read(graphFocusMemoryIdProvider)?.trim();
                final focusKeyword = ref.read(graphFocusKeywordProvider)?.trim();
                if ((focusMemoryId != null && focusMemoryId.isNotEmpty) ||
                    (focusKeyword != null && focusKeyword.isNotEmpty)) {
                  setState(() {
                    _focusDragPositions = {..._focusDragPositions, ...positions};
                  });
                } else {
                  ref.read(graphNodePositionsProvider.notifier).state = {
                    ...ref.read(graphNodePositionsProvider),
                    ...positions,
                  };
                  saveGraphPositions(
                    ref.read(preferencesProvider),
                    ref.read(graphNodePositionsProvider),
                  );
                }
              },
              onTapNode: (nodeId, canvasPos) {
                _handleGraphNodeTap(
                  ref: ref,
                  nodeId: nodeId,
                  canvasPos: canvasPos,
                  memories: visibleMemories,
                  imagePaths: imagePaths,
                  videoPaths: videoPaths,
                  nodes: layout.nodes,
                  edges: layout.edges,
                  positions: anchoredBase,
                );
              },
              buildNodeCard: ({
                required node,
                required isHighlighted,
                required isSelected,
                required isDragging,
                required thumbnailPath,
                required photoCount,
                required showVideoBadge,
                required satellitesExpanded,
              }) {
                return Semantics(
                  label: node.title,
                  hint: node.satelliteBadge,
                  button: true,
                  child: _GraphNodeCard(
                    node: node,
                    isHighlighted: isHighlighted,
                    isSelected: isSelected,
                    isDragging: isDragging,
                    isDark: isDark,
                    thumbnailPath: thumbnailPath,
                    photoCount: photoCount,
                    showVideoBadge: showVideoBadge,
                    satelliteBadge: node.satelliteBadge,
                    satellitesExpanded: satellitesExpanded,
                    localeCode: localeCode,
                  ),
                );
              },
            );
          },
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
          const GraphProValueBanner(),
        if (!landscapeImmersive && !isFocusMode)
          GraphContextLensBar(
            lens: contextLens,
            visibleCount: layoutMemories.length,
            rangeCount: rangeMemories.length,
            onLensChanged: (lens) => _onContextLensChanged(ref, lens, memories),
          ),
        if (!landscapeImmersive && !isFocusMode)
          _buildGraphLensModeBar(
            t: t,
            viewLens: viewLens,
            timeRange: timeRange,
            totalMemoryCount: totalMemoryCount,
            visibleCount: layoutMemories.length,
            collapseMemories: layoutMemories,
            insights: insights,
            displayMode: displayMode,
          ),
        if (!landscapeImmersive &&
            !isFocusMode &&
            effectiveViewLens == GraphViewLens.memory &&
            ref.watch(graphAiEnabledProvider))
          GraphAiHubToolbar(
            insights: insights.map((i) => i.message).toList(),
            emptyHint: t['graph_ai_insight_empty']!,
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
          )
        else if (!landscapeImmersive && !isFocusMode && effectiveViewLens == GraphViewLens.memory)
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
            onOpenList: () => setState(() => _setGraphDisplayMode(GraphDisplayMode.list)),
          ),
        if (!landscapeImmersive && !isFocusMode && layoutCapApplied)
          _GraphLayoutCapBanner(
            cap: GraphScaleConfig.maxLayoutMemories,
            onOpenList: () => setState(() => _setGraphDisplayMode(GraphDisplayMode.list)),
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
          child: displayMode == GraphDisplayMode.list && !isFocusMode
              ? GraphListView(
                  memories: layoutMemories,
                  localeCode: localeCode,
                  peopleLabel: t['graph_list_people']!,
                  placesLabel: t['graph_list_places']!,
                  memoriesLabel: t['graph_list_memories']!,
                  emptyLabel: t['graph_list_empty']!,
                )
              : landscapeImmersive
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
    final hasThumb = thumbnailPath != null;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(node.isMemory ? 22 : 18),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: isHighlighted || isDragging
          ? [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );

    return IgnorePointer(
      child: isDragging
          ? Container(
              width: node.size.width,
              height: node.size.height,
              clipBehavior: Clip.antiAlias,
              decoration: decoration,
              child: _buildNodeBody(context, hasThumb: hasThumb, accent: accent),
            )
          : Container(
        width: node.size.width,
        height: node.size.height,
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: _buildNodeBody(context, hasThumb: hasThumb, accent: accent),
      ),
    );
  }

  Widget _buildNodeBody(BuildContext context, {required bool hasThumb, required Color accent}) {
    return Stack(
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
                      useHero: false,
                      cacheWidth: 320,
                      filterQuality: FilterQuality.low,
                    )
                  : Image.file(
                      File(thumbnailPath!),
                      width: node.size.width,
                      height: node.size.height,
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                      filterQuality: FilterQuality.low,
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
                  animated: false,
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
  const _GraphScaleHintBanner({
    required this.total,
    required this.onPickRange,
    required this.onOpenList,
  });

  final int total;
  final ValueChanged<GraphTimeRange> onPickRange;
  final VoidCallback onOpenList;

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
            TextButton(
              onPressed: onOpenList,
              child: Text(t['graph_list_cta']!),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphLayoutCapBanner extends ConsumerWidget {
  const _GraphLayoutCapBanner({required this.cap, required this.onOpenList});

  final int cap;
  final VoidCallback onOpenList;

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
            TextButton(
              onPressed: onOpenList,
              child: Text(t['graph_list_cta']!),
            ),
          ],
        ),
      ),
    );
  }
}

/// 관계망 하단 신뢰 배너 — 짧은 한 줄 + 안내 시트, 닫으면 다시 표시하지 않음.
class _GraphTrustHintBar extends ConsumerStatefulWidget {
  const _GraphTrustHintBar({required this.graphAiOn});

  final bool graphAiOn;

  @override
  ConsumerState<_GraphTrustHintBar> createState() => _GraphTrustHintBarState();
}

class _GraphTrustHintBarState extends ConsumerState<_GraphTrustHintBar> {
  bool _sessionDismissed = false;

  Future<void> _dismiss() async {
    setState(() => _sessionDismissed = true);
    await writeGraphTrustHintDismissed(ref.read(preferencesProvider), true);
  }

  @override
  Widget build(BuildContext context) {
    final prefsDismissed = readGraphTrustHintDismissed(ref.watch(preferencesProvider));
    if (prefsDismissed || _sessionDismissed) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.95),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              if (widget.graphAiOn) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t['graph_trust_ai_badge']!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  t['graph_trust_short']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => showGraphTrustSheet(
                  context,
                  t: t,
                  graphAiOn: widget.graphAiOn,
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  t['graph_trust_learn']!,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.primary),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: t['close']!,
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
