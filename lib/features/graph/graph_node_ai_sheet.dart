import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_maturity.dart';
import '../../core/crash_reporting.dart';
import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/subscription_providers.dart';
import '../../services/ai_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/graph_ai_orchestrator.dart';
import '../../services/local_memory_store.dart';
import '../../services/subscription_exceptions.dart';
import '../../utils/ocr_utils.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/memory_video_paths.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';
import 'graph_node_context.dart';
import 'graph_node_insight.dart';
import 'graph_node_insight_panel.dart';
import 'graph_node_local_insights.dart';

class _AiChatLine {
  const _AiChatLine.user(this.text) : isUser = true;
  const _AiChatLine.assistant(this.text) : isUser = false;

  final bool isUser;
  final String text;
}

/// 관계망 노드 탭 → AI와 기억 대화 이어가기.
typedef GraphChatSavedCallback = void Function(String memoryId);

void showGraphNodeAiSheet(
  BuildContext context,
  WidgetRef ref, {
  required GraphNodeData node,
  required List<GraphEdgeData> edges,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
  GraphChatSavedCallback? onSaved,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(bottom: kMainNavBarSheetInset),
      child: _GraphNodeAiSheet(
        node: node,
        edges: edges,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        onSaved: onSaved,
      ),
    ),
  );
}

class _GraphNodeAiSheet extends ConsumerStatefulWidget {
  const _GraphNodeAiSheet({
    required this.node,
    required this.edges,
    required this.imagePaths,
    required this.videoPaths,
    this.onSaved,
  });

  final GraphNodeData node;
  final List<GraphEdgeData> edges;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> videoPaths;
  final GraphChatSavedCallback? onSaved;

  @override
  ConsumerState<_GraphNodeAiSheet> createState() => _GraphNodeAiSheetState();
}

