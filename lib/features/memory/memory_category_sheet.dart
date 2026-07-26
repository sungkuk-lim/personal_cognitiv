import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../utils/memory_input_category.dart';

/// 캡처·음성 입력 전 관계 카테고리를 고릅니다. null = 취소, none = 일반.
Future<String?> showMemoryCategorySheet(BuildContext context, WidgetRef ref) async {
  final t = ref.read(translationsProvider);
  final localeCode = ref.read(languageProvider).languageCode;
  final prefs = ref.read(preferencesProvider);
  var selected = readLastMemoryInputCategory(prefs);

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          void select(String id) => setLocal(() => selected = id);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t['input_category_title']!,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['input_category_subtitle']!,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.65,
                    children: [
                      for (final cat in memoryInputCategories)
                        _CategoryOptionTile(
                          icon: _iconFor(cat.iconName),
                          label: cat.labelFor(localeCode),
                          selected: selected == cat.id,
                          onTap: () => select(cat.id),
                        ),
                      _CategoryOptionTile(
                        icon: Icons.layers_outlined,
                        label: t['input_category_general']!,
                        selected: selected == kMemoryInputCategoryNone,
                        onTap: () => select(kMemoryInputCategoryNone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      await writeLastMemoryInputCategory(prefs, selected);
                      if (context.mounted) Navigator.pop(context, selected);
                    },
                    child: Text(t['input_category_continue']!),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.65);
    final bg = selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.2,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String name) => switch (name) {
      'family' => Icons.family_restroom_rounded,
      'lover' => Icons.favorite_rounded,
      'friend' => Icons.people_rounded,
      'pet' => Icons.pets_rounded,
      'company' => Icons.business_center_rounded,
      'study' => Icons.school_rounded,
      'travel' => Icons.flight_takeoff_rounded,
      _ => Icons.category_rounded,
    };
