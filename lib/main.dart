import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/crash_reporting.dart';
import 'core/env.dart';
import 'core/prefs.dart';
import 'providers/app_providers.dart';
import 'services/background_recall_worker.dart';
import 'services/local_memory_store.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashReporting.install();
  await initializeDateFormatting('ko', null);
  await initializeDateFormatting('en', null);
  await NotificationService.instance.initialize();
  await BackgroundRecallWorker.initialize();
  await BackgroundRecallWorker.register();
  final prefs = await SharedPreferences.getInstance();
  if (AppEnv.isConfigured) {
    await Supabase.initialize(url: AppEnv.supabaseUrl, publishableKey: AppEnv.supabaseAnonKey);
  }
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        themeModeProvider.overrideWith((ref) => readSavedThemeMode(prefs)),
        graphNodePositionsProvider.overrideWith((ref) => readSavedGraphPositions(prefs)),
        ocrEngineModeProvider.overrideWith((ref) => readOcrEngineMode(prefs)),
        ocrVisionQualityProvider.overrideWith((ref) => readOcrVisionQuality(prefs)),
        onDeviceOcrProvider.overrideWith((ref) => readOnDeviceOcrEnabled(prefs)),
        memoryImagePathsProvider.overrideWith((ref) => readMemoryImagePaths(prefs)),
        privacyLocalModeProvider.overrideWith((ref) => readPrivacyLocalMode(prefs)),
        guestModeProvider.overrideWith((ref) => readGuestMode(prefs)),
      ],
      child: const MemoryOSApp(),
    ),
  );
}
