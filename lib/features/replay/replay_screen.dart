import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/memory_image_paths.dart';

/// 월별로 기억을 묶어 사진 썸네일과 함께 보여줍니다.
class ReplayScreen extends ConsumerWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return ReplayTimelineView(
      memories: ref.watch(memoryListProvider),
      imagePaths: ref.watch(memoryImagePathsProvider),
      localeCode: ref.watch(languageProvider).languageCode,
      emptyLabel: t['no_memories']!,
    );
  }
}

class ReplayTimelineView extends StatelessWidget {
  const ReplayTimelineView({
    super.key,
    required this.memories,
    required this.imagePaths,
    required this.localeCode,
    required this.emptyLabel,
  });

  final List<Memory> memories;
  final Map<String, String> imagePaths;
  final String localeCode;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    final grouped = <String, List<Memory>>{};
    for (final memory in memories) {
      final key = localeCode == 'ko'
          ? DateFormat('yyyy년 M월', 'ko').format(memory.createdAt)
          : DateFormat('MMMM yyyy', 'en').format(memory.createdAt);
      grouped.putIfAbsent(key, () => []).add(memory);
    }

    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        final items = grouped[month]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${items.length}'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .map(
                        (memory) {
                          final thumb = imagePathForMemory(memory, imagePaths);
                          return _ReplayTile(
                            memory: memory,
                            imagePath: thumb,
                            onTap: () => showMemoryDetailSheet(context, memory, imagePath: thumb),
                          );
                        },
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReplayTile extends StatelessWidget {
  const _ReplayTile({required this.memory, this.imagePath, this.onTap});

  final Memory memory;
  final String? imagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = memory.type == 'image' && imagePath != null;
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Image.file(File(imagePath!), height: 90, width: double.infinity, fit: BoxFit.cover)
              else
                Container(
                  height: 90,
                  color: memory.categoryColor.withValues(alpha: 0.2),
                  child: Icon(Icons.auto_awesome, color: memory.categoryColor),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  memory.summary.isNotEmpty ? memory.summary : memory.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
