import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ocr_config.dart';
import '../core/replay_config.dart';
import '../models/graph_ai_snapshot.dart';
import '../l10n/translations.dart';
import '../core/graph_hub_config.dart';
import '../utils/graph_time_filter.dart';

final searchQueryProvider = StateProvider<String>((ref) => "");
final highlightedEntitiesProvider = StateProvider<List<String>>((ref) => []);
final preferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('preferencesProvider must be overridden in main()'));
final graphNodePositionsProvider = StateProvider<Map<String, Offset>>((ref) => {});
final selectedGraphNodeProvider = StateProvider<String?>((ref) => null);
final selectedMemoryIdProvider = StateProvider<String?>((ref) => null);
/// 관계망 키워드 포커스 모드 (null = 전체 그래프).
final graphFocusKeywordProvider = StateProvider<String?>((ref) => null);
/// 관계망 기억 포커스 — 단일 기억 + 위성만 표시 (키워드 포커스보다 우선).
final graphFocusMemoryIdProvider = StateProvider<String?>((ref) => null);
/// 하단 탭 인덱스 (0 타임라인, 1 검색, 2 관계망, 3 회상).
final mainNavigationTabProvider = StateProvider<int>((ref) => 0);
final proactiveRecallEnabledProvider = StateProvider<bool>((ref) => true);
final memoryPulseEnabledProvider = StateProvider<bool>((ref) => true);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final seedColorProvider = StateProvider<Color>((ref) => Colors.deepPurple);
final languageProvider = StateProvider<Locale>((ref) => const Locale('ko'));
final ocrEngineModeProvider = StateProvider<OcrEngineMode>((ref) => OcrEngineMode.hybrid);
final ocrVisionQualityProvider = StateProvider<OcrVisionQuality>((ref) => OcrVisionQuality.low);
final onDeviceOcrProvider = StateProvider<bool>((ref) => false);
final memoryImagePathsProvider = StateProvider<Map<String, List<String>>>((ref) => {});
final memoryImageMemosProvider = StateProvider<Map<String, List<String>>>((ref) => {});
final memoryVideoPathsProvider = StateProvider<Map<String, List<String>>>((ref) => {});
final memoryPlaceNamesProvider = StateProvider<Map<String, String>>((ref) => {});
final memoryPlaceFullAddressesProvider = StateProvider<Map<String, String>>((ref) => {});
final graphAiEnabledProvider = StateProvider<bool>((ref) => true);
final memoryGraphFragmentsProvider = StateProvider<Map<String, GraphMemoryFragment>>((ref) => {});
final memoryGraphClustersProvider = StateProvider<Map<String, GraphClusterSnapshot>>((ref) => {});
final replayViewModeProvider = StateProvider<ReplayViewMode>((ref) => ReplayViewMode.shared);
final privacyLocalModeProvider = StateProvider<bool>((ref) => false);
final guestModeProvider = StateProvider<bool>((ref) => false);
final graphTimeRangeProvider = StateProvider<GraphTimeRange>((ref) => GraphTimeRange.days7);
final graphHubViewModeProvider = StateProvider<GraphHubViewMode>((ref) => GraphHubViewMode.memoryHub);
final contactPersonAvatarsEnabledProvider = StateProvider<bool>((ref) => true);
/// 관계망 내 엔티티·노드 제목 필터.
final graphEntitySearchProvider = StateProvider<String>((ref) => '');

final translationsProvider = Provider((ref) {
  final locale = ref.watch(languageProvider);
  return translationsFor(locale);
});

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
