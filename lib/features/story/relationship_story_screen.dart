import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/memory_video_paths.dart';
import '../../widgets/trust_source_badge.dart';
import '../graph/graph_chat_save.dart';

/// 인물·장소별 관계 스토리 — 하이라이트 + 날짜별 챕터.
class RelationshipStoryScreen extends ConsumerWidget {
  const RelationshipStoryScreen({
    super.key,
    required this.entityLabel,
  });

  final String entityLabel;

  static Future<void> open(BuildContext context, WidgetRef ref, String entityLabel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RelationshipStoryScreen(entityLabel: entityLabel),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final locale = ref.watch(languageProvider).languageCode;
    final memories = ref
        .watch(memoryListProvider)
        .where(isUserFacingMemory)
        .where((m) => memoryMatchesKeyword(m, entityLabel))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final videoPaths = ref.watch(memoryVideoPathsProvider);
    final slideCount = countEntityHighlightSlides(
      entityLabel: entityLabel,
      allMemories: ref.read(memoryListProvider),
      imagePaths: imagePaths,
      videoPaths: videoPaths,
    );

    final chapters = _groupByDate(memories, locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(t['relationship_story_title']!.replaceAll('{name}', entityLabel)),
      ),
      body: memories.isEmpty
          ? Center(child: Text(t['relationship_story_empty']!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (slideCount > 0)
                  FilledButton.tonalIcon(
                    onPressed: () => launchEntityHighlight(
                      context: context,
                      ref: ref,
                      entityLabel: entityLabel,
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(t['entity_highlight_play']!.replaceAll('{name}', entityLabel)),
                  ),
                const SizedBox(height: 12),
                Text(
                  t['relationship_story_chapters']!.replaceAll('{count}', '${memories.length}'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...chapters.map((chapter) => _StoryChapterTile(
                      chapter: chapter,
                      imagePaths: imagePaths,
                      videoPaths: videoPaths,
                      onTap: (memory) => showMemoryDetailSheet(
                        context,
                        memory,
                        imagePaths: imagePaths,
                        options: MemoryDetailPresets.full,
                      ),
                    )),
              ],
            ),
    );
  }

  List<_StoryChapter> _groupByDate(List<Memory> memories, String localeCode) {
    final map = <String, List<Memory>>{};
    for (final memory in memories) {
      final key = localeCode == 'ko'
          ? DateFormat('yyyy년 M월 d일', 'ko').format(memory.createdAt)
          : DateFormat('MMMM d, yyyy', 'en').format(memory.createdAt);
      map.putIfAbsent(key, () => []).add(memory);
    }
    return map.entries
        .map((e) => _StoryChapter(dateLabel: e.key, memories: e.value))
        .toList();
  }
}

class _StoryChapter {
  const _StoryChapter({required this.dateLabel, required this.memories});
  final String dateLabel;
  final List<Memory> memories;
}

class _StoryChapterTile extends StatelessWidget {
  const _StoryChapterTile({
    required this.chapter,
    required this.imagePaths,
    required this.videoPaths,
    required this.onTap,
  });

  final _StoryChapter chapter;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> videoPaths;
  final void Function(Memory memory) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(chapter.dateLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${chapter.memories.length}'),
        children: chapter.memories
            .map(
              (memory) => ListTile(
                leading: _thumb(memory),
                title: Text(
                  memory.summary.trim().isNotEmpty ? memory.summary.trim() : memory.content.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TrustSourceBadge(memory: memory, compact: true),
                onTap: () => onTap(memory),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget? _thumb(Memory memory) {
    final path = primaryMediaThumbForMemoryId(memory.id, imagePaths, videoPaths);
    if (path == null) {
      return CircleAvatar(
        backgroundColor: memory.categoryColor.withValues(alpha: 0.2),
        child: Icon(Icons.memory_rounded, color: memory.categoryColor, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
      ),
    );
  }
}
