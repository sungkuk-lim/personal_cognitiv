import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/env.dart';
import '../../core/ocr_config.dart';
import '../../core/prefs.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/graph/relationship_graph_screen.dart';
import '../../features/memory/memory_category_sheet.dart';
import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../features/memory/memory_thread_ui.dart';
import '../../services/background_recall_worker.dart';
import '../../services/place_lookup_service.dart';
import '../../services/proactive_recall_service.dart';
import '../../features/memory/photo_pick_flow.dart';
import '../../features/replay/replay_screen.dart';
import '../../features/search/cognitive_search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/timeline/memory_timeline.dart';
import '../../features/voice/voice_input_dialog.dart';
import '../../features/voice/voice_input_session.dart';
import '../../features/voice/voice_stt_engine.dart';
import '../../models/image_memory_analysis.dart';
import '../../models/memory.dart';
import '../../providers/app_launch_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/person_avatar_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../services/ai_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/subscription_service.dart';
import '../../services/subscription_exceptions.dart';
import '../../services/home_widget_service.dart';
import '../../services/image_pipeline_service.dart';
import '../../services/location_permission_service.dart';
import '../../services/notification_service.dart';
import '../../utils/memory_video_paths.dart';
import '../../utils/memory_input_category.dart';
import '../../utils/memory_place_policy.dart';
import '../../utils/memory_place_cache.dart';
import '../../utils/photo_memo_format.dart';
import '../../utils/photo_memory_format.dart';
import '../../utils/voice_memory_format.dart';
import '../../services/local_memory_store.dart';
import '../../services/memory_entity_reenrich_service.dart';
import '../../services/recall_anchor_service.dart';
import '../../widgets/app_maturity_dialog.dart';
import '../../widgets/onboarding_sheet.dart';
import '../../features/legal/legal_consent_dialog.dart';
import '../../widgets/network_status_banner.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../features/story/relationship_story_screen.dart';
import '../../services/memory_pulse_service.dart';
import '../../services/memory_pulse_worker.dart';
import '../../utils/ocr_utils.dart';

