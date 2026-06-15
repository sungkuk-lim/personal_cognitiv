import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/ocr_utils.dart';

class MemoryCard extends ConsumerWidget {
  final Memory memory;
  final VoidCallback? onTap;
  const MemoryCard({super.key, required this.memory, this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final locale = ref.watch(languageProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final localImagePath = imagePathForMemory(memory, imagePaths);
    final hasThumbnail = localImagePath != null;
    final categoryLabel = localizedCategoryLabel(t, memory.category);
    final dateText = locale.languageCode == 'ko'
        ? DateFormat('M월 d일 HH:mm', 'ko').format(memory.createdAt)
        : DateFormat('MMM d, HH:mm', 'en').format(memory.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasThumbnail)
            Image.file(
              File(localImagePath),
              height: 168,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(dateText, style: Theme.of(context).textTheme.labelSmall),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: memory.categoryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text("$categoryLabel > ${memory.subCategory}", style: TextStyle(fontSize: 10, color: memory.categoryColor, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 8),
                if (memory.type == 'image' && !hasThumbnail)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          locale.languageCode == 'ko' ? '사진 기억' : 'Photo memory',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                Text(
                  memory.type == 'image' && isJunkEntityOrKeyword(memory.summary)
                      ? graphTitleForMemory(memory)
                      : memory.summary,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                if (memory.type == 'image' && memory.content != memory.summary)
                  Text(memory.content, maxLines: 4, overflow: TextOverflow.ellipsis)
                else if (memory.type != 'image')
                  Text(memory.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (sanitizeEntities(memory.entities).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      children: sanitizeEntities(memory.entities)
                          .map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 10))))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
