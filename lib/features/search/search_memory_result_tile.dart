import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/local_memory_store.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_theme_tags.dart';
import '../../utils/ocr_utils.dart';

class SearchMemoryResultTile extends StatelessWidget {
  const SearchMemoryResultTile({
    super.key,
    required this.memory,
    required this.imagePaths,
    required this.localeCode,
    required this.onTap,
  });

  final Memory memory;
  final Map<String, List<String>> imagePaths;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = primaryImagePathForMemory(memory, imagePaths);
    final photoCount = imageCountForMemory(memory, imagePaths);
    final title = searchResultTitle(memory);
    final dateText = localeCode == 'ko'
        ? DateFormat('M월 d일 HH:mm', 'ko').format(memory.createdAt)
        : DateFormat('MMM d, HH:mm', 'en').format(memory.createdAt);
    final displayEntities = displayEntitiesForMemory(memory);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: thumb != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(thumb),
                              fit: BoxFit.cover,
                              cacheWidth: 192,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: memory.categoryColor.withValues(alpha: 0.2),
                                child: Icon(Icons.photo_camera_outlined, color: memory.categoryColor),
                              ),
                            ),
                            if (photoCount > 1)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$photoCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : ColoredBox(
                          color: memory.categoryColor.withValues(alpha: 0.2),
                          child: Icon(Icons.photo_camera_outlined, color: memory.categoryColor),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    if (displayEntities.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          displayEntities.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchMemoryResultsList extends ConsumerWidget {
  const SearchMemoryResultsList({
    super.key,
    required this.memories,
    required this.imagePaths,
    required this.localeCode,
    this.header,
    this.searchQuery = '',
  });

  final List<Memory> memories;
  final Map<String, List<String>> imagePaths;
  final String localeCode;
  final String? header;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final keyword = primaryKeywordForMemories(memories, searchQuery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null && header!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(header!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        if (keyword != null && keyword.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (countEntityHighlightSlides(
                      entityLabel: keyword,
                      allMemories: ref.watch(memoryListProvider),
                      imagePaths: ref.watch(memoryImagePathsProvider),
                      videoPaths: ref.watch(memoryVideoPathsProvider),
                    ) >
                    0)
                  FilledButton.tonalIcon(
                    onPressed: () => launchEntityHighlight(
                      context: context,
                      ref: ref,
                      entityLabel: keyword,
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: Text(t['search_entity_highlight']!.replaceAll('{keyword}', keyword)),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openGraphForMemories(ref, memories, searchQuery),
                  icon: const Icon(Icons.hub_outlined, size: 18),
                  label: Text(t['search_open_graph']!.replaceAll('{keyword}', keyword)),
                ),
              ],
            ),
          ),
        ],
        ...memories.map(
          (m) => SearchMemoryResultTile(
            memory: m,
            imagePaths: imagePaths,
            localeCode: localeCode,
            onTap: () => showMemoryDetailSheet(context, m, options: MemoryDetailPresets.full),
          ),
        ),
      ],
    );
  }
}
