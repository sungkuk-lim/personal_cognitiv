import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ocr_config.dart';
import 'replay_config.dart';
import 'graph_hub_config.dart';
import 'graph_display_mode.dart';
import 'graph_view_lens.dart';
import '../utils/graph_time_filter.dart';
import '../utils/graph_context_lens.dart';
import '../utils/memory_input_category.dart';

const String prefThemeMode = 'theme_mode';
const String prefSeedColor = 'seed_color';
const String prefGraphPositions = 'graph_node_positions';
const String prefGraphLayoutVersion = 'graph_layout_version';
/// 트리 레이아웃 전환 시 구형(원형 궤도) 저장 좌표를 무효화합니다.
const int kGraphLayoutVersion = 2;
const String prefOcrEngineMode = 'ocr_engine_mode';
const String prefOcrVisionQuality = 'ocr_vision_quality';
const String prefMemoryImagePaths = 'memory_image_paths';
const String prefMemoryImageMemos = 'memory_image_memos';
const String prefMemoryVideoPaths = 'memory_video_paths';
const String prefReplayViewMode = 'replay_view_mode';
const String prefOnDeviceOcr = 'on_device_ocr_enabled';
const String prefGuestMode = 'guest_mode';
const String prefGraphAiEnabled = 'graph_ai_enabled';
const String prefProactiveRecallEnabled = 'proactive_recall_enabled';
const String prefMemoryPulseEnabled = 'memory_pulse_enabled';
const String prefLastPulseDate = 'memory_pulse_last_date';
const String prefLanguageCode = 'language_code';
const String prefOnboardingDone = 'onboarding_done';
const String prefGraphTimeRange = 'graph_time_range';
const String prefGraphHubViewMode = 'graph_hub_view_mode';
const String prefGraphViewLens = 'graph_view_lens';
const String prefGraphDisplayMode = 'graph_display_mode';
const String prefGraphContextLens = 'graph_context_lens';
const String prefOnDeviceOcrInFlight = 'on_device_ocr_in_flight';
const String prefGraphProBannerDismissed = 'graph_pro_banner_dismissed';
const String prefCompletionMilestoneNotified = 'completion_milestone_notified';
const String prefLastMemoryInputCategory = 'last_memory_input_category';
const String prefGraphAchievementsUnlocked = 'graph_achievements_unlocked';
const String prefContactPersonAvatarsEnabled = 'contact_person_avatars_enabled';
const String prefReplayCoachDone = 'replay_coach_done';
const String prefSearchCoachDone = 'search_coach_done';
const String prefGraphTrustHintDismissed = 'graph_trust_hint_dismissed';

bool readGraphTrustHintDismissed(SharedPreferences prefs) =>
    prefs.getBool(prefGraphTrustHintDismissed) ?? false;

Future<void> writeGraphTrustHintDismissed(SharedPreferences prefs, bool dismissed) async {
  await prefs.setBool(prefGraphTrustHintDismissed, dismissed);
}

bool readProactiveRecallEnabled(SharedPreferences prefs) =>
    prefs.getBool(prefProactiveRecallEnabled) ?? false;

Future<void> writeProactiveRecallEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefProactiveRecallEnabled, enabled);
}

bool readMemoryPulseEnabled(SharedPreferences prefs) =>
    prefs.getBool(prefMemoryPulseEnabled) ?? true;

Future<void> writeMemoryPulseEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefMemoryPulseEnabled, enabled);
}

String? readLastPulseDate(SharedPreferences prefs) => prefs.getString(prefLastPulseDate);

Future<void> writeLastPulseDate(SharedPreferences prefs, String dateKey) async {
  await prefs.setString(prefLastPulseDate, dateKey);
}

String readLanguageCode(SharedPreferences prefs) {
  final raw = prefs.getString(prefLanguageCode)?.trim();
  if (raw == null || raw.isEmpty) return 'ko';
  // 구버전 'zh' / 'pt' 값을 신규 id로 정규화합니다.
  if (raw == 'zh') return 'zh_Hans';
  if (raw == 'pt') return 'pt_BR';
  return raw;
}

