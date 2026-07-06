import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/app_maturity.dart';
import '../../core/app_urls.dart';
import '../../core/env.dart';
import '../../core/ocr_config.dart';
import '../../core/prefs.dart';
import '../../core/replay_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/person_avatar_provider.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/subscription_providers.dart';
import '../../services/background_recall_worker.dart';
import '../../services/memory_pulse_worker.dart';
import '../../services/graph_cleanup_service.dart';
import '../../services/location_permission_service.dart';
import '../../services/local_memory_store.dart';
import '../../services/account_deletion_service.dart';
import '../../services/memory_backup_service.dart';
import '../../services/memory_cloud_sync_service.dart';
import '../../services/home_widget_service.dart';
import '../../features/legal/legal_consent_dialog.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/subscription/paywall_sheet.dart';
import '../../features/subscription/pro_saas_dashboard.dart';
import '../../features/trust/trust_dashboard_screen.dart';
import 'location_permission_tile.dart';
import 'settings_plan_cards.dart';
import 'settings_section_header.dart';
import 'user_guide_pdf_screen.dart';

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

  String _replayModeHint(Map<String, String> t, ReplayViewMode mode) {
    switch (mode) {
      case ReplayViewMode.shared:
        return t['replay_mode_shared_hint']!;
      case ReplayViewMode.light:
        return t['replay_mode_light_hint']!;
      case ReplayViewMode.gallery:
        return t['replay_mode_gallery_hint']!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed = ref.watch(seedColorProvider);
    final t = ref.watch(translationsProvider);
    final engineMode = ref.watch(ocrEngineModeProvider);
    final visionQuality = ref.watch(ocrVisionQualityProvider);
    final qualityLocked = engineMode == OcrEngineMode.lowCost;
    final localOnly = isLocalOnlyMode(
      ref.watch(preferencesProvider),
      privacyMode: ref.watch(privacyLocalModeProvider),
      guestMode: ref.watch(guestModeProvider),
    );
    final graphAiLocked = localOnly ||
        (requiresProCloudForGraphAi && (!AppEnv.isConfigured || !ref.watch(hasProEntitlementProvider)));
    final themeColors = [
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.pink,
      Colors.red,
      Colors.blueGrey,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t['settings']!)),
      body: ListView(
        children: [
          SettingsSectionHeader(
            title: t['settings_sec_plan']!,
            subtitle: t['settings_sec_plan_sub']!,
            icon: Icons.workspace_premium_outlined,
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(t['user_guide_title']!),
            subtitle: Text(t['user_guide_subtitle']!),
            onTap: () => _showUsageGuide(context, t),
          ),
          ListTile(
            leading: Icon(
              Icons.workspace_premium_rounded,
              color: ref.watch(hasProEntitlementProvider) ? Colors.amber.shade700 : null,
            ),
            title: Text(t['pro_plan']!),
            subtitle: Text(
              ref.watch(hasProEntitlementProvider) ? t['pro_plan_hint_active']! : t['pro_plan_hint_free']!,
            ),
            trailing: ref.watch(hasProEntitlementProvider)
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
            onTap: () => showProPaywall(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_rounded),
            title: Text(t['pro_saas_title']!),
            subtitle: Text(t['pro_saas_subtitle']!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProSaasDashboardScreen()),
            ),
          ),
          const SettingsPlanOverviewCard(),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_memory']!,
            icon: Icons.collections_outlined,
          ),
          ListTile(
            leading: const Icon(Icons.collections_outlined),
            title: Text(t['replay_view_mode']!),
            subtitle: Text(_replayModeHint(t, ref.watch(replayViewModeProvider))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ReplayViewMode>(
              segments: [
                ButtonSegment(value: ReplayViewMode.shared, label: Text(t['replay_mode_shared']!, style: const TextStyle(fontSize: 10))),
                ButtonSegment(value: ReplayViewMode.light, label: Text(t['replay_mode_light']!, style: const TextStyle(fontSize: 10))),
                ButtonSegment(value: ReplayViewMode.gallery, label: Text(t['replay_mode_gallery']!, style: const TextStyle(fontSize: 10))),
              ],
              selected: {ref.watch(replayViewModeProvider)},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                ref.read(replayViewModeProvider.notifier).state = mode;
                saveReplayViewMode(ref.read(preferencesProvider), mode);
              },
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_notify']!,
            icon: Icons.notifications_active_outlined,
          ),
          const LocationPermissionTile(),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(t['proactive_recall']!),
            subtitle: Text(t['proactive_recall_hint']!),
            value: ref.watch(proactiveRecallEnabledProvider),
            onChanged: (enabled) async {
              ref.read(proactiveRecallEnabledProvider.notifier).state = enabled;
              await writeProactiveRecallEnabled(ref.read(preferencesProvider), enabled);
              if (enabled) {
                await BackgroundRecallWorker.register();
                final bgOk = await LocationPermissionService.requestBackgroundLocationForRecall();
                if (context.mounted && !bgOk) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t['proactive_recall_bg_hint']!)),
                  );
                }
              } else {
                await BackgroundRecallWorker.cancel();
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline_rounded),
            title: Text(t['memory_pulse_enabled']!),
            subtitle: Text(t['memory_pulse_hint']!),
            value: ref.watch(memoryPulseEnabledProvider),
            onChanged: (enabled) async {
              ref.read(memoryPulseEnabledProvider.notifier).state = enabled;
              final prefs = ref.read(preferencesProvider);
              await writeMemoryPulseEnabled(prefs, enabled);
              if (enabled) {
                await MemoryPulseWorker.register();
                await MemoryPulseWorker.ensureScheduled(prefs);
                await MemoryPulseWorker.saveMemorySnapshot(prefs, ref.read(memoryListProvider));
              } else {
                await MemoryPulseWorker.cancel();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(t['trust_dashboard_title']!),
            subtitle: Text(t['trust_dashboard_intro']!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrustDashboardScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showUsageGuide(context, t, scrollToRecall: true),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(t['guide_open_recall']!),
              ),
            ),
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_graph']!,
            icon: Icons.hub_outlined,
          ),
          const SettingsGraphAiStatusCard(),
          SwitchListTile(
            secondary: const Icon(Icons.hub_outlined),
            title: Text(t['graph_ai']!),
            subtitle: Text(
              graphAiLocked
                  ? t['graph_ai_locked']!
                  : requiresProCloudForGraphAi
                      ? t['graph_ai_hint']!
                      : t['graph_ai_dev_hint']!,
            ),
            value: graphAiLocked ? false : ref.watch(graphAiEnabledProvider),
            onChanged: graphAiLocked
                ? null
                : (enabled) {
                    ref.read(graphAiEnabledProvider.notifier).state = enabled;
                    writeGraphAiEnabled(ref.read(preferencesProvider), enabled);
                  },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contacts_outlined),
            title: Text(t['contact_person_avatars']!),
            subtitle: Text(t['contact_person_avatars_hint']!),
            value: ref.watch(contactPersonAvatarsEnabledProvider),
            onChanged: (enabled) async {
              ref.read(contactPersonAvatarsEnabledProvider.notifier).state = enabled;
              final prefs = ref.read(preferencesProvider);
              await writeContactPersonAvatarsEnabled(prefs, enabled);
              final cache = ref.read(personAvatarCacheProvider.notifier);
              if (enabled) {
                await cache.reload();
                if (!context.mounted) return;
                final loaded = ref.read(personAvatarCacheProvider);
                final messenger = ScaffoldMessenger.of(context);
                if (loaded.contactsWithPhotos == 0) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(t['contact_person_avatars_empty']!)),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        t['contact_person_avatars_loaded']!
                            .replaceAll('{count}', '${loaded.contactsWithPhotos}'),
                      ),
                    ),
                  );
                }
              } else {
                cache.clearContactPhotos();
              }
            },
          ),
          const Divider(),
          const _GraphCleanupRecommendBanner(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(t['graph_cleanup_title']!),
            subtitle: Text(t['graph_cleanup_hint']!),
            onTap: () => _runGraphCleanup(context, ref, t),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: Text(t['backup_export']!),
            subtitle: Text(t['backup_export_hint']!),
            onTap: () => _exportBackup(context, ref, t),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(t['backup_import']!),
            subtitle: Text(t['backup_import_hint']!),
            onTap: () => _importBackup(context, ref, t),
          ),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(t['home_widget']!),
            subtitle: Text(t['home_widget_hint']!),
            onTap: () => _showWidgetGuide(context, t),
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_privacy']!,
            icon: Icons.lock_outline,
          ),
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
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 12, children: themeColors.map((color) => GestureDetector(onTap: () async {
            ref.read(seedColorProvider.notifier).state = color;
            final prefs = ref.read(preferencesProvider);
            await writeSeedColor(prefs, color);
            await HomeWidgetService.refreshTheme(color, themeMode: ref.read(themeModeProvider));
          }, child: CircleAvatar(backgroundColor: color, radius: 20, child: currentSeed == color ? const Icon(Icons.check, color: Colors.white) : null))).toList())),
          ListTile(title: Text(t['language']!), trailing: DropdownButton<Locale>(value: ref.watch(languageProvider), onChanged: (l) {
            if (l == null) return;
            ref.read(languageProvider.notifier).state = l;
            writeLanguageCode(ref.read(preferencesProvider), l.languageCode);
          }, items: const [DropdownMenuItem(value: Locale('ko'), child: Text("한국어")), DropdownMenuItem(value: Locale('en'), child: Text("English"))])),
          const Divider(),
          ref.watch(packageInfoProvider).when(
            data: (info) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t['app_version']!),
              subtitle: Text('${info.version} (${info.buildNumber})'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t['privacy_policy']!),
            subtitle: Text(t['privacy_policy_open_in_app']!),
            onTap: () => openLegalDocument(
              context,
              title: t['privacy_policy']!,
              assetPath: LegalDocumentScreen.privacyAsset,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(t['terms_of_service']!),
            subtitle: Text(t['terms_open_in_app']!),
            onTap: () => openLegalDocument(
              context,
              title: t['terms_of_service']!,
              assetPath: LegalDocumentScreen.termsAsset,
            ),
          ),
          if (AppEnv.isConfigured)
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(t['account_delete_title']!),
              subtitle: Text(t['account_delete_hint']!),
              onTap: () => _confirmAccountDeletion(context, ref, t),
            ),
          if (AppEnv.isConfigured)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(t['cloud_sync_title']!),
              subtitle: Text(t['cloud_sync_run']!),
              onTap: () => _runCloudSync(context, ref, t),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t['logout']!),
            onTap: () async {
              final prefs = ref.read(preferencesProvider);
              await writeGuestMode(prefs, false);
              ref.read(guestModeProvider.notifier).state = false;
              if (AppEnv.isConfigured) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runGraphCleanup(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    final preview = await previewGraphDataCleanup(ref);
    if (!context.mounted) return;
    if (preview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['graph_cleanup_none']!)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['graph_cleanup_confirm_title']!),
        content: Text(
          t['graph_cleanup_confirm_body']!
              .replaceAll('{types}', '${preview.repairedTypes}')
              .replaceAll('{empty}', '${preview.removedEmptyMediaAnchors}')
              .replaceAll('{merged}', '${preview.mergedDuplicateAnchors}')
              .replaceAll('{fragments}', '${preview.removedOrphanFragments}')
              .replaceAll('{positions}', '${preview.clearedStalePositions}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t['cancel']!)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t['graph_cleanup_run']!)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final report = await runGraphDataCleanup(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['graph_cleanup_done']!.replaceAll('{total}', '${report.total}'))),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    try {
      await ref.read(memoryBackupServiceProvider).shareBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['backup_export_done']!)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['backup_import_failed']!)));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    try {
      final count = await ref.read(memoryBackupServiceProvider).importFromPicker();
      if (!context.mounted) return;
      if (count <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['backup_import_failed']!)));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['backup_import_done']!.replaceAll('{count}', '$count'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['backup_import_failed']!)));
    }
  }

  Future<void> _runCloudSync(BuildContext context, WidgetRef ref, Map<String, String> t) async {
    final report = await syncLocalMemoriesToCloud(
      prefs: ref.read(preferencesProvider),
      subscription: ref.read(subscriptionStatusProvider),
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    );
    if (!context.mounted) return;
    final message = report.uploaded > 0
        ? t['cloud_sync_done']!.replaceAll('{uploaded}', '${report.uploaded}')
        : t['cloud_sync_none']!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (report.uploaded > 0) {
      await ref.read(memoryListProvider.notifier).reload();
    }
  }

  void _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmAccountDeletion(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> t,
  ) async {
    final guest = ref.read(guestModeProvider);
    if (guest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['account_delete_guest']!)),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['account_delete_title']!),
        content: Text(t['account_delete_confirm']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t['cancel']!)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t['account_delete_action']!),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await deleteUserAccountAndData(prefs: ref.read(preferencesProvider));
    if (!context.mounted) return;
    if (result.success) {
      ref.read(guestModeProvider.notifier).state = false;
      await ref.read(memoryListProvider.notifier).reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['account_delete_done']!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['account_delete_failed']!)),
      );
    }
  }

  void _showUsageGuide(BuildContext context, Map<String, String> t, {bool scrollToRecall = false}) {
    final recallSectionKey = GlobalKey();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: scrollToRecall ? 0.88 : 0.82,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          if (scrollToRecall) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = recallSectionKey.currentContext;
              if (target != null) {
                Scrollable.ensureVisible(
                  target,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  alignment: 0.02,
                );
              }
            });
          }
          return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t['guide_title']!,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // PDF 및 웹 가이드 빠른 링크
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserGuidePdfScreen(title: t['user_guide_title']!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: Text(t['user_guide_open_pdf'] ?? 'PDF 가이드'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final uri = Uri.tryParse(AppUrls.userGuide);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.language_outlined, size: 20),
                      label: Text(t['user_guide_open_web'] ?? '웹 안내'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                t['guide_intro']!,
                style: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              _buildGuideSection(context, t['guide_sec_capture']!, [
                (Icons.mic_rounded, t['guide_capture_mic']!),
                (Icons.camera_alt_outlined, t['guide_capture_photo']!),
                (Icons.location_on_outlined, t['guide_capture_location']!),
              ]),
              _buildGuideRecallSection(context, t, sectionKey: recallSectionKey),
              _buildGuideSection(context, t['guide_sec_search']!, [
                (Icons.psychology_alt_rounded, t['guide_search_ai']!),
                (Icons.phone_android_outlined, t['guide_search_local']!),
                (Icons.check_circle_outline, t['guide_search_good']!),
                (Icons.info_outline, t['guide_search_limit']!),
              ]),
              _buildGuideSection(context, t['guide_sec_graph']!, [
                (Icons.hub_outlined, t['guide_graph']!),
                (Icons.auto_awesome, t['guide_graph_ai']!),
                (Icons.filter_center_focus, t['guide_graph_focus']!),
                (Icons.history_rounded, t['guide_replay']!),
                (Icons.notifications_active_outlined, t['guide_recall']!),
              ]),
              _buildGuideSection(context, t['guide_sec_ocr']!, [
                (Icons.document_scanner_outlined, t['guide_ocr_hybrid']!),
                (Icons.savings_outlined, t['guide_ocr_lowcost']!),
                (Icons.auto_awesome, t['guide_ocr_vision']!),
                (Icons.phone_android_outlined, t['guide_ocr_ondevice']!),
                (Icons.high_quality_outlined, t['guide_ocr_quality']!),
              ]),
              _buildGuideSection(context, t['guide_sec_privacy']!, [
                (Icons.lock_outline, t['guide_privacy']!),
                (Icons.widgets_outlined, t['guide_widget']!),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(t['got_it']!),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _buildGuideRecallSection(BuildContext context, Map<String, String> t, {Key? sectionKey}) {
    final steps = [
      t['guide_recall_step1']!,
      t['guide_recall_step2']!,
      t['guide_recall_step3']!,
      t['guide_recall_step4']!,
      t['guide_recall_step5']!,
    ];
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t['guide_sec_recall']!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t['guide_recall_important']!,
                  style: const TextStyle(fontSize: 14, height: 1.55, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 15, height: 1.5))),
              ],
            ),
          );
        }),
        _buildGuideItem(context, Icons.battery_charging_full_outlined, t['guide_recall_battery']!),
        _buildGuideItem(context, Icons.info_outline, t['guide_recall_limit']!),
      ],
    );
  }

  Widget _buildGuideSection(BuildContext context, String title, List<(IconData, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...items.map((item) => _buildGuideItem(context, item.$1, item.$2)),
      ],
    );
  }

  void _showWidgetGuide(BuildContext context, Map<String, String> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t['home_widget']!, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(t['home_widget_hint']!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            _buildGuideItem(context, Icons.auto_awesome_motion_rounded, t['home_widget_f1']!),
            _buildGuideItem(context, Icons.mic_rounded, t['home_widget_f2']!),
            _buildGuideItem(context, Icons.search_rounded, t['home_widget_f3']!),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(t['got_it']!)),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(BuildContext context, IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28), const SizedBox(width: 16), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5)))]));
  }
}

/// 정리 미리보기에 항목이 있으면 관계망 데이터 정리를 권장합니다.
class _GraphCleanupRecommendBanner extends ConsumerStatefulWidget {
  const _GraphCleanupRecommendBanner();

  @override
  ConsumerState<_GraphCleanupRecommendBanner> createState() => _GraphCleanupRecommendBannerState();
}

class _GraphCleanupRecommendBannerState extends ConsumerState<_GraphCleanupRecommendBanner> {
  GraphCleanupReport? _preview;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPreview);
  }

  Future<void> _loadPreview() async {
    final preview = await previewGraphDataCleanup(ref);
    if (!mounted) return;
    if (preview.isEmpty) return;
    setState(() => _preview = preview);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (preview == null || preview.isEmpty) return const SizedBox.shrink();
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: MaterialBanner(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        content: Text(
          t['graph_cleanup_recommend']!.replaceAll('{total}', '${preview.total}'),
        ),
        leading: Icon(Icons.auto_fix_high, color: Theme.of(context).colorScheme.onSecondaryContainer),
        actions: [
          TextButton(
            onPressed: () => setState(() => _preview = null),
            child: Text(t['got_it']!),
          ),
        ],
      ),
    );
  }
}
