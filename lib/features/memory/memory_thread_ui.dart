import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../services/memory_thread_service.dart';

Future<void> showMemoryThreadSuggestions(BuildContext context, WidgetRef ref, Memory saved) async {
  if (saved.embedding == null) return;
  final related = await MemoryThreadService.instance.findRelated(
    embedding: saved.embedding!,
    excludeId: saved.id,
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
            builder: (ctx) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t['thread_title']!, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...related.map((m) => ListTile(
                      title: Text(m.summary),
                      subtitle: Text(m.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(selectedMemoryIdProvider.notifier).state = m.id;
                        showMemoryDetailSheet(context, m, imagePath: ref.read(memoryImagePathsProvider)[m.id]);
                      },
                    )),
              ],
            ),
          );
        },
      ),
      duration: const Duration(seconds: 5),
    ),
  );
}
