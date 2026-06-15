import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ocr_config.dart';
import '../l10n/translations.dart';

final searchQueryProvider = StateProvider<String>((ref) => "");
final highlightedEntitiesProvider = StateProvider<List<String>>((ref) => []);
final preferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('preferencesProvider must be overridden in main()'));
final graphNodePositionsProvider = StateProvider<Map<String, Offset>>((ref) => {});
final selectedGraphNodeProvider = StateProvider<String?>((ref) => null);
final selectedMemoryIdProvider = StateProvider<String?>((ref) => null);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final seedColorProvider = StateProvider<Color>((ref) => Colors.deepPurple);
final languageProvider = StateProvider<Locale>((ref) => const Locale('ko'));
final ocrEngineModeProvider = StateProvider<OcrEngineMode>((ref) => OcrEngineMode.hybrid);
final ocrVisionQualityProvider = StateProvider<OcrVisionQuality>((ref) => OcrVisionQuality.low);
final onDeviceOcrProvider = StateProvider<bool>((ref) => false);
final memoryImagePathsProvider = StateProvider<Map<String, String>>((ref) => {});
final privacyLocalModeProvider = StateProvider<bool>((ref) => false);
final guestModeProvider = StateProvider<bool>((ref) => false);

final translationsProvider = Provider((ref) {
  final locale = ref.watch(languageProvider);
  return translationsFor(locale);
});

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