Future<void> writeLanguageCode(SharedPreferences prefs, String code) async {
  await prefs.setString(prefLanguageCode, code);
}

bool readGraphAiEnabled(SharedPreferences prefs) => prefs.getBool(prefGraphAiEnabled) ?? true;

Future<void> writeGraphAiEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefGraphAiEnabled, enabled);
}

bool readGuestMode(SharedPreferences prefs) => prefs.getBool(prefGuestMode) ?? false;

Future<void> writeGuestMode(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefGuestMode, enabled);
}

ThemeMode readSavedThemeMode(SharedPreferences prefs) {
  switch (prefs.getString(prefThemeMode)) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Color readSeedColor(SharedPreferences prefs) =>
    Color(prefs.getInt(prefSeedColor) ?? 0xFF673AB7);

Future<void> writeSeedColor(SharedPreferences prefs, Color color) async {
  await prefs.setInt(prefSeedColor, color.toARGB32());
}

Future<void> saveThemeMode(SharedPreferences prefs, ThemeMode mode) async {
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
  await prefs.setString(prefThemeMode, value);
}

Map<String, Offset> readSavedGraphPositions(SharedPreferences prefs) {
  final savedVersion = prefs.getInt(prefGraphLayoutVersion) ?? 0;
  if (savedVersion != kGraphLayoutVersion) {
    // 동기 경로에서는 remove만; 다음 프레임에 버전 기록은 save 시 함께.
    prefs.remove(prefGraphPositions);
    // ignore: discarded_futures
    prefs.setInt(prefGraphLayoutVersion, kGraphLayoutVersion);
    return {};
  }
  final raw = prefs.getString(prefGraphPositions);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) {
      final point = value as Map<String, dynamic>;
      return MapEntry(key, Offset((point['dx'] as num).toDouble(), (point['dy'] as num).toDouble()));
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveGraphPositions(SharedPreferences prefs, Map<String, Offset> positions) async {
  final encoded = positions.map((key, value) => MapEntry(key, {'dx': value.dx, 'dy': value.dy}));
  await prefs.setString(prefGraphPositions, jsonEncode(encoded));
  await prefs.setInt(prefGraphLayoutVersion, kGraphLayoutVersion);
}

Map<String, List<String>> readMemoryImagePaths(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryImagePaths);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.map((e) => e.toString()).toList());
      }
      return MapEntry(key, [value.toString()]);
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryImagePaths(SharedPreferences prefs, Map<String, List<String>> paths) async {
  await prefs.setString(prefMemoryImagePaths, jsonEncode(paths));
}

Map<String, List<String>> readMemoryImageMemos(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryImageMemos);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.map((e) => e.toString()).toList());
      }
      return MapEntry(key, [value.toString()]);
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryImageMemos(SharedPreferences prefs, Map<String, List<String>> memos) async {
  await prefs.setString(prefMemoryImageMemos, jsonEncode(memos));
}

Map<String, List<String>> readMemoryVideoPaths(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryVideoPaths);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.map((e) => e.toString()).toList());
      }
      return MapEntry(key, [value.toString()]);
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryVideoPaths(SharedPreferences prefs, Map<String, List<String>> paths) async {
  await prefs.setString(prefMemoryVideoPaths, jsonEncode(paths));
}

ReplayViewMode readReplayViewMode(SharedPreferences prefs) {
  return replayViewModeFromString(prefs.getString(prefReplayViewMode));
}

Future<void> saveReplayViewMode(SharedPreferences prefs, ReplayViewMode mode) async {
  await prefs.setString(prefReplayViewMode, replayViewModeToString(mode));
}

OcrEngineMode readOcrEngineMode(SharedPreferences prefs) {
  switch (prefs.getString(prefOcrEngineMode)) {
    case 'lowCost':
      return OcrEngineMode.lowCost;
    case 'vision':
      return OcrEngineMode.vision;
    default:
      return OcrEngineMode.hybrid;
  }
}

Future<void> saveOcrEngineMode(SharedPreferences prefs, OcrEngineMode mode) async {
  await prefs.setString(prefOcrEngineMode, mode.name);
}

