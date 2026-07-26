import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../utils/entity_canonical.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/korean_person_names.dart';
import '../../utils/medical_entity_lexicon.dart';
import '../../utils/memory_entity_cache.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_participation_extract.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';
import 'graph_person_detail_sheet.dart';

/// 관계망 대규모 탐색용 목록 대체 뷰.
class GraphListView extends ConsumerWidget {
  const GraphListView({
    super.key,
    required this.memories,
    required this.localeCode,
    required this.peopleLabel,
    required this.placesLabel,
    required this.memoriesLabel,
    required this.emptyLabel,
  });

  final List<Memory> memories;
  final String localeCode;
  final String peopleLabel;
  final String placesLabel;
  final String memoriesLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = buildGraphListEntries(memories, localeCode: localeCode);

    if (entries.people.isEmpty && entries.places.isEmpty && entries.memoryItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyLabel, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (entries.people.isNotEmpty) ...[
          _SectionHeader(title: peopleLabel, icon: Icons.person_outline_rounded),
          for (final person in entries.people)
            _GraphListTile(
              title: person.label,
              subtitle: localeCode == 'ko' ? '추억 ${person.count}개' : '${person.count} memories',
              icon: Icons.person_rounded,
              color: graphNodeKindColor(GraphNodeKind.person),
              onTap: () => showGraphPersonDetailSheet(context, ref, personName: person.label),
            ),
          const SizedBox(height: 12),
        ],
        if (entries.places.isNotEmpty) ...[
          _SectionHeader(title: placesLabel, icon: Icons.place_outlined),
          for (final place in entries.places)
            _GraphListTile(
              title: place.label,
              subtitle: localeCode == 'ko' ? '연결 ${place.count}건' : '${place.count} links',
              icon: Icons.place_rounded,
              color: graphNodeKindColor(GraphNodeKind.place),
              onTap: () => openGraphKeywordFocus(ref, place.label),
            ),
          const SizedBox(height: 12),
        ],
        if (entries.memoryItems.isNotEmpty) ...[
          _SectionHeader(title: memoriesLabel, icon: Icons.auto_stories_outlined),
          for (final item in entries.memoryItems)
            _GraphListTile(
              title: item.title,
              subtitle: item.dateLabel,
              icon: Icons.memory_rounded,
              color: graphNodeKindColor(GraphNodeKind.memory),
              onTap: () => openGraphForMemory(ref, item.memory),
            ),
        ],
      ],
    );
  }
}

class GraphListEntries {
  const GraphListEntries({
    required this.people,
    required this.places,
    required this.memoryItems,
  });

  final List<GraphListCountEntry> people;
  final List<GraphListCountEntry> places;
  final List<GraphListMemoryEntry> memoryItems;
}

class GraphListCountEntry {
  const GraphListCountEntry({required this.label, required this.count});

  final String label;
  final int count;
}

class GraphListMemoryEntry {
  const GraphListMemoryEntry({
    required this.memory,
    required this.title,
    required this.dateLabel,
  });

  final Memory memory;
  final String title;
  final String dateLabel;
}

GraphListEntries buildGraphListEntries(
  List<Memory> memories, {
  String localeCode = 'ko',
}) {
  final peopleCounts = <String, int>{};
  final placeCounts = <String, int>{};

  for (final memory in memories) {
    if (!isLayoutPrimaryMemory(memory)) continue;
    final bundle = MemoryEntityCache.bundle(memory, localeCode: localeCode);
    for (final person in bundle.people) {
      if (isSelfPersonLabel(person, localeCode)) continue;
      final key = stripTrailingKoreanParticles(person.trim());
      if (key.isEmpty || isBlockedPersonName(key)) continue;
      if (isMedicalGraphNoisePhrase(key) || isMedicalNonPersonToken(key)) continue;
      peopleCounts[key] = (peopleCounts[key] ?? 0) + 1;
    }
    for (final place in bundle.places) {
      final key = canonicalEntityLabel(place);
      if (key.isEmpty || isMedicalGraphNoisePhrase(key)) continue;
      placeCounts[key] = (placeCounts[key] ?? 0) + 1;
    }
  }

  final people = peopleCounts.entries
      .map((e) => GraphListCountEntry(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  final places = placeCounts.entries
      .map((e) => GraphListCountEntry(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final memoryItems = <GraphListMemoryEntry>[];
  final sorted = [...memories.where(isLayoutPrimaryMemory)]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final memory in sorted.take(80)) {
    final title = graphMeaningSentence(memory, localeCode: localeCode);
    final at = memory.createdAt;
    final dateLabel = localeCode == 'ko'
        ? '${at.year}.${at.month}.${at.day}'
        : '${at.year}-${at.month}-${at.day}';
    memoryItems.add(GraphListMemoryEntry(memory: memory, title: title, dateLabel: dateLabel));
  }

  return GraphListEntries(
    people: people.take(40).toList(),
    places: places.take(40).toList(),
    memoryItems: memoryItems,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GraphListTile extends StatelessWidget {
  const _GraphListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}
