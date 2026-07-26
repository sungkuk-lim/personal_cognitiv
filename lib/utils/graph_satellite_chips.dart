import 'package:flutter/material.dart';

import '../features/graph/graph_layout.dart';
import '../models/memory.dart';
import 'graph_satellites.dart';
import 'memory_entity_cache.dart';
import 'memory_entity_edit.dart';
import 'memory_keyword_ui.dart';

/// 회상·미리보기용 위성 칩 항목.
class GraphSatelliteChipItem {
  const GraphSatelliteChipItem({required this.label, required this.kind});

  final String label;
  final GraphNodeKind kind;
}

List<GraphSatelliteChipItem> collectGraphSatelliteChipItems(
  Memory memory, {
  String localeCode = 'ko',
  int maxCount = 6,
}) {
  if (memoryHasManualEntityEdit(memory)) {
    return displayTagsForMemory(memory, localeCode: localeCode)
        .take(maxCount)
        .map(
          (label) => GraphSatelliteChipItem(
            label: label,
            kind: _chipKindForLabel(label, memory, localeCode),
          ),
        )
        .toList();
  }

  final satellites = MemoryEntityCache.visibleSatellites(memory, localeCode: localeCode);
  final items = <GraphSatelliteChipItem>[];

  void addMany(GraphNodeKind kind, List<String> labels) {
    for (final label in labels) {
      if (items.length >= maxCount) return;
      items.add(GraphSatelliteChipItem(label: label, kind: kind));
    }
  }

  addMany(GraphNodeKind.person, satellites.people);
  addMany(GraphNodeKind.pet, satellites.pets);
  addMany(GraphNodeKind.place, satellites.places);
  addMany(GraphNodeKind.activity, satellites.activities);
  addMany(GraphNodeKind.event, satellites.events);
  addMany(GraphNodeKind.emotion, satellites.emotions);
  addMany(GraphNodeKind.food, satellites.food);
  addMany(GraphNodeKind.organization, satellites.organizations);
  addMany(GraphNodeKind.interest, satellites.interests);
  addMany(GraphNodeKind.hobby, satellites.hobbies);

  return items;
}

GraphNodeKind _chipKindForLabel(String label, Memory memory, String localeCode) {
  return switch (classifyKeyword(label, memory, localeCode: localeCode)) {
    MemoryKeywordKind.person => GraphNodeKind.person,
    MemoryKeywordKind.pet => GraphNodeKind.pet,
    MemoryKeywordKind.place => GraphNodeKind.place,
    MemoryKeywordKind.event => GraphNodeKind.event,
    MemoryKeywordKind.interest => GraphNodeKind.interest,
    MemoryKeywordKind.food => GraphNodeKind.food,
    MemoryKeywordKind.organization => GraphNodeKind.organization,
    MemoryKeywordKind.activity => GraphNodeKind.activity,
    MemoryKeywordKind.tag => GraphNodeKind.activity,
  };
}

IconData iconForGraphNodeKind(GraphNodeKind kind) {
  return switch (kind) {
    GraphNodeKind.person => Icons.person_outline_rounded,
    GraphNodeKind.pet => Icons.pets_outlined,
    GraphNodeKind.place => Icons.place_outlined,
    GraphNodeKind.activity => Icons.directions_walk_outlined,
    GraphNodeKind.event => Icons.event_outlined,
    GraphNodeKind.content => Icons.menu_book_outlined,
    GraphNodeKind.interest => Icons.favorite_border_rounded,
    GraphNodeKind.food => Icons.restaurant_outlined,
    GraphNodeKind.hobby => Icons.sports_esports_outlined,
    GraphNodeKind.organization => Icons.business_outlined,
    GraphNodeKind.goal => Icons.flag_outlined,
    GraphNodeKind.emotion => Icons.sentiment_satisfied_alt_outlined,
    _ => Icons.sell_outlined,
  };
}

Color colorForGraphNodeKind(GraphNodeKind kind, ColorScheme scheme) {
  return graphNodeKindColor(kind);
}

List<Widget> buildGraphSatelliteChips(
  Memory memory,
  ColorScheme colorScheme, {
  String localeCode = 'ko',
  int maxCount = 6,
  void Function(String keyword, GraphNodeKind kind)? onChipTap,
}) {
  final items = collectGraphSatelliteChipItems(memory, localeCode: localeCode, maxCount: maxCount);
  if (items.isEmpty) {
    return buildKeywordChips(
      memory,
      colorScheme,
      maxCount: maxCount,
      onKeywordTap: onChipTap == null ? null : (k) => onChipTap(k, GraphNodeKind.activity),
    );
  }

  return items.map((item) {
    final color = colorForGraphNodeKind(item.kind, colorScheme);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForGraphNodeKind(item.kind), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            item.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    if (onChipTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChipTap(item.label, item.kind),
        borderRadius: BorderRadius.circular(20),
        child: chip,
      ),
    );
  }).toList();
}
