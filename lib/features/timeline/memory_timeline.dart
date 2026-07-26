import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/timeline_providers.dart';
import '../../services/image_pipeline_service.dart';
import '../../services/video_pipeline_service.dart';
import '../../widgets/daily_capture_nudge.dart';
import '../../widgets/app_empty_state.dart';
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
    final snapshot = ref.watch(timelineListSnapshotProvider);
    final memories = snapshot.memories;
    final t = snapshot.translations;
    final groups = snapshot.groups;
    final cardContext = TimelineCardContext(
      locale: snapshot.locale,
      translations: snapshot.translations,
      imagePaths: snapshot.imagePaths,
      imageMemos: snapshot.imageMemos,
      videoPaths: snapshot.videoPaths,
      placeCache: snapshot.placeCache,
      fullAddressCache: snapshot.fullAddressCache,
      allMemories: memories,
      cardMeta: snapshot.cardMeta,
    );

    if (memories.isEmpty) {
      return AppEmptyState(
        icon: Icons.auto_awesome,
        title: t['no_memories']!,
        subtitle: t['empty_hint'],
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(memoryListProvider.notifier).reload(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: true,
        cacheExtent: 720,
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
                  contextData: cardContext,
                  onTap: () => showMemoryDetailSheet(
                    context,
                    memory,
                    imagePaths: snapshot.imagePaths,
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
              contextData: cardContext,
              confirmDelete: () => _confirmDelete(context, ref),
              onDeleteMemory: (memory) => _handleDelete(context, ref, memory.id, t),
              onTapMemory: (memory) => showMemoryDetailSheet(
                context,
                memory,
                imagePaths: snapshot.imagePaths,
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
