import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/crash_reporting.dart';
import 'core/env.dart';
import 'core/prefs.dart';
import 'core/system_ui.dart';
import 'l10n/app_locales.dart';
import 'providers/app_providers.dart';
import 'providers/care_dictionary_provider.dart';
import 'services/background_recall_worker.dart';
import 'services/fcm_push_service.dart';
import 'services/local_memory_store.dart';
import 'services/memory_pulse_worker.dart';
import 'services/notification_service.dart';
import 'utils/memory_image_paths.dart';
import 'utils/memory_place_cache.dart';
import 'utils/graph_snapshot_store.dart';
import 'utils/memory_video_paths.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    ensureStatusBarVisible();
    await CrashReporting.install();
  }

  await initializeDateFormatting('ko', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('ja', null);
  await initializeDateFormatting('zh', null);
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('fr', null);
  await initializeDateFormatting('de', null);
  await initializeDateFormatting('pt', null);
  await initializeDateFormatting('vi', null);
  
  tz_data.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  } catch (e) {
    debugPrint('Timezone error: $e');
  }

  if (!kIsWeb) {
    await NotificationService.instance.initialize();
    await BackgroundRecallWorker.initialize();
  }

  final prefs = await SharedPreferences.getInstance();

  if (!kIsWeb) {
    await FcmPushService.instance.start(prefs: prefs);
    if (readProactiveRecallEnabled(prefs)) {
      await BackgroundRecallWorker.register();
    } else if (readMemoryPulseEnabled(prefs)) {
      await MemoryPulseWorker.register();
    }
    if (readMemoryPulseEnabled(prefs)) {
      await MemoryPulseWorker.ensureScheduled(prefs);
      final localMemories = LocalMemoryStore(prefs).loadAll();
      if (localMemories.isNotEmpty) {
        await MemoryPulseWorker.saveMemorySnapshot(prefs, localMemories);
      }
    }
    await warmMemoryImagesDirectoryCache();
    await warmMemoryVideosDirectoryCache();
    await CrashReporting.sendConnectivitySmokeTestOnce(prefs);
    if (readOnDeviceOcrInFlight(prefs)) {
      await saveOnDeviceOcrEnabled(prefs, false);
      await writeOnDeviceOcrInFlight(prefs, false);
    }
  }

  if (AppEnv.isConfigured) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        themeModeProvider.overrideWith((ref) => readSavedThemeMode(prefs)),
        seedColorProvider.overrideWith((ref) => readSeedColor(prefs)),
        graphNodePositionsProvider.overrideWith((ref) => readSavedGraphPositions(prefs)),
        ocrEngineModeProvider.overrideWith((ref) => readOcrEngineMode(prefs)),
        ocrVisionQualityProvider.overrideWith((ref) => readOcrVisionQuality(prefs)),
        onDeviceOcrProvider.overrideWith((ref) => kIsWeb ? false : readOnDeviceOcrEnabled(prefs)),
        memoryImagePathsProvider.overrideWith((ref) => kIsWeb ? {} : readMemoryImagePaths(prefs)),
        memoryImageMemosProvider.overrideWith((ref) => kIsWeb ? {} : readMemoryImageMemos(prefs)),
        memoryVideoPathsProvider.overrideWith((ref) => kIsWeb ? {} : readMemoryVideoPaths(prefs)),
        memoryPlaceNamesProvider.overrideWith((ref) => readMemoryPlaceNames(prefs)),
        memoryPlaceFullAddressesProvider.overrideWith((ref) => readMemoryPlaceFullAddresses(prefs)),
        graphAiEnabledProvider.overrideWith((ref) => readGraphAiEnabled(prefs)),
        proactiveRecallEnabledProvider.overrideWith((ref) => readProactiveRecallEnabled(prefs)),
        memoryPulseEnabledProvider.overrideWith((ref) => readMemoryPulseEnabled(prefs)),
        languageProvider.overrideWith((ref) => localeFromId(readLanguageCode(prefs))),
        memoryGraphFragmentsProvider.overrideWith((ref) => readMemoryGraphFragments(prefs)),
        memoryGraphClustersProvider.overrideWith((ref) => readMemoryGraphClusters(prefs)),
        replayViewModeProvider.overrideWith((ref) => readReplayViewMode(prefs)),
        privacyLocalModeProvider.overrideWith((ref) => readPrivacyLocalMode(prefs)),
        guestModeProvider.overrideWith((ref) => readGuestMode(prefs)),
        graphTimeRangeProvider.overrideWith((ref) => readGraphTimeRange(prefs)),
        graphHubViewModeProvider.overrideWith((ref) => readGraphHubViewMode(prefs)),
        graphViewLensProvider.overrideWith((ref) => readGraphViewLens(prefs)),
        graphDisplayModeProvider.overrideWith((ref) => readGraphDisplayMode(prefs)),
        graphContextLensProvider.overrideWith((ref) => readGraphContextLens(prefs)),
        contactPersonAvatarsEnabledProvider.overrideWith((ref) => readContactPersonAvatarsEnabled(prefs)),
        careDictionaryProvider.overrideWith((ref) => CareDictionaryNotifier(prefs)),
      ],
      child: const MemoryOSApp(),
    ),
  );
}