class _GraphNodeAiSheetState extends ConsumerState<_GraphNodeAiSheet> with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiChatLine> _lines = [];
  bool _loading = false;
  bool _saving = false;
  bool _showTopExtras = true;
  bool _advancedAiEnabled = false;
  Memory? _savedMemory;
  GraphChatSaveResult? _saveResult;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    final localeCode = ref.read(languageProvider).languageCode;
    final fragments = ref.read(memoryGraphFragmentsProvider);
    final memories = _connectedMemories();
    if (memories.isEmpty) {
      _lines.add(_AiChatLine.assistant(graphNodeLocalInsightLine(
        node: widget.node,
        memories: memories,
        fragments: fragments,
        localeCode: localeCode,
      )));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(graphAiEnabledProvider) && _canUseAi()) {
        setState(() => _advancedAiEnabled = true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Memory> _connectedMemories() {
    return resolveGraphChatContextMemories(
      node: widget.node,
      allMemories: ref.read(memoryListProvider),
      edges: widget.edges,
    );
  }

  bool _canUseAi() {
    if (isLocalOnlyMode(
      ref.read(preferencesProvider),
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    )) {
      return false;
    }
    if (!requiresProCloudForCloudFeatures) return true;
    return canUseCloudFeatures(
      ref.read(preferencesProvider),
      subscription: ref.read(subscriptionStatusProvider),
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    );
  }

  void _enableAdvancedAi() {
    if (_advancedAiEnabled) return;
    final t = ref.read(translationsProvider);
    final memories = _connectedMemories();
    setState(() {
      _advancedAiEnabled = true;
      _lines.add(_AiChatLine.assistant(
        '${t['graph_node_ai_advanced_hint']!}\n${graphNodeAiHook(node: widget.node, t: t, memories: memories)}',
      ));
    });
    _scrollToEnd();
  }

  void _submitInput() {
    final trimmed = _inputController.text.trim();
    if (trimmed.isEmpty || _loading) return;
    if (_advancedAiEnabled) {
      _sendMessage(trimmed);
      return;
    }
    setState(() {
      _lines.add(_AiChatLine.user(trimmed));
      _inputController.clear();
      _showTopExtras = false;
    });
    _scrollToEnd();
  }

  bool _isEntityMediaNode() {
    final id = widget.node.id;
    if (id.startsWith('memory_') ||
        id.startsWith('group_') ||
        id.startsWith('event_hub_') ||
        id.startsWith('focus_hub_')) {
      return true;
    }
    return widget.node.kind == GraphNodeKind.person ||
        widget.node.kind == GraphNodeKind.pet ||
        widget.node.kind == GraphNodeKind.place ||
        widget.node.kind == GraphNodeKind.activity ||
        widget.node.kind == GraphNodeKind.event ||
        widget.node.kind == GraphNodeKind.organization ||
        widget.node.kind == GraphNodeKind.group ||
        widget.node.kind == GraphNodeKind.eventHub ||
        widget.node.kind == GraphNodeKind.memory;
  }

  void _openEntityMedia() {
    Navigator.of(context).pop();
    if (widget.node.id.startsWith('memory_')) {
      final memoryId = widget.node.id.replaceFirst('memory_', '');
      final memories = ref.read(memoryListProvider);
      Memory? memory;
      for (final m in memories) {
        if (m.id == memoryId) {
          memory = m;
          break;
        }
      }
      if (memory == null || !context.mounted) return;
      showMemoryDetailSheet(
        context,
        memory,
        imagePaths: widget.imagePaths,
        options: MemoryDetailPresets.graphFromNodeAi(
          node: widget.node,
          hasVideo: memoryHasVideo(memory.id, widget.videoPaths),
        ),
      );
      return;
    }
    showGraphEntityMediaSheet(
      context,
      ref,
      node: widget.node,
      imagePaths: widget.imagePaths,
    );
  }

  void _playEntityHighlight() {
    HapticFeedback.mediumImpact();
    launchEntityHighlight(
      context: context,
      ref: ref,
      entityLabel: widget.node.title.trim(),
      node: widget.node,
      edges: widget.edges,
    );
  }

  bool _hasHighlightMedia() {
    return countEntityHighlightSlides(
      entityLabel: widget.node.title.trim(),
      allMemories: ref.read(memoryListProvider),
      imagePaths: widget.imagePaths,
      videoPaths: widget.videoPaths,
      node: widget.node,
      edges: widget.edges,
    ) > 0;
  }

  Future<void> _sendMessage(String text, {bool fromSuggestion = false}) async {
    if (!_advancedAiEnabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _lines.add(_AiChatLine.user(trimmed));
      if (!fromSuggestion) _inputController.clear();
      _showTopExtras = false;
    });
    _scrollToEnd();

    final t = ref.read(translationsProvider);
    if (!_canUseAi()) {
      setState(() {
        _lines.add(_AiChatLine.assistant(t['graph_node_ai_locked']!));
        _loading = false;
      });
      _scrollToEnd();
      return;
    }

    try {
      final memories = _connectedMemories();
      final fragments = ref.read(memoryGraphFragmentsProvider);
      final locale = ref.read(languageProvider);
      final recent = _lines
          .map((e) => {'role': e.isUser ? 'user' : 'assistant', 'content': e.text})
          .toList();
      final reply = await AiService.instance.chatText(
        systemPrompt: buildGraphNodeAiSystemPrompt(
          node: widget.node,
          memories: memories,
          fragments: fragments,
          languageName: languageNameForLocale(locale),
        ),
        messages: recent.length > 10 ? recent.sublist(recent.length - 10) : recent,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(_AiChatLine.assistant(reply.trim()));
        _loading = false;
      });
      HapticFeedback.lightImpact();
    } catch (e, stack) {
      await CrashReporting.recordError(e, stack, reason: 'graph_node_ai');
      if (!mounted) return;
      final msg = e is QuotaExceededException ? t['pro_quota_exceeded']! : t['graph_node_ai_error']!;
      setState(() {
        _lines.add(_AiChatLine.assistant(msg));
        _loading = false;
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveConversationToMemory() async {
    final userLines = _lines.where((l) => l.isUser).map((l) => l.text).toList();
    if (userLines.isEmpty || _saving) return;

    final t = ref.read(translationsProvider);
    final memories = _connectedMemories();
    if (graphChatSaveNeedsLinkedMemories(widget.node) && memories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['graph_node_ai_save_failed']!)),
      );
      return;
    }

    final locale = ref.read(languageProvider);
    final plan = planGraphChatSave(
      node: widget.node,
      userLines: userLines,
      contextMemories: memories,
      allMemories: ref.read(memoryListProvider),
      localeCode: locale.languageCode,
      markerLabel: t['graph_node_ai_save_marker']!,
    );
    if (plan == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['graph_node_ai_save_failed']!)),
      );
      return;
    }

    setState(() => _saving = true);
    final Memory? saved;
    try {
      if (plan.isNewMemory) {
        saved = await ref.read(memoryListProvider.notifier).addMemory(plan.memory);
      } else {
        saved = await ref.read(memoryListProvider.notifier).updateMemory(plan.memory);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['graph_node_ai_save_error']!)),
      );
      return;
    }

    var savedMemory = saved;
    if (plan.kind == GraphChatSaveKind.entityAnchor && !isGraphNoteMemory(savedMemory)) {
      final repaired = savedMemory.copyWith(type: kGraphNoteMemoryType);
      final updated = await ref.read(memoryListProvider.notifier).updateMemory(repaired);
      if (updated != null) savedMemory = updated;
    }

    if (!isGraphNoteMemory(savedMemory) && plan.kind == GraphChatSaveKind.entityAnchor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['graph_node_ai_save_type_failed']!)),
      );
      return;
    }
    scheduleGraphAiSync(ref as Ref, savedMemory);
    widget.onSaved?.call(savedMemory.id);
    setState(() {
      _savedMemory = savedMemory;
      _saveResult = GraphChatSaveResult(
        memory: savedMemory,
        kind: plan.kind,
        anchorLabel: plan.anchorLabel,
        relatedEventLabel: plan.relatedEventLabel,
        isNewMemory: plan.isNewMemory,
      );
    });
    HapticFeedback.heavyImpact();
  }

  String _savedBannerMessage(Map<String, String> t) {
    final result = _saveResult;
    final memory = _savedMemory;
    if (result == null || memory == null) return '';

    if (result.kind == GraphChatSaveKind.entityAnchor) {
      return t['graph_node_ai_saved_entity']!.replaceAll('{anchor}', result.anchorLabel);
    }
    return t['graph_node_ai_saved_event']!.replaceAll('{title}', memoryLabelForGraphSave(memory));
  }

  void _openSavedMemory(Memory saved) {
    showMemoryDetailSheet(
      context,
      saved,
      imagePaths: widget.imagePaths,
      options: MemoryDetailPresets.graphFromNodeAi(
        node: widget.node,
        hasVideo: memoryHasVideo(saved.id, widget.videoPaths),
      ),
    );
  }

  IconData _iconForKind(GraphNodeKind kind) => switch (kind) {
        GraphNodeKind.person => Icons.person_rounded,
        GraphNodeKind.pet => Icons.pets_rounded,
        GraphNodeKind.place => Icons.place_rounded,
        GraphNodeKind.memory => Icons.auto_stories_rounded,
        GraphNodeKind.group => Icons.hub_rounded,
        GraphNodeKind.eventHub => Icons.event_rounded,
        GraphNodeKind.activity => Icons.directions_walk_rounded,
        GraphNodeKind.event => Icons.event_note_rounded,
        GraphNodeKind.content => Icons.movie_outlined,
        GraphNodeKind.interest => Icons.lightbulb_outline_rounded,
        GraphNodeKind.food => Icons.restaurant_rounded,
        GraphNodeKind.hobby => Icons.sports_esports_outlined,
        GraphNodeKind.organization => Icons.business_rounded,
        GraphNodeKind.goal => Icons.flag_rounded,
        GraphNodeKind.emotion => Icons.favorite_rounded,
      };

  static const double _inputBarReserve = 76;

  Widget _buildCollapsedChip(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Memory> memories,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(Icons.unfold_more_rounded, size: 16, color: colorScheme.primary),
          label: Text(
            memories.isEmpty ? widget.node.title : '${widget.node.title} · ${memories.length}',
            style: theme.textTheme.labelLarge,
          ),
          onPressed: () => setState(() => _showTopExtras = true),
        ),
      ),
    );
  }

  Widget _buildTopExtras(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Memory> memories,
    Map<String, String> t,
    List<String> suggestions,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasHighlightMedia())
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _playEntityHighlight,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: Text(t['entity_highlight_play']!.replaceAll('{name}', widget.node.title)),
              ),
            ),
          ),
        if (_isEntityMediaNode())
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEntityMedia,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(t['graph_entity_media_open']!),
              ),
            ),
          ),
        if (memories.isNotEmpty)
          GraphNodeInsightPanel(
            node: widget.node,
            insight: buildGraphNodeInsight(
              node: widget.node,
              connectedMemories: memories,
              allMemories: ref.read(memoryListProvider),
              fragments: ref.read(memoryGraphFragmentsProvider),
              localeCode: ref.watch(languageProvider).languageCode,
            ),
            imagePaths: widget.imagePaths,
            localeCode: ref.watch(languageProvider).languageCode,
            translations: t,
            onMemoryTap: (memory) {
              showMemoryDetailSheet(
                context,
                memory,
                imagePaths: widget.imagePaths,
                options: MemoryDetailPresets.full,
              );
            },
            onProTap: () => requireProOrShowPaywall(
              context,
              ref,
              reasonKey: 'pro_reason_insights',
            ),
          ),
        if (memories.isEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _advancedAiEnabled ? suggestions.length : 0,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final q = suggestions[i];
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  avatar: Icon(Icons.bolt_rounded, size: 15, color: colorScheme.tertiary),
                  label: Text(q, style: theme.textTheme.labelMedium),
                  onPressed: _loading ? null : () => _sendMessage(q, fromSuggestion: true),
                );
              },
            ),
          ),
        if (!_advancedAiEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.tonalIcon(
              onPressed: _enableAdvancedAi,
              icon: const Icon(Icons.psychology_alt_rounded, size: 18),
              label: Text(t['graph_node_ai_advanced']!),
            ),
          ),
      ],
    );
  }

  Widget _buildChatBubble(BuildContext context, ThemeData theme, ColorScheme colorScheme, _AiChatLine line) {
    return Align(
      alignment: line.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: line.isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(line.isUser ? 16 : 4),
            bottomRight: Radius.circular(line.isUser ? 4 : 16),
          ),
        ),
        child: Text(line.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final memories = _connectedMemories();
    final suggestions = graphNodeAiSuggestions(node: widget.node, t: t);
    final hasUserReply = _lines.any((l) => l.isUser);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, sheetScroll) {
        final chatFocus = hasUserReply && !_showTopExtras;
        final scrollBottomPad = _inputBarReserve + bottomInset + (_savedMemory != null ? 56 : 0);
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _GradientHeader(
                node: widget.node,
                icon: _iconForKind(widget.node.kind),
                title: t['graph_node_ai_title']!,
                pulse: _pulseController,
                canSave: hasUserReply,
                saving: _saving,
                saved: _savedMemory != null,
                saveLabel: t['graph_node_ai_save']!,
                savedLabel: t['graph_node_ai_saved_done']!,
                onSave: _saveConversationToMemory,
              ),
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: chatFocus ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        sizeCurve: Curves.easeInOut,
                        firstChild: _buildTopExtras(context, theme, colorScheme, memories, t, suggestions),
                        secondChild: _buildCollapsedChip(context, theme, colorScheme, memories),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, scrollBottomPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i == _lines.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return _buildChatBubble(context, theme, colorScheme, _lines[i]);
                          },
                          childCount: _lines.length + (_loading ? 1 : 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_savedMemory != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Material(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _savedBannerMessage(t),
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openSavedMemory(_savedMemory!),
                            child: Text(t['graph_node_ai_saved_view']!),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() {
                              _savedMemory = null;
                              _saveResult = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottomInset),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: _advancedAiEnabled
                                ? t['graph_node_ai_input_hint']!
                                : t['graph_node_ai_note_hint']!,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _submitInput(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _loading ? null : _submitInput,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.node,
    required this.icon,
    required this.title,
    required this.pulse,
    this.canSave = false,
    this.saving = false,
    this.saved = false,
    this.saveLabel = '',
    this.savedLabel = '',
    this.onSave,
  });

  final GraphNodeData node;
  final IconData icon;
  final String title;
  final AnimationController pulse;
  final bool canSave;
  final bool saving;
  final bool saved;
  final String saveLabel;
  final String savedLabel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = '$title · ${node.title}';
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final glow = 0.55 + pulse.value * 0.25;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Color.lerp(node.color, theme.colorScheme.primary, 0.35)!.withValues(alpha: glow),
                node.color.withValues(alpha: 0.35 + pulse.value * 0.15),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
                    child: Icon(icon, size: 20, color: node.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (saved)
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        savedLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (saving)
                const Padding(
                  padding: EdgeInsets.only(left: 46, top: 2),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: canSave ? onSave : null,
                    icon: Icon(
                      Icons.bookmark_add_outlined,
                      size: 17,
                      color: canSave
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    label: Text(
                      saveLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: canSave
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.fromLTRB(34, 0, 8, 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.memory, required this.thumbPath, required this.onTap});

  final Memory memory;
  final String? thumbPath;
  final VoidCallback onTap;

  String _chipLabel() {
    if (isGraphNoteMemory(memory)) {
      final body = graphNoteCardBody(memory);
      if (body.isNotEmpty) return body;
      return '';
    }
    return memory.summary.isNotEmpty ? memory.summary : memory.content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _chipLabel();
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: thumbPath != null && File(thumbPath!).existsSync()
                      ? Image.file(File(thumbPath!), fit: BoxFit.cover)
                      : ColoredBox(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          child: Icon(Icons.photo_outlined, color: theme.colorScheme.primary),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: label.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
