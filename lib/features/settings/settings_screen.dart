import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ocr_config.dart';
import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../services/local_memory_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _ocrEngineHint(Map<String, String> t, OcrEngineMode mode) {
    switch (mode) {
      case OcrEngineMode.hybrid:
        return t['ocr_engine_hybrid_hint']!;
      case OcrEngineMode.lowCost:
        return t['ocr_engine_low_cost_hint']!;
      case OcrEngineMode.vision:
        return t['ocr_engine_vision_hint']!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed = ref.watch(seedColorProvider);
    final t = ref.watch(translationsProvider);
    final engineMode = ref.watch(ocrEngineModeProvider);
    final visionQuality = ref.watch(ocrVisionQualityProvider);
    final qualityLocked = engineMode == OcrEngineMode.lowCost;
    final themeColors = [Colors.deepPurple, Colors.blue, Colors.green, Colors.indigo, Colors.pink, Colors.orange, Colors.blueGrey];
    return Scaffold(
      appBar: AppBar(title: Text(t['settings']!)),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.help_outline_rounded), title: Text(t['how_to_use']!), onTap: () => _showUsageGuide(context, t)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(t['ocr_engine']!),
            subtitle: Text(_ocrEngineHint(t, engineMode)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<OcrEngineMode>(
              segments: [
                ButtonSegment(value: OcrEngineMode.hybrid, label: Text(t['ocr_engine_hybrid']!, style: const TextStyle(fontSize: 11))),
                ButtonSegment(value: OcrEngineMode.lowCost, label: Text(t['ocr_engine_low_cost']!, style: const TextStyle(fontSize: 11))),
                ButtonSegment(value: OcrEngineMode.vision, label: Text(t['ocr_engine_vision']!, style: const TextStyle(fontSize: 11))),
              ],
              selected: {engineMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                ref.read(ocrEngineModeProvider.notifier).state = mode;
                saveOcrEngineMode(ref.read(preferencesProvider), mode);
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.phone_android_outlined),
            title: Text(t['on_device_ocr']!),
            subtitle: Text(t['on_device_ocr_hint']!),
            value: ref.watch(onDeviceOcrProvider),
            onChanged: engineMode == OcrEngineMode.hybrid
                ? (enabled) {
                    ref.read(onDeviceOcrProvider.notifier).state = enabled;
                    saveOnDeviceOcrEnabled(ref.read(preferencesProvider), enabled);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text(t['ocr_vision_quality']!),
            subtitle: Text(
              qualityLocked ? t['ocr_quality_locked_low']! : t['ocr_quality_hybrid_hint']!,
            ),
            trailing: qualityLocked
                ? Text(t['ocr_quality_low']!, style: Theme.of(context).textTheme.bodyMedium)
                : DropdownButton<OcrVisionQuality>(
                    value: visionQuality,
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(ocrVisionQualityProvider.notifier).state = value;
                      saveOcrVisionQuality(ref.read(preferencesProvider), value);
                    },
                    items: [
                      DropdownMenuItem(value: OcrVisionQuality.low, child: Text(t['ocr_quality_low']!)),
                      DropdownMenuItem(value: OcrVisionQuality.high, child: Text(t['ocr_quality_high']!)),
                    ],
                  ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(t['privacy_local_mode']!),
            subtitle: Text(t['privacy_local_mode_hint']!),
            value: ref.watch(privacyLocalModeProvider),
            onChanged: (enabled) {
              ref.read(privacyLocalModeProvider.notifier).state = enabled;
              writePrivacyLocalMode(ref.read(preferencesProvider), enabled);
            },
          ),
          const Divider(),
          ListTile(title: Text(t['theme_color']!)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 12, children: themeColors.map((color) => GestureDetector(onTap: () => ref.read(seedColorProvider.notifier).state = color, child: CircleAvatar(backgroundColor: color, radius: 20, child: currentSeed == color ? const Icon(Icons.check, color: Colors.white) : null))).toList())),
          ListTile(title: Text(t['language']!), trailing: DropdownButton<Locale>(value: ref.watch(languageProvider), onChanged: (l) => ref.read(languageProvider.notifier).state = l!, items: const [DropdownMenuItem(value: Locale('ko'), child: Text("한국어")), DropdownMenuItem(value: Locale('en'), child: Text("English"))])),
          const Divider(),
          ref.watch(packageInfoProvider).when(
            data: (info) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t['app_version']!),
              subtitle: Text('${info.version} (${info.buildNumber})'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t['privacy_policy']!),
            onTap: () => _showPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t['logout']!),
            onTap: () async {
              final prefs = ref.read(preferencesProvider);
              await writeGuestMode(prefs, false);
              ref.read(guestModeProvider.notifier).state = false;
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) async {
    final text = await rootBundle.loadString('docs/PRIVACY_POLICY.md');
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Text('개인정보 처리방침', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showUsageGuide(BuildContext context, Map<String, String> t) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.9, expand: false, builder: (context, scrollController) => Padding(padding: const EdgeInsets.all(24), child: ListView(controller: scrollController, children: [Text(t['guide_title']!, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 24), _buildGuideItem(context, Icons.auto_awesome, t['guide_f1']!), _buildGuideItem(context, Icons.chat_bubble_outline, t['guide_f2']!), _buildGuideItem(context, Icons.hub_outlined, t['guide_f3']!), _buildGuideItem(context, Icons.location_on_outlined, t['guide_f4']!), _buildGuideItem(context, Icons.camera_alt_outlined, t['guide_f5']!), const SizedBox(height: 40), ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => Navigator.pop(context), child: Text(t['got_it']!))]))));
  }

  Widget _buildGuideItem(BuildContext context, IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28), const SizedBox(width: 16), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5)))]));
  }
}