OcrVisionQuality readOcrVisionQuality(SharedPreferences prefs) {
  return prefs.getString(prefOcrVisionQuality) == 'high' ? OcrVisionQuality.high : OcrVisionQuality.low;
}

Future<void> saveOcrVisionQuality(SharedPreferences prefs, OcrVisionQuality quality) async {
  await prefs.setString(prefOcrVisionQuality, quality.name);
}

bool readOnDeviceOcrEnabled(SharedPreferences prefs) {
  return prefs.getBool(prefOnDeviceOcr) ?? false;
}

Future<void> saveOnDeviceOcrEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefOnDeviceOcr, enabled);
}

GraphTimeRange readGraphTimeRange(SharedPreferences prefs) =>
    GraphTimeRangeX.fromPref(prefs.getString(prefGraphTimeRange));

Future<void> writeGraphTimeRange(SharedPreferences prefs, GraphTimeRange range) async {
  await prefs.setString(prefGraphTimeRange, range.prefValue);
}

GraphHubViewMode readGraphHubViewMode(SharedPreferences prefs) =>
    graphHubViewModeFromString(prefs.getString(prefGraphHubViewMode));

Future<void> writeGraphHubViewMode(SharedPreferences prefs, GraphHubViewMode mode) async {
  await prefs.setString(prefGraphHubViewMode, graphHubViewModeToString(mode));
}

GraphViewLens readGraphViewLens(SharedPreferences prefs) =>
    graphViewLensFromString(prefs.getString(prefGraphViewLens));

Future<void> writeGraphViewLens(SharedPreferences prefs, GraphViewLens lens) async {
  await prefs.setString(prefGraphViewLens, graphViewLensToString(lens));
}

GraphDisplayMode readGraphDisplayMode(SharedPreferences prefs) =>
    graphDisplayModeFromString(prefs.getString(prefGraphDisplayMode));

Future<void> writeGraphDisplayMode(SharedPreferences prefs, GraphDisplayMode mode) async {
  await prefs.setString(prefGraphDisplayMode, graphDisplayModeToString(mode));
}

bool readOnDeviceOcrInFlight(SharedPreferences prefs) =>
    prefs.getBool(prefOnDeviceOcrInFlight) ?? false;

Future<void> writeOnDeviceOcrInFlight(SharedPreferences prefs, bool inFlight) async {
  await prefs.setBool(prefOnDeviceOcrInFlight, inFlight);
}

GraphContextLens readGraphContextLens(SharedPreferences prefs) =>
    GraphContextLensX.fromPref(prefs.getString(prefGraphContextLens));

Future<void> writeGraphContextLens(SharedPreferences prefs, GraphContextLens lens) async {
  await prefs.setString(prefGraphContextLens, lens.prefValue);
}

bool readGraphProBannerDismissed(SharedPreferences prefs) =>
    prefs.getBool(prefGraphProBannerDismissed) ?? false;

Future<void> writeGraphProBannerDismissed(SharedPreferences prefs, bool dismissed) async {
  await prefs.setBool(prefGraphProBannerDismissed, dismissed);
}

String readLastMemoryInputCategory(SharedPreferences prefs) =>
    prefs.getString(prefLastMemoryInputCategory) ?? kMemoryInputCategoryNone;

Future<void> writeLastMemoryInputCategory(SharedPreferences prefs, String id) async {
  await prefs.setString(prefLastMemoryInputCategory, id);
}

Set<String> readGraphAchievementsUnlocked(SharedPreferences prefs) {
  final raw = prefs.getString(prefGraphAchievementsUnlocked);
  if (raw == null || raw.isEmpty) return {};
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e.toString()).toSet();
  } catch (_) {
    return {};
  }
}

Future<void> writeGraphAchievementsUnlocked(SharedPreferences prefs, Set<String> ids) async {
  await prefs.setString(prefGraphAchievementsUnlocked, jsonEncode(ids.toList()));
}

bool readContactPersonAvatarsEnabled(SharedPreferences prefs) =>
    prefs.getBool(prefContactPersonAvatarsEnabled) ?? true;

Future<void> writeContactPersonAvatarsEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefContactPersonAvatarsEnabled, enabled);
}
