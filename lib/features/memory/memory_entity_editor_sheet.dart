import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/memory_entity_edit.dart';

/// 기억 상세에서 관계 태그(인물·장소 등)를 수동으로 수정합니다.
Future<void> showMemoryEntityEditor(
  BuildContext context,
  WidgetRef ref, {
  required Memory memory,
}) async {
  final t = ref.read(translationsProvider);
  final labels = editableEntityLabelsForMemory(memory);
  final controller = TextEditingController();
  final working = [...labels];

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          void addLabel() {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            if (working.any((e) => e == value)) {
              controller.clear();
              return;
            }
            setLocal(() {
              working.add(value);
              controller.clear();
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t['entity_edit_title']!,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  t['entity_edit_hint']!,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in working)
                      InputChip(
                        label: Text(label),
                        onDeleted: () => setLocal(() => working.remove(label)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => addLabel(),
                        decoration: InputDecoration(
                          hintText: t['entity_edit_add_hint']!,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: addLabel,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final latest = ref.read(memoryListProvider).where((m) => m.id == memory.id).firstOrNull ?? memory;
                    final merged = mergeManualEntityLabels(latest, working);
                    final saved = await ref.read(memoryListProvider.notifier).updateMemory(
                          latest.copyWith(entities: merged),
                        );
                    if (saved == null) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(t['entity_edit_save_failed']!)),
                        );
                      }
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t['entity_edit_saved']!)),
                      );
                    }
                  },
                  child: Text(t['save'] ?? '저장'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  controller.dispose();
}
