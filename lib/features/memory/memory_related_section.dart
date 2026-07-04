import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/local_memory_thread_service.dart';

/// 상세 시트 하단 — Pro 없이도 연관 기억 표시.
class MemoryRelatedSection extends ConsumerWidget {
  const MemoryRelatedSection({super.key, required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(memoryListProvider);
    final locale = ref.watch(languageProvider).languageCode;
    final related = LocalMemoryThreadService.findRelated(
      saved: memory,
      allMemories: all,
      excludeId: memory.id,
      limit: 4,
      localeCode: locale,
    );
    if (related.isEmpty) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(t['related_memories_title']!, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...related.map(
          (m) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.link_rounded, size: 20),
              title: Text(
                m.summary.trim().isNotEmpty ? m.summary : m.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                m.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () {
                Navigator.pop(context);
                showMemoryDetailSheet(
                  context,
                  m,
                  imagePaths: imagePaths,
                  options: MemoryDetailPresets.full,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