Future<Position?> tryGetLocation() => LocationPermissionService.getCurrentPositionForMemoryCapture();

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isProcessing = false;
  late stt.SpeechToText _speech;
  VoiceSttEngine? _voiceEngine;
  bool _isListening = false;
  bool _speechInitialized = false;
  VoidCallback? _speechDoneHandler;
  final VoiceInputSession _captureVoiceSession = VoiceInputSession();
  final VoiceInputSession _searchVoiceSession = VoiceInputSession();
  ProactiveRecallService? _recallService;
  ProviderSubscription? _authSub;
  ProviderSubscription? _memorySub;
  ProviderSubscription? _launchSub;
  ProviderSubscription? _tabSub;

  String? _gpsPlaceOrCoords(Position? position, String? place) {
    if (place != null && place.trim().isNotEmpty) return place.trim();
    if (position == null) return null;
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  Future<void> _cachePlaceName(Position? position) async {
    if (position == null) return;
    final prefs = ref.read(preferencesProvider);
    final locale = ref.read(languageProvider).languageCode;
    final key = latLngCacheKey(position.latitude, position.longitude);

    final nameCache = {...ref.read(memoryPlaceNamesProvider)};
    if (!nameCache.containsKey(key)) {
      final name = await PlaceLookupService.resolvePlaceName(
        position.latitude,
        position.longitude,
        localeCode: locale,
      );
      if (name != null && name.trim().isNotEmpty) {
        nameCache[key] = name.trim();
        await saveMemoryPlaceNames(prefs, nameCache);
        ref.read(memoryPlaceNamesProvider.notifier).state = nameCache;
      }
    }

    final addressCache = {...ref.read(memoryPlaceFullAddressesProvider)};
    if (!addressCache.containsKey(key)) {
      final address = await PlaceLookupService.resolveFullAddress(
        position.latitude,
        position.longitude,
        localeCode: locale,
      );
      if (address != null && address.trim().isNotEmpty) {
        addressCache[key] = address.trim();
        await saveMemoryPlaceFullAddresses(prefs, addressCache);
        ref.read(memoryPlaceFullAddressesProvider.notifier).state = addressCache;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostCameraCapture();
      _setupRecallService();
      _setupSubscription();
      showOnboardingIfNeeded(context, ref);
      showLegalConsentIfNeeded(context, ref);
      maybeShowAppMaturityDialog(context, ref);
      HomeWidgetService.initialize((uri) {
        ref.read(appLaunchTargetProvider.notifier).state = appLaunchTargetFromUri(uri);
      });
      HomeWidgetService.refreshTheme(
        ref.read(seedColorProvider),
        themeMode: ref.read(themeModeProvider),
      );
      _handleLaunchTarget(ref.read(appLaunchTargetProvider));
      _wireNotificationTap();
      _maybeDeliverMemoryPulse();
      _maybeShowGraphReenrichNotice();
      if (ref.read(contactPersonAvatarsEnabledProvider)) {
        ref.read(personAvatarCacheProvider.notifier).reload();
      }
    });
    _launchSub = ref.listenManual(appLaunchTargetProvider, (prev, next) {
      if (next != AppLaunchTarget.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunchTarget(next));
      }
    });
    if (AppEnv.isConfigured) {
      _authSub = ref.listenManual(authSessionProvider, (prev, next) {
        final session = next.asData?.value;
        if (session == null && next.isLoading) return;
        Future.microtask(() async {
          if (session != null) {
            await SubscriptionService.instance.syncAfterLogin(session.user.id);
          } else {
            await SubscriptionService.instance.syncAfterLogout();
          }
          if (mounted) {
            ref.read(memoryListProvider.notifier).reload();
          }
        });
      });
    }
    _tabSub = ref.listenManual(mainNavigationTabProvider, (prev, next) {
      if (mounted && next != _currentIndex) {
        setState(() => _currentIndex = next);
      }
    });
  }

  void _maybeShowGraphReenrichNotice() {
    final prefs = ref.read(preferencesProvider);
    final count = readGraphReenrichPendingCount(prefs);
    if (count <= 0 || !mounted) return;
    clearGraphReenrichPendingNotice(prefs);
    final t = ref.read(translationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t['graph_reenrich_done']!.replaceAll('{count}', '$count')),
      ),
    );
  }

  void _setupSubscription() {
    SubscriptionService.instance.setListener((status) {
      ref.read(subscriptionStatusProvider.notifier).state = status;
    });
    Future.microtask(() async {
      await SubscriptionService.instance.initialize();
      if (!AppEnv.isConfigured) {
        await SubscriptionService.instance.refreshFromSupabase();
        return;
      }
      final session = ref.read(authSessionProvider).asData?.value;
      if (session != null) {
        await SubscriptionService.instance.syncAfterLogin(session.user.id);
      } else {
        await SubscriptionService.instance.refreshFromSupabase();
      }
    });
  }

  void _setupRecallService() {
    final prefs = ref.read(preferencesProvider);
    if (!ref.read(proactiveRecallEnabledProvider)) {
      _recallService?.stop();
      BackgroundRecallWorker.cancel();
      return;
    }
    BackgroundRecallWorker.register();
    Future.microtask(LocationPermissionService.requestBackgroundLocationForRecall);
    _recallService = ProactiveRecallService(prefs)..start();
    _recallService!.updateMemories(ref.read(memoryListProvider));
    _memorySub = ref.listenManual(memoryListProvider, (prev, next) {
      _recallService?.updateMemories(next);
    });
  }

  void _maybeDeliverMemoryPulse() {
    final prefs = ref.read(preferencesProvider);
    final memories = ref.read(memoryListProvider);
    Future.microtask(() => MemoryPulseWorker.maybeDeliverInForeground(prefs, memories));
  }

  void _wireNotificationTap() {
    NotificationService.instance.onNotificationTapped = (payload) {
      if (!mounted) return;
      if (payload.startsWith('pulse:')) {
        parsePulsePayload(payload, onParsed: (kind, memoryId, entity) {
          if (kind == MemoryPulseKind.personSpotlight && entity != null && entity.isNotEmpty) {
            setState(() => _currentIndex = 3);
            ref.read(mainNavigationTabProvider.notifier).state = 3;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              launchEntityHighlight(context: context, ref: ref, entityLabel: entity);
            });
            return;
          }
          if (memoryId != null && memoryId.isNotEmpty) {
            final memories = ref.read(memoryListProvider);
            final match = memories.where((m) => m.id == memoryId);
            if (match.isEmpty) return;
            final memory = match.first;
            final imagePaths = ref.read(memoryImagePathsProvider);
            setState(() => _currentIndex = 3);
            ref.read(mainNavigationTabProvider.notifier).state = 3;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showMemoryDetailSheet(
                context,
                memory,
                imagePaths: imagePaths,
                options: MemoryDetailPresets.replayShared,
              );
            });
          }
        });
        return;
      }
      final memories = ref.read(memoryListProvider);
      final matches = memories.where((m) => m.id == payload);
      if (matches.isEmpty) return;
      final memory = matches.first;
      final imagePaths = ref.read(memoryImagePathsProvider);
      final videoPaths = ref.read(memoryVideoPathsProvider);
      setState(() => _currentIndex = 0);
      ref.read(mainNavigationTabProvider.notifier).state = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showMemoryDetailSheet(
          context,
          memory,
          imagePaths: imagePaths,
          options: MemoryDetailPresets.graphWithVideo(
            hasVideo: memoryHasVideo(memory.id, videoPaths),
          ),
        );
      });
    };
  }

  void _wireRecallNotificationTap() => _wireNotificationTap();

  @override
  void dispose() {
    _authSub?.close();
    _memorySub?.close();
    _launchSub?.close();
    _tabSub?.close();
    _recallService?.stop();
    _speechDoneHandler = null;
    _voiceEngine?.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _recoverLostCameraCapture() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty || !mounted) return;
      if (response.exception != null) {
        debugPrint('Lost camera data: ${response.exception}');
        return;
      }
      final file = response.file;
      if (file != null) await _processCameraImage(file);
    } catch (e) {
      debugPrint('retrieveLostData error: $e');
    }
  }

  Future<bool> _ensureVoiceInputReady() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;

    _voiceEngine = VoiceSttEngineResolver.resolve(_speech);
    final ready = await _voiceEngine!.initialize(
      onAutoRestart: () => _speechDoneHandler?.call(),
    );
    _speechInitialized = ready;
    return ready;
  }

  Future<String> _resolveSpeechLocaleId() async {
    final locale = ref.read(languageProvider);
    final locales = await _speech.locales();
    for (final item in locales) {
      if (item.localeId.startsWith(locale.languageCode)) return item.localeId;
    }
    return locale.languageCode;
  }

  void _handleLaunchTarget(AppLaunchTarget target) {
    if (!mounted || target == AppLaunchTarget.none) return;
    ref.read(appLaunchTargetProvider.notifier).state = AppLaunchTarget.none;
    final t = ref.read(translationsProvider);
    switch (target) {
      case AppLaunchTarget.capture:
        setState(() => _currentIndex = 0);
        ref.read(mainNavigationTabProvider.notifier).state = 0;
        _showCaptureDialog(context, ref, t);
      case AppLaunchTarget.search:
        setState(() => _currentIndex = 1);
        ref.read(mainNavigationTabProvider.notifier).state = 1;
        _showSearchVoiceDialog(context, ref, t);
      case AppLaunchTarget.open:
        setState(() => _currentIndex = 0);
        ref.read(mainNavigationTabProvider.notifier).state = 0;
      case AppLaunchTarget.graph:
        setState(() => _currentIndex = 2);
        ref.read(mainNavigationTabProvider.notifier).state = 2;
      case AppLaunchTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final graphLandscapeImmersive =
        _currentIndex == 2 && MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: graphLandscapeImmersive
          ? null
          : AppBar(
        title: Text(switch (_currentIndex) {
          0 => t['memory_stream']!,
          1 => t['memory_engine']!,
          2 => t['rel_graph']!,
          _ => t['replay']!,
        }),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () {
              final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = nextMode;
              saveThemeMode(ref.read(preferencesProvider), nextMode);
              HomeWidgetService.refreshTheme(
                ref.read(seedColorProvider),
                themeMode: nextMode,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!graphLandscapeImmersive) const OfflineBanner(),
          Expanded(
            child: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              MemoryTimeline(onCaptureTap: () => _showCaptureDialog(context, ref, t)),
              const CognitiveSearchScreen(),
              const RelationshipGraphScreen(),
              const ReplayScreen(),
            ],
          ),
          if (_isProcessing) Container(color: Colors.black26, child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(t['processing']!)])))))
        ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: graphLandscapeImmersive
          ? null
          : NavigationBar(
        height: 78,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          ref.read(mainNavigationTabProvider.notifier).state = i;
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.auto_awesome_motion_rounded), label: t['stream']!),
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: t['search']!),
          NavigationDestination(icon: const Icon(Icons.hub_outlined), label: t['graph']!),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: t['replay']!),
        ],
      ),
      floatingActionButton: graphLandscapeImmersive || _currentIndex == 3
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentIndex == 0) FloatingActionButton.small(onPressed: () => _pickImageAndProcess(ref), heroTag: 'camera_btn', child: const Icon(Icons.camera_alt_rounded)),
                if (_currentIndex == 0) const SizedBox(height: 12),
                FloatingActionButton(
                  onPressed: () => _currentIndex == 1
                      ? _showSearchVoiceDialog(context, ref, t)
                      : _showCaptureDialog(context, ref, t),
                  heroTag: 'mic_btn',
                  backgroundColor: _isListening ? Colors.redAccent : (_currentIndex == 1 ? Colors.blueAccent : null),
                  child: Icon(_isListening ? Icons.stop_rounded : (_currentIndex == 1 ? Icons.search_rounded : Icons.mic_rounded)),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showSearchVoiceDialog(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    final text = await _showVoiceInputDialog(
      context: context,
      t: t,
      session: _searchVoiceSession,
      title: t['search_voice_title']!,
      hint: t['search_voice_hint']!,
      confirmLabel: t['search_action']!,
    );
    if (!mounted || text == null || text.isEmpty) return;
    _searchVoiceSession.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(searchQueryProvider.notifier).state = text;
    });
  }

  void _showCaptureDialog(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    final categoryId = await showMemoryCategorySheet(context, ref);
    if (!mounted || categoryId == null) return;

    final text = await _showVoiceInputDialog(
      context: context,
      t: t,
      session: _captureVoiceSession,
      title: t['capture_title']!,
      hint: t['capture_hint']!,
      confirmLabel: t['save']!,
      maxLines: 5,
    );
    if (!mounted || text == null || text.isEmpty) return;
    final inputCategory = memoryInputCategoryById(categoryId);
    await _processAndSaveMemory(text, ref, type: 'voice', inputCategory: inputCategory);
    _captureVoiceSession.clear();
  }

  Future<String?> _showVoiceInputDialog({
    required BuildContext context,
    required Map<String, String> t,
    required VoiceInputSession session,
    required String title,
    required String hint,
    required String confirmLabel,
    int maxLines = 3,
  }) async {
    if (!await _ensureVoiceInputReady()) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['mic_error']!)));
      return null;
    }

    final localeId = await _resolveSpeechLocaleId();
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => VoiceInputDialog(
        engine: _voiceEngine!,
        localeId: localeId,
        session: session,
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        cancelLabel: t['cancel']!,
        listeningLabel: t['listening']!,
        voiceModeLabel: t['input_mode_voice']!,
        keyboardModeLabel: t['input_mode_keyboard']!,
        maxLines: maxLines,
        onListeningChanged: (listening) {
          if (mounted) setState(() => _isListening = listening);
        },
        onBindSpeechDone: (handler) => _speechDoneHandler = handler,
        onUnbindSpeechDone: (handler) {
          if (identical(_speechDoneHandler, handler)) _speechDoneHandler = null;
        },
      ),
    );
  }

  Future<bool> _ensureCameraPermission(Map<String, String> t) async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t['camera_denied']!),
          action: SnackBarAction(label: t['settings']!, onPressed: openAppSettings),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['camera_denied']!)));
    }
    return false;
  }

  Future<void> _saveImageMemoryFromAnalysis(
    ImageMemoryAnalysis analysis,
    WidgetRef ref, {
    required Uint8List jpegBytes,
    Position? position,
    String userMemo = '',
    MemoryInputCategory? inputCategory,
  }) async {
    if (!hasPhotoMemoryPayload(analysis) && resolveImageMemoryContent(analysis).isEmpty) return;

    if (!mounted) return;

    final prefs = ref.read(preferencesProvider);
    var localOnly = isLocalOnlyMode(
      prefs,
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    );
    if (!localOnly && !AppEnv.isConfigured) {
      localOnly = true;
    }

    final locale = ref.read(languageProvider).languageCode;
    final gpsPlaceResolved = position != null
        ? await PlaceLookupService.resolvePlaceName(
            position.latitude,
            position.longitude,
            localeCode: locale,
          )
        : null;
    final gpsPlace = _gpsPlaceOrCoords(position, gpsPlaceResolved);

    var fields = buildPhotoMemoryFieldsFromVision(
      analysis: analysis,
      capturedAt: DateTime.now(),
      localeCode: locale,
      gpsPlace: gpsPlace,
    );
    fields = enrichPhotoFieldsWithUserMemo(
      fields: fields,
      userMemo: userMemo,
      capturedAt: DateTime.now(),
      localeCode: locale,
      gpsPlace: gpsPlace,
    );
    if (inputCategory != null) {
      final applied = applyMemoryInputCategory(
        localeCode: locale,
        inputCategory: inputCategory,
        fallbackCategory: fields.category,
        fallbackSubCategory: fields.subCategory,
      );
      fields = PhotoMemoryFields(
        summary: fields.summary,
        content: fields.content,
        entities: fields.entities,
        category: applied.category,
        subCategory: applied.subCategory,
      );
    }

    if (!mounted) return;
    final saved = await savePhotoMemoryToStore(
      ref: ref,
      fields: fields,
      jpegBytes: jpegBytes,
      position: position,
      userMemo: userMemo,
      context: context,
      capturePlaceLabel: gpsPlace,
      localeCode: locale,
    );
      if (saved != null) {
        HapticFeedback.lightImpact();
        if (mounted) await showMemoryThreadSuggestions(context, ref, saved);
      } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
    }
  }

  Future<void> _saveLocalPhotoMemory(
    WidgetRef ref, {
    required Uint8List jpegBytes,
    String? ocrText,
    Position? position,
    String userMemo = '',
    MemoryInputCategory? inputCategory,
  }) async {
    final locale = ref.read(languageProvider).languageCode;
    final gpsPlaceResolved = position != null
        ? await PlaceLookupService.resolvePlaceName(
            position.latitude,
            position.longitude,
            localeCode: locale,
          )
        : null;
    final gpsPlace = _gpsPlaceOrCoords(position, gpsPlaceResolved);

    var fields = buildPhotoMemoryFieldsLocal(
      capturedAt: DateTime.now(),
      localeCode: locale,
      gpsPlace: gpsPlace,
      ocrText: ocrText,
    );
    fields = enrichPhotoFieldsWithUserMemo(
      fields: fields,
      userMemo: userMemo,
      capturedAt: DateTime.now(),
      localeCode: locale,
      gpsPlace: gpsPlace,
    );
    if (inputCategory != null) {
      final applied = applyMemoryInputCategory(
        localeCode: locale,
        inputCategory: inputCategory,
        fallbackCategory: fields.category,
        fallbackSubCategory: fields.subCategory,
      );
      fields = PhotoMemoryFields(
        summary: fields.summary,
        content: fields.content,
        entities: fields.entities,
        category: applied.category,
        subCategory: applied.subCategory,
      );
    }

    if (!mounted) return;
    final saved = await savePhotoMemoryToStore(
      ref: ref,
      fields: fields,
      jpegBytes: jpegBytes,
      position: position,
      userMemo: userMemo,
      context: context,
      capturePlaceLabel: gpsPlace,
      localeCode: locale,
    );
    if (saved != null) {
      HapticFeedback.lightImpact();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)),
      );
    }
  }

  Future<void> _processCameraImage(XFile image, {String userMemo = '', MemoryInputCategory? inputCategory}) async {
    final t = ref.read(translationsProvider);
    if (!mounted) return;

    // 카메라 앱 복귀 직후 Activity/메모리 안정화
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final engineMode = ref.read(ocrEngineModeProvider);
    final visionQuality = effectiveVisionQuality(engineMode, ref.read(ocrVisionQualityProvider));
    final maxSide = ocrMaxSideFor(engineMode, visionQuality);
    final jpegQuality = visionQuality == OcrVisionQuality.high ? 90 : 80;
    final useMlKit = engineMode == OcrEngineMode.hybrid && ref.read(onDeviceOcrProvider);

    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    try {
      final jpegBytes = await prepareOcrImageBytes(image, maxSide: maxSide, jpegQuality: jpegQuality);
      if (jpegBytes == null || jpegBytes.isEmpty) throw Exception('invalid image');

      final position = await tryGetLocation();
      await _cachePlaceName(position);
      final prefs = ref.read(preferencesProvider);
      final localOnly = isLocalOnlyMode(
        prefs,
        privacyMode: ref.read(privacyLocalModeProvider),
        guestMode: ref.read(guestModeProvider),
      );
      final privacyLocal = ref.read(privacyLocalModeProvider);

      if (localOnly || privacyLocal) {
        String? ocrText;
        if (useMlKit) {
          try {
            final mlKitBytes = await prepareOcrImageBytes(image, maxSide: mlKitMaxSide, jpegQuality: 70);
            final ocrPath = mlKitBytes != null ? await writeTempJpeg(mlKitBytes) : null;
            if (ocrPath != null) {
              ocrText = await recognizeTextWithMlKit(ocrPath);
            }
          } catch (e, stack) {
            debugPrint('Privacy photo OCR failed: $e\n$stack');
          }
        }
        await _saveLocalPhotoMemory(
          ref,
          jpegBytes: jpegBytes,
          ocrText: ocrText,
          position: position,
          userMemo: userMemo,
          inputCategory: inputCategory,
        );
        return;
      }

      if (!mounted) return;
      var useCloudVision = await ensureCloudAccessForAction(
        context,
        ref,
        reasonKey: 'pro_reason_vision',
      );
      if (!useCloudVision) {
        await _saveLocalPhotoMemory(
          ref,
          jpegBytes: jpegBytes,
          position: position,
          userMemo: userMemo,
          inputCategory: inputCategory,
        );
        return;
      }

      if (useMlKit) {
        final mlKitBytes = await prepareOcrImageBytes(image, maxSide: mlKitMaxSide, jpegQuality: 70);
        final ocrPath = mlKitBytes != null ? await writeTempJpeg(mlKitBytes) : null;
        if (ocrPath != null) {
          try {
            final mlKitText = await recognizeTextWithMlKit(ocrPath);
            if (mlKitText.isNotEmpty && !isJunkOcrMetaResponse(mlKitText)) {
              debugPrint('ML Kit OCR success: ${mlKitText.length} chars');
              if (!mounted) return;
              await _saveLocalPhotoMemory(
                ref,
                jpegBytes: jpegBytes,
                ocrText: mlKitText,
                position: position,
                userMemo: userMemo,
                inputCategory: inputCategory,
              );
              return;
            }
          } catch (e, stack) {
            debugPrint('ML Kit OCR failed, falling back to Vision: $e\n$stack');
          }
        }
      }

      final locale = ref.read(languageProvider);
      final analysis = await analyzeImageMemoryViaOpenAI(
        jpegBytes: jpegBytes,
        localeCode: locale.languageCode,
        visionQuality: visionQuality,
      );

      debugPrint(
        'Vision analysis: engine=$engineMode quality=$visionQuality '
        'text=${analysis.extractedText.length} chars place=${analysis.placeName}',
      );

      if (!hasPhotoMemoryPayload(analysis) && resolveImageMemoryContent(analysis).isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['ocr_empty']!)));
        }
        return;
      }

      await _saveImageMemoryFromAnalysis(
        analysis,
        ref,
        jpegBytes: jpegBytes,
        position: position,
        userMemo: userMemo,
        inputCategory: inputCategory,
      );
    } catch (e, stack) {
      debugPrint("OCR pipeline error: $e\n$stack");
      if (mounted) {
        final msg = e is SubscriptionRequiredException
            ? t['pro_reason_vision']!
            : e is QuotaExceededException
                ? t['pro_quota_exceeded']!
                : t['ocr_error']!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImageAndProcess(WidgetRef ref) async {
    final t = ref.read(translationsProvider);
    final categoryId = await showMemoryCategorySheet(context, ref);
    if (categoryId == null || !mounted) return;
    final inputCategory = memoryInputCategoryById(categoryId);

    final source = await showPhotoSourceSheet(context, t);
    if (source == null || !mounted) return;
    if (source == ImageSource.camera && !await _ensureCameraPermission(t)) return;

    final engineMode = ref.read(ocrEngineModeProvider);
    final visionQuality = effectiveVisionQuality(engineMode, ref.read(ocrVisionQualityProvider));
    final pickMaxSide = cameraPickMaxSideFor(engineMode, visionQuality);

    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: source,
        maxWidth: pickMaxSide.toDouble(),
        maxHeight: pickMaxSide.toDouble(),
        imageQuality: visionQuality == OcrVisionQuality.high ? 84 : 76,
        requestFullMetadata: false,
      );
    } catch (e, stack) {
      debugPrint("Image pick error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['ocr_error']!)));
      }
      return;
    }

    if (image == null || !mounted) return;
    final userMemo = await showPhotoMemoDialog(context, t) ?? '';
    if (!mounted) return;
    await _processCameraImage(image, userMemo: userMemo, inputCategory: inputCategory);
  }

  Future<void> _processAndSaveMemory(
    String text,
    WidgetRef ref, {
    required String type,
    bool manageProcessingOverlay = true,
    Uint8List? imageBytesForThumbnail,
    MemoryInputCategory? inputCategory,
    bool forceLocal = false,
  }) async {
    if (!mounted) return;

    final prefs = ref.read(preferencesProvider);
    var useCloud = !forceLocal &&
        !isLocalOnlyMode(
          prefs,
          privacyMode: ref.read(privacyLocalModeProvider),
          guestMode: ref.read(guestModeProvider),
        );
    if (useCloud && !AppEnv.isConfigured) {
      useCloud = false;
    }
    if (!mounted) return;
    if (useCloud) {
      useCloud = await ensureCloudAccessForAction(
        context,
        ref,
        reasonKey: 'pro_reason_save',
      );
    }

    if (manageProcessingOverlay) setState(() => _isProcessing = true);
    try {
      final position = await tryGetLocation();
      await _cachePlaceName(position);
      final locale = ref.read(languageProvider).languageCode;
      final gpsPlaceResolved = position != null
          ? await PlaceLookupService.resolvePlaceName(
              position.latitude,
              position.longitude,
              localeCode: locale,
            )
          : null;
      final gpsPlace = _gpsPlaceOrCoords(position, gpsPlaceResolved);
      final persistGps = shouldPersistCaptureGpsOnSave(type: type, content: text, localeCode: locale);
      final capturedAt = DateTime.now();
      final voiceFields = buildVoiceMemoryFields(
        speechText: text,
        capturedAt: capturedAt,
        localeCode: locale,
        gpsPlace: persistGps ? gpsPlace : null,
      );

      if (!useCloud) {
        final applied = applyMemoryInputCategory(
          localeCode: locale,
          inputCategory: inputCategory,
          fallbackCategory: voiceFields.category,
          fallbackSubCategory: voiceFields.subCategory,
        );
        var draft = Memory(
          id: "",
          content: text,
          summary: voiceFields.summary,
          entities: voiceFields.entities,
          createdAt: capturedAt,
          category: applied.category,
          subCategory: applied.subCategory,
          type: type,
          lat: persistGps ? position?.latitude : null,
          lng: persistGps ? position?.longitude : null,
        );
        draft = await resolveRecallAnchorForMemory(
          context,
          draft,
          localeCode: locale,
          capturePlaceLabel: gpsPlace,
          captureLat: position?.latitude,
          captureLng: position?.longitude,
        );
        if (!mounted) return;
        final saved = await ref.read(memoryListProvider.notifier).addMemory(draft);
        if (saved != null && type == 'image' && imageBytesForThumbnail != null) {
          await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: imageBytesForThumbnail);
        }
        if (saved != null) {
          HapticFeedback.lightImpact();
        } else if (mounted && saved == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
        }
        return;
      }

      final localeObj = ref.read(languageProvider);
      final langName = languageNameForLocale(localeObj);
      final subCategoryExamples = localeObj.languageCode == 'ko'
          ? "'절친', '영어 회화', '고급 레스토랑'"
          : "'Best Friend', 'English Conversation', 'Expensive Restaurant'";

      final jsonText = await AiService.instance.chatJson(
        systemPrompt:
            "Classify this memory with extreme detail. Respond in $langName. Return JSON: {summary: string, entities: string[], category: 'Food'|'Social'|'Study'|'Work'|'Health'|'Travel'|'Finance'|'Other', sub_category: string}. summary must be ONE sentence capturing the core meaning and emotional significance of the memory (그날의 핵심 의미) — never metadata lists, dates, times, or comma-separated tags. Write summary, entities, and sub_category in $langName. Keep category as one of the English keys listed above. sub_category should be very specific (e.g. $subCategoryExamples). entities must be up to 6 short nouns (max 12 characters each) — people, places, activities, goals, emotions, brands, or concrete things only. Never include sentences or meta descriptions.",
        userPrompt: text,
      );
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final mergedFields = mergeVoiceFieldsWithAi(localFields: voiceFields, aiData: data);
      final applied = applyMemoryInputCategory(
        localeCode: locale,
        inputCategory: inputCategory,
        fallbackCategory: mergedFields.category,
        fallbackSubCategory: mergedFields.subCategory,
      );
      final embedding = await AiService.instance.createEmbedding(text);

      if (!mounted) return;
      var draft = Memory(
        id: "",
        content: text,
        summary: mergedFields.summary,
        entities: mergedFields.entities,
        createdAt: capturedAt,
        category: applied.category,
        subCategory: applied.subCategory,
        embedding: embedding,
        type: type,
        lat: persistGps ? position?.latitude : null,
        lng: persistGps ? position?.longitude : null,
      );
      draft = await resolveRecallAnchorForMemory(
        context,
        draft,
        localeCode: locale,
        capturePlaceLabel: gpsPlace,
        captureLat: position?.latitude,
        captureLng: position?.longitude,
      );
      if (!mounted) return;
      final saved = await ref.read(memoryListProvider.notifier).addMemory(draft);

      if (saved != null && type == 'image' && imageBytesForThumbnail != null) {
        await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: imageBytesForThumbnail);
      }
      if (saved != null) {
        HapticFeedback.lightImpact();
        if (mounted) {
          await showMemoryThreadSuggestions(context, ref, saved);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
      }
    } catch (e, stack) {
      debugPrint("AI/Save Error: $e\n$stack");
      if (useCloud && !forceLocal && mounted) {
        await _processAndSaveMemory(
          text,
          ref,
          type: type,
          manageProcessingOverlay: false,
          inputCategory: inputCategory,
          forceLocal: true,
        );
        return;
      }
      if (mounted) {
        final t = ref.read(translationsProvider);
        final msg = e is SubscriptionRequiredException
            ? t['pro_reason_save']!
            : e is QuotaExceededException
                ? t['pro_quota_exceeded']!
                : t['save_failed']!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (manageProcessingOverlay && mounted) setState(() => _isProcessing = false);
    }
  }
}
