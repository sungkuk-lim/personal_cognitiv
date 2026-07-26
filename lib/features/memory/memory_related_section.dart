import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/local_memory_thread_service.dart';

/// 상세 시트 하단 — Pro 없이도 연관 기억 표시.
class MemoryRelatedSection extends ConsumerStatefulWidget {
  const MemoryRelatedSection({super.key, required this.memory});

  final Memory memory;

  @override
  ConsumerState<MemoryRelatedSection> createState() => _MemoryRelatedSectionState();
}

class _MemoryRelatedSectionState extends ConsumerState<MemoryRelatedSection> {
  List<Memory>? _related;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRelated());
  }

  @override
  void didUpdateWidget(covariant MemoryRelatedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.id != widget.memory.id) {
      _related = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRelated());
    }
  }

  void _loadRelated() {
    if (!mounted) return;
    final all = ref.read(memoryListProvider);
    final locale = ref.read(languageProvider).languageCode;
    final related = LocalMemoryThreadService.findRelated(
      saved: widget.memory,
      allMemories: all,
      excludeId: widget.memory.id,
      limit: 4,
      localeCode: locale,
    );
    if (!mounted) return;
    setState(() => _related = related);
  }

  @override
  Widget build(BuildContext context) {
    final related = _related;
    if (related == null) {
      return const SizedBox(height: 8);
    }
    if (related.isEmpty) return const SizedBox.shrink();

    final t = ref.read(translationsProvider);
    final imagePaths = ref.read(memoryImagePathsProvider);

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
