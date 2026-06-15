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
import '../../features/memory/memory_thread_ui.dart';
import '../../features/replay/replay_screen.dart';
import '../../features/search/cognitive_search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/timeline/memory_timeline.dart';
import '../../features/voice/voice_input_dialog.dart';
import '../../models/image_memory_analysis.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/ai_service.dart';
import '../../services/image_pipeline_service.dart';
import '../../services/proactive_recall_service.dart';
import '../../widgets/onboarding_sheet.dart';
import '../../widgets/network_status_banner.dart';
import '../../utils/ocr_utils.dart';

Future<Position?> tryGetLocation() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  } catch (_) {
    return null;
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isProcessing = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;
  VoidCallback? _speechDoneHandler;
  ProactiveRecallService? _recallService;
  ProviderSubscription? _authSub;
  ProviderSubscription? _memorySub;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostCameraCapture();
      _setupRecallService();
      showOnboardingIfNeeded(context, ref);
    });
    _authSub = ref.listenManual(authSessionProvider, (prev, next) {
      next.whenData((session) {
        if (session != null) {
          ref.read(memoryListProvider.notifier).reload();
        }
      });
    });
  }

  void _setupRecallService() {
    final prefs = ref.read(preferencesProvider);
    _recallService = ProactiveRecallService(prefs)..start();
    _recallService!.updateMemories(ref.read(memoryListProvider));
    _memorySub = ref.listenManual(memoryListProvider, (prev, next) {
      _recallService?.updateMemories(next);
    });
  }

  @override
  void dispose() {
    _authSub?.close();
    _memorySub?.close();
    _recallService?.stop();
    _speechDoneHandler = null;
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

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechInitialized) return true;
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') _speechDoneHandler?.call();
      },
    );
    return _speechInitialized;
  }

  Future<String> _resolveSpeechLocaleId() async {
    final locale = ref.read(languageProvider);
    final locales = await _speech.locales();
    for (final item in locales) {
      if (item.localeId.startsWith(locale.languageCode)) return item.localeId;
    }
    return locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
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
          const OfflineBanner(),
          Expanded(
            child: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const MemoryTimeline(),
              const CognitiveSearchScreen(),
              const RelationshipGraphScreen(),
              ReplayTimelineView(
                memories: ref.watch(memoryListProvider),
                imagePaths: ref.watch(memoryImagePathsProvider),
                localeCode: ref.watch(languageProvider).languageCode,
                emptyLabel: t['no_memories']!,
              ),
            ],
          ),
          if (_isProcessing) Container(color: Colors.black26, child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(t['processing']!)])))))
        ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.auto_awesome_motion_rounded), label: t['stream']!),
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: t['search']!),
          NavigationDestination(icon: const Icon(Icons.hub_outlined), label: t['graph']!),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: t['replay']!),
        ],
      ),
      floatingActionButton: _currentIndex > 1
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentIndex == 0) FloatingActionButton.small(onPressed: () => _pickImageAndProcess(ref), heroTag: 'camera_btn', child: const Icon(Icons.camera_alt_rounded)),
                if (_currentIndex == 0) const SizedBox(height: 12),
                FloatingActionButton.large(
                  onPressed: () => _currentIndex == 0 ? _showCaptureDialog(context, ref, t) : _showSearchVoiceDialog(context, ref, t),
                  heroTag: 'mic_btn',
                  backgroundColor: _isListening ? Colors.redAccent : (_currentIndex != 0 ? Colors.blueAccent : null),
                  child: Icon(_isListening ? Icons.stop_rounded : (_currentIndex == 0 ? Icons.mic_rounded : Icons.search_rounded)),
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
      title: t['search_voice_title']!,
      hint: t['search_voice_hint']!,
      confirmLabel: t['search_action']!,
    );
    if (!mounted || text == null || text.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(searchQueryProvider.notifier).state = text;
    });
  }

  void _showCaptureDialog(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    final text = await _showVoiceInputDialog(
      context: context,
      t: t,
      title: t['capture_title']!,
      hint: t['capture_hint']!,
      confirmLabel: t['save']!,
      maxLines: 5,
    );
    if (!mounted || text == null || text.isEmpty) return;
    await _processAndSaveMemory(text, ref, type: "voice");
  }

  Future<String?> _showVoiceInputDialog({
    required BuildContext context,
    required Map<String, String> t,
    required String title,
    required String hint,
    required String confirmLabel,
    int maxLines = 3,
  }) async {
    if (!await _ensureSpeechInitialized()) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['mic_error']!)));
      return null;
    }

    final localeId = await _resolveSpeechLocaleId();
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => VoiceInputDialog(
        speech: _speech,
        localeId: localeId,
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        cancelLabel: t['cancel']!,
        listeningLabel: t['listening']!,
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
  }) async {
    final content = resolveImageMemoryContent(analysis);
    if (content.isEmpty) return;

    final summary = !isJunkOcrMetaResponse(analysis.summary) && analysis.summary.isNotEmpty
        ? analysis.summary
        : (analysis.subCategory.isNotEmpty && !isJunkEntityOrKeyword(analysis.subCategory)
            ? analysis.subCategory
            : (content.length > 60 ? '${content.substring(0, 57)}...' : content));

    if (!AppEnv.isConfigured || !mounted) return;

    final privacy = ref.read(privacyLocalModeProvider);
    final embedding = privacy ? null : await AiService.instance.createEmbedding(content);

    final position = await tryGetLocation();

    if (!mounted) return;
    final saved = await ref.read(memoryListProvider.notifier).addMemory(Memory(
      id: "",
      content: content,
      summary: summary,
      entities: analysis.entities,
      createdAt: DateTime.now(),
      category: analysis.category,
      subCategory: analysis.subCategory,
      embedding: embedding,
      type: "image",
      lat: position?.latitude,
      lng: position?.longitude,
    ));
    if (saved != null) {
      HapticFeedback.lightImpact();
      await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: jpegBytes);
      if (mounted && saved.embedding != null) await showMemoryThreadSuggestions(context, ref, saved);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
    }
  }

  Future<void> _processCameraImage(XFile image) async {
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

      if (ref.read(privacyLocalModeProvider)) {
        final position = await tryGetLocation();
        final label = ref.read(languageProvider).languageCode == 'ko' ? '기기에 저장된 사진' : 'Photo on device';
        final saved = await ref.read(memoryListProvider.notifier).addMemory(Memory(
          id: "",
          content: label,
          summary: label,
          entities: const [],
          createdAt: DateTime.now(),
          type: "image",
          lat: position?.latitude,
          lng: position?.longitude,
        ));
        if (saved != null) {
          HapticFeedback.lightImpact();
          await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: jpegBytes);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['save_failed']!)));
        }
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
              await _processAndSaveMemory(
                mlKitText,
                ref,
                type: "image",
                manageProcessingOverlay: false,
                imageBytesForThumbnail: jpegBytes,
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
        'text=${analysis.extractedText.length} chars summary=${analysis.summary}',
      );

      if (resolveImageMemoryContent(analysis).isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['ocr_empty']!)));
        }
        return;
      }

      await _saveImageMemoryFromAnalysis(analysis, ref, jpegBytes: jpegBytes);
    } catch (e, stack) {
      debugPrint("OCR pipeline error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['ocr_error']!)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImageAndProcess(WidgetRef ref) async {
    final t = ref.read(translationsProvider);
    if (!await _ensureCameraPermission(t)) return;

    final engineMode = ref.read(ocrEngineModeProvider);
    final visionQuality = effectiveVisionQuality(engineMode, ref.read(ocrVisionQualityProvider));
    final pickMaxSide = cameraPickMaxSideFor(engineMode, visionQuality);

    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: pickMaxSide.toDouble(),
        maxHeight: pickMaxSide.toDouble(),
        imageQuality: visionQuality == OcrVisionQuality.high ? 92 : 85,
        requestFullMetadata: false,
      );
    } catch (e, stack) {
      debugPrint("Camera pick error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['ocr_error']!)));
      }
      return;
    }

    if (image == null || !mounted) return;
    await _processCameraImage(image);
  }

  Future<void> _processAndSaveMemory(
    String text,
    WidgetRef ref, {
    required String type,
    bool manageProcessingOverlay = true,
    Uint8List? imageBytesForThumbnail,
  }) async {
    if (!AppEnv.isConfigured || !mounted) return;
    if (manageProcessingOverlay) setState(() => _isProcessing = true);
    try {
      final privacy = ref.read(privacyLocalModeProvider);
      final position = await tryGetLocation();

      if (privacy) {
        final summary = text.length > 80 ? '${text.substring(0, 77)}...' : text;
        final saved = await ref.read(memoryListProvider.notifier).addMemory(Memory(
          id: "",
          content: text,
          summary: summary,
          entities: const [],
          createdAt: DateTime.now(),
          type: type,
          lat: position?.latitude,
          lng: position?.longitude,
        ));
        if (saved != null && type == 'image' && imageBytesForThumbnail != null) {
          await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: imageBytesForThumbnail);
        }
        if (saved != null) HapticFeedback.lightImpact();
        else if (mounted && saved == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
        }
        return;
      }

      final locale = ref.read(languageProvider);
      final langName = languageNameForLocale(locale);
      final subCategoryExamples = locale.languageCode == 'ko'
          ? "'절친', '영어 회화', '고급 레스토랑'"
          : "'Best Friend', 'English Conversation', 'Expensive Restaurant'";

      final jsonText = await AiService.instance.chatJson(
        systemPrompt:
            "Classify this memory with extreme detail. Respond in $langName. Return JSON: {summary: string, entities: string[], category: 'Food'|'Social'|'Study'|'Work'|'Health'|'Travel'|'Finance'|'Other', sub_category: string}. Write summary, entities, and sub_category in $langName. Keep category as one of the English keys listed above. sub_category should be very specific (e.g. $subCategoryExamples). entities must be up to 6 short nouns (max 12 characters each) — people, places, brands, or concrete things only. Never include sentences or meta descriptions.",
        userPrompt: text,
      );
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final embedding = await AiService.instance.createEmbedding(text);

      if (!mounted) return;
      final saved = await ref.read(memoryListProvider.notifier).addMemory(Memory(
        id: "",
        content: text,
        summary: data['summary'] ?? "Memory",
        entities: sanitizeEntities(List<String>.from(data['entities'] ?? [])),
        createdAt: DateTime.now(),
        category: data['category'] ?? "Other",
        subCategory: data['sub_category'] ?? "",
        embedding: embedding,
        type: type,
        lat: position?.latitude,
        lng: position?.longitude,
      ));

      if (saved != null && type == 'image' && imageBytesForThumbnail != null) {
        await persistMemoryThumbnail(ref: ref, memoryId: saved.id, jpegBytes: imageBytesForThumbnail);
      }
      if (saved != null) {
        HapticFeedback.lightImpact();
        if (mounted && saved.embedding != null) {
          await showMemoryThreadSuggestions(context, ref, saved);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
      }
    } catch (e) {
      debugPrint("AI/Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(translationsProvider)['save_failed']!)));
      }
    } finally {
      if (manageProcessingOverlay && mounted) setState(() => _isProcessing = false);
    }
  }
}
