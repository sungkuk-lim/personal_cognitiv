import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/memory_thread_service.dart';

Future<void> showMemoryThreadSuggestions(BuildContext context, WidgetRef ref, Memory saved) async {
  final allMemories = ref.read(memoryListProvider);
  final locale = ref.read(languageProvider).languageCode;
  final related = await MemoryThreadService.instance.findRelated(
    saved: saved,
    allMemories: allMemories,
    embedding: saved.embedding,
    excludeId: saved.id,
    localeCode: locale,
  );
  if (!context.mounted || related.isEmpty) return;
  final t = ref.read(translationsProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(t['thread_found']!),
      action: SnackBarAction(
        label: t['view']!,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(t['thread_title']!, style: Theme.of(ctx).textTheme.titleMedium),
                if (saved.embedding == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    t['thread_local_hint']!,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                ...related.map(
                  (m) => ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: Text(m.summary.trim().isNotEmpty ? m.summary : m.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(m.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(selectedMemoryIdProvider.notifier).state = m.id;
                      showMemoryDetailSheet(
                        context,
                        m,
                        imagePaths: ref.read(memoryImagePathsProvider),
                        options: MemoryDetailPresets.full,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}
