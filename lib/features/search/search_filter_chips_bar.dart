import 'package:flutter/material.dart';

import '../../utils/memory_query.dart';

/// 검색 화면 — 파싱된 복합 필터 칩 (Phase A).
class SearchFilterChipsBar extends StatelessWidget {
  const SearchFilterChipsBar({
    super.key,
    required this.query,
    required this.localeCode,
    required this.onRemoveChip,
    required this.onClearAll,
  });

  final MemoryQuery query;
  final String localeCode;
  final void Function(String chipId) onRemoveChip;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = memoryQueryChips(query, localeCode: localeCode);
    if (chips.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.55),
            colorScheme.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localeCode == 'ko' ? '이 조건으로 찾는 중' : 'Active filters',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(localeCode == 'ko' ? '전체 해제' : 'Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              final (icon, color) = _chipStyle(chip.iconName, colorScheme);
              return InputChip(
                avatar: Icon(icon, size: 16, color: color),
                label: Text(chip.label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                deleteIcon: Icon(Icons.close_rounded, size: 16, color: color),
                onDeleted: () => onRemoveChip(chip.id),
                backgroundColor: color.withValues(alpha: 0.12),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _chipStyle(String iconName, ColorScheme scheme) {
    return switch (iconName) {
      'person' => (Icons.person_rounded, Colors.pink.shade400),
      'place' => (Icons.place_rounded, Colors.teal.shade500),
      'emotion' => (Icons.favorite_rounded, Colors.deepOrange.shade400),
      'activity' => (Icons.event_rounded, const Color(0xFF6750A4)),
      'food' => (Icons.restaurant_rounded, Colors.orange.shade600),
      'hobby' => (Icons.interests_rounded, Colors.indigo.shade400),
      'interest' => (Icons.lightbulb_rounded, Colors.deepPurple.shade400),
      'season' => (Icons.wb_sunny_rounded, Colors.amber.shade700),
      'weather' => (Icons.cloud_rounded, Colors.blueGrey.shade500),
      'photo' => (Icons.photo_rounded, scheme.primary),
      'video' => (Icons.videocam_rounded, scheme.tertiary),
      'category' => (Icons.label_rounded, scheme.secondary),
      _ => (Icons.filter_alt_rounded, scheme.primary),
    };
  }
}
