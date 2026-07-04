import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/image_pipeline_service.dart';
import '../../services/video_pipeline_service.dart';
import '../../utils/memory_grouping.dart';
import '../../widgets/daily_capture_nudge.dart';
import 'memory_card.dart';

class MemoryTimeline extends ConsumerWidget {
  const MemoryTimeline({super.key, this.onCaptureTap});

  final VoidCallback? onCaptureTap;

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.read(translationsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['delete_confirm_title']!),
        content: Text(t['delete_confirm_body']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t['cancel']!)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t['delete']!)),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryListProvider);
    final t = ref.watch(translationsProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final groups = groupMemoriesForTimeline(memories);

    if (memories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                t['no_memories']!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t['empty_hint']!,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(memoryListProvider.notifier).reload(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return DailyCaptureNudge(memories: memories, onCaptureTap: onCaptureTap);
          }
          final group = groups[index - 1];
          if (!group.isGrouped) {
            final memory = group.primary;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Dismissible(
              key: Key(memory.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(context, ref),
              background: _deleteBackground(),
              onDismissed: (_) => _handleDelete(context, ref, memory.id, t),
              child: MemoryCard(
                memory: memory,
                onTap: () => showMemoryDetailSheet(
                  context,
                  memory,
                  imagePaths: imagePaths,
                  options: MemoryDetailPresets.full,
                ),
              ),
            ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MemoryGroupCard(
            group: group,
            confirmDelete: () => _confirmDelete(context, ref),
            onDeleteMemory: (memory) => _handleDelete(context, ref, memory.id, t),
            onTapMemory: (memory) => showMemoryDetailSheet(
              context,
              memory,
              imagePaths: imagePaths,
              options: MemoryDetailPresets.full,
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, String memoryId, Map<String, String> t) async {
    final ok = await ref.read(memoryListProvider.notifier).deleteMemory(memoryId);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      await deleteLocalMemoryImage(ref, memoryId);
      await deleteAllMemoryVideos(ref, memoryId);
      messenger.showSnackBar(SnackBar(content: Text(t['deleted']!), duration: const Duration(seconds: 2)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(t['delete_failed']!)));
      await ref.read(memoryListProvider.notifier).reload();
    }
  }
}
