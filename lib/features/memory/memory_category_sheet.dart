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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t['input_category_title']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t['input_category_subtitle']!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(t['input_category_general']!),
                        selected: selected == kMemoryInputCategoryNone,
                        onSelected: (_) => setLocal(() => selected = kMemoryInputCategoryNone),
                      ),
                      for (final cat in memoryInputCategories)
                        ChoiceChip(
                          avatar: Icon(_iconFor(cat.iconName), size: 18),
                          label: Text(cat.labelFor(localeCode)),
                          selected: selected == cat.id,
                          onSelected: (_) => setLocal(() => selected = cat.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
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

IconData _iconFor(String name) => switch (name) {
      'family' => Icons.family_restroom_rounded,
      'lover' => Icons.favorite_rounded,
      'friend' => Icons.people_rounded,
      'company' => Icons.business_center_rounded,
      'study' => Icons.school_rounded,
      'travel' => Icons.flight_takeoff_rounded,
      _ => Icons.category_rounded,
    };
