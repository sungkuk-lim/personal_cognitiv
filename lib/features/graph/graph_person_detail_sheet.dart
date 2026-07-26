import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_person_hops.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_place_cache.dart';
import 'graph_person_stats.dart';

void showGraphPersonDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required String personName,
}) {
  final localeCode = ref.read(languageProvider).languageCode;
  final t = ref.read(translationsProvider);
  final memories = ref.read(memoryListProvider);
  final imagePaths = ref.read(memoryImagePathsProvider);
  final placeCache = ref.read(memoryPlaceNamesProvider);
  final fullAddressCache = ref.read(memoryPlaceFullAddressesProvider);
  final stats = computePersonGraphStats(
    personName: personName,
    memories: memories,
    imagePaths: imagePaths,
    placeCache: placeCache,
    fullAddressCache: fullAddressCache,
    localeCode: localeCode,
  );
  final hops = groupPeopleByHop(
    personHopDistances(
      fromPerson: personName,
      memories: memories,
      localeCode: localeCode,
      maxDepth: 5,
    ),
  );
  final theme = Theme.of(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final lastLabel = stats.lastMemoryAt == null
          ? (localeCode == 'ko' ? '기록 없음' : 'No records')
          : (localeCode == 'ko'
              ? DateFormat('yyyy.M.d', 'ko').format(stats.lastMemoryAt!)
              : DateFormat('MMM d, yyyy', 'en').format(stats.lastMemoryAt!));

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.person_rounded, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.personName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatRow(
              label: t['graph_person_strength'] ?? '관계 강도',
              value: '${'★' * stats.strengthStars}${'☆' * (5 - stats.strengthStars)}',
            ),
            _StatRow(label: t['graph_person_memories'] ?? '추억', value: personStatsMemoryLabel(stats.memoryCount, localeCode)),
            _StatRow(label: t['graph_person_photos'] ?? '사진', value: personStatsPhotoLabel(stats.photoCount, localeCode)),
            _StatRow(label: t['graph_person_last'] ?? '최근 기억', value: lastLabel),
            if (hops.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t['graph_person_hops_title'] ?? '연결 차수 (최대 5차)',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                t['graph_person_hops_hint'] ??
                    '같은 기억에 함께 나온 사람을 1차로 보고, 그다음 기억으로 이어진 사람을 2~5차로 표시합니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              for (final e in hops.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${e.key}${localeCode == 'ko' ? '차' : '°'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value.take(12).join(localeCode == 'ko' ? ' · ' : ', ') +
                              (e.value.length > 12
                                  ? (localeCode == 'ko'
                                      ? ' 외 ${e.value.length - 12}명'
                                      : ' +${e.value.length - 12}')
                                  : ''),
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (stats.topPlaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t['graph_person_places'] ?? '자주 간 장소',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < stats.topPlaces.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${stats.topPlaces[i]}', style: theme.textTheme.bodyMedium),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                openGraphKeywordFocus(ref, stats.personName);
              },
              icon: const Icon(Icons.hub_outlined),
              label: Text(t['graph_person_expand'] ?? '관계망 확대'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t['close'] ?? '닫기'),
            ),
          ],
        ),
      );
    },
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
