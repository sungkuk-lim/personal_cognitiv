import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../services/recall_background_coordinator.dart';
import '../../services/local_memory_store.dart';
import '../../services/subscription_service.dart';
import '../../services/account_deletion_service.dart';
import '../../services/memory_backup_service.dart';
import '../../services/memory_cloud_sync_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/app_lock_service.dart';
import '../../services/firebase_email_auth_service.dart';
import '../../features/auth/pattern_lock_screen.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/trust/trust_dashboard_screen.dart';
import 'location_permission_tile.dart';
import 'settings_language_section.dart';
import 'settings_memory_film_tile.dart';
import 'settings_plan_cards.dart';
import 'settings_recommended_setup.dart';
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
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: true,
        children: [
          const SettingsLanguageSection(),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_help']!,
            subtitle: t['settings_sec_help_sub']!,
            icon: Icons.menu_book_rounded,
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(t['user_guide_title']!),
            subtitle: Text(t['user_guide_subtitle']!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showUsageGuide(context, t),
          ),
          const Divider(),
          const SettingsMemoryFilmSection(),
          const Divider(),
          SettingsRecommendedSetup(
            onOpenWidgetGuide: () => _showWidgetGuide(context, t),
            onOpenRecallGuide: () =>
                _showUsageGuide(context, t, scrollToRecall: true),
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_plan']!,
            subtitle: t['settings_sec_plan_sub']!,
            icon: Icons.workspace_premium_outlined,
          ),
          const SettingsPlanOverviewCard(),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: Text(t['pro_restore']!),
            subtitle: Text(t['pro_restore_hint'] ?? t['pro_refresh_status_hint']!),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(content: Text(t['pro_restore_working'] ?? 'Restoring…')),
              );
              try {
                await SubscriptionService.instance.ensureInitialized();
                final status = await SubscriptionService.instance.restorePurchases();
                if (!context.mounted) return;
                if (status == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        AppEnv.hasRevenueCat
                            ? t['pro_store_pending']!
                            : t['pro_store_pending_no_key']!,
                      ),
                    ),
                  );
                  return;
                }
                ref.read(subscriptionStatusProvider.notifier).state = status;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      status.isProActive
                          ? (t['pro_restore_ok'] ?? t['sub_refresh_pro']!)
                          : (t['pro_restore_none'] ?? t['sub_refresh_free']!),
                    ),
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(t['pro_restore_error']!)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: Text(t['pro_refresh_status']!),
            subtitle: Text(t['pro_refresh_status_hint']!),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(content: Text(t['pro_refresh_working'] ?? 'Refreshing…')),
              );
              try {
                await SubscriptionService.instance.ensureInitialized();
                final refreshed = await SubscriptionService.instance.refreshEntitlements();
                if (!context.mounted) return;
                ref.read(subscriptionStatusProvider.notifier).state = refreshed;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      refreshed.isProActive ? t['sub_refresh_pro']! : t['sub_refresh_free']!,
                    ),
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(t['pro_restore_error']!)),
                );
              }
            },
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_memory']!,
            subtitle: t['settings_sec_memory_sub'],
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
                ? (enabled) async {
                    if (!enabled) {
                      ref.read(onDeviceOcrProvider.notifier).state = false;
                      await saveOnDeviceOcrEnabled(ref.read(preferencesProvider), false);
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t['graph_ocr_confirm_title']!),
                        content: Text(t['graph_ocr_confirm_body']!),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t['cancel'] ?? '취소')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(t['on_device_ocr_confirm']!),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    ref.read(onDeviceOcrProvider.notifier).state = true;
                    await saveOnDeviceOcrEnabled(ref.read(preferencesProvider), true);
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
            subtitle: t['settings_sec_notify_sub'],
            icon: Icons.notifications_active_outlined,
          ),
          const LocationPermissionTile(),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(t['proactive_recall']!),
            subtitle: Text(
              ref.watch(proactiveRecallEnabledProvider)
                  ? t['proactive_recall_while_in_use']!
                  : t['proactive_recall_hint']!,
            ),
            value: ref.watch(proactiveRecallEnabledProvider),
            onChanged: (enabled) async {
              ref.read(proactiveRecallEnabledProvider.notifier).state = enabled;
              await writeProactiveRecallEnabled(ref.read(preferencesProvider), enabled);
              if (enabled) {
                final result = await RecallBackgroundCoordinator.enableAndSync(
                  prefs: ref.read(preferencesProvider),
                  memories: ref.read(memoryListProvider),
                );
                if (context.mounted && !result.backgroundLocation) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t['proactive_recall_bg_hint']!),
                      action: SnackBarAction(
                        label: t['proactive_recall_open_settings']!,
                        onPressed: LocationPermissionService.openAppSettings,
                      ),
                    ),
                  );
                }
                if (context.mounted && !result.batteryUnrestricted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t['proactive_recall_battery_hint']!),
                      action: SnackBarAction(
                        label: t['proactive_recall_open_settings']!,
                        onPressed: LocationPermissionService.openAppSettings,
                      ),
                    ),
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
            subtitle: t['settings_sec_graph_sub'],
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
          SettingsSectionHeader(
            title: t['settings_sec_data']!,
            subtitle: t['settings_sec_data_sub'],
            icon: Icons.storage_outlined,
          ),
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
          if (AppEnv.isConfigured)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(t['cloud_sync_title']!),
              subtitle: Text(t['cloud_sync_run']!),
              onTap: () => _runCloudSync(context, ref, t),
            ),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(t['home_widget']!),
            subtitle: Text(t['home_widget_hint']!),
            onTap: () => _showWidgetGuide(context, t),
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_appearance']!,
            subtitle: t['settings_sec_appearance_sub'],
            icon: Icons.palette_outlined,
          ),
          ListTile(
            title: Text(t['theme_color']!),
            subtitle: Text(t['theme_color_hint'] ?? t['settings_sec_appearance_sub']!),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: themeColors.map((color) {
                final selected = currentSeed.toARGB32() == color.toARGB32();
                final checkColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : Colors.black87;
                return Semantics(
                  selected: selected,
                  button: true,
                  label: t['theme_color']!,
                  child: GestureDetector(
                    onTap: () async {
                      ref.read(seedColorProvider.notifier).state = Color(color.toARGB32());
                      final prefs = ref.read(preferencesProvider);
                      await writeSeedColor(prefs, Color(color.toARGB32()));
                      await HomeWidgetService.refreshTheme(
                        Color(color.toARGB32()),
                        themeMode: ref.read(themeModeProvider),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.black26,
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, color: checkColor, size: 26)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_lock'] ?? '기기 잠금',
            subtitle: t['settings_sec_lock_sub'] ?? '지문·패턴으로 앱을 보호합니다',
            icon: Icons.security_rounded,
          ),
          Builder(
            builder: (context) {
              ref.watch(appLockRevisionProvider);
              final prefs = ref.watch(preferencesProvider);
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: Text(t['app_lock_biometric'] ?? '지문 잠금'),
                    subtitle: Text(t['app_lock_biometric_hint'] ?? '앱을 열 때 지문 인증을 요청합니다'),
                    value: AppLockService.instance.readBiometricEnabled(prefs),
                    onChanged: (enabled) async {
                      final lock = AppLockService.instance;
                      if (enabled) {
                        final can = await lock.canCheckBiometrics();
                        if (!can) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t['app_lock_bio_unavailable'] ?? '이 기기에서 지문을 사용할 수 없습니다.')),
                            );
                          }
                          return;
                        }
                        final ok = await lock.authenticateBiometric(reason: '지문 잠금을 켜려면 인증하세요');
                        if (!ok) return;
                      }
                      await lock.writeBiometricEnabled(prefs, enabled);
                      ref.read(appLockRevisionProvider.notifier).state++;
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.grid_view_rounded),
                    title: Text(t['app_lock_pattern'] ?? '패턴 잠금'),
                    subtitle: Text(t['app_lock_pattern_hint'] ?? '9점 패턴으로 잠금을 해제합니다'),
                    value: AppLockService.instance.readPatternEnabled(prefs),
                    onChanged: (enabled) async {
                      final lock = AppLockService.instance;
                      if (enabled) {
                        final has = await lock.hasPattern();
                        if (!has) {
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PatternLockScreen(
                                mode: PatternLockMode.register,
                                title: t['app_lock_pattern_register'] ?? '패턴 등록',
                                subtitle: t['app_lock_pattern_register_sub'] ?? '잠금에 사용할 패턴을 그려 주세요',
                                onCancel: () => Navigator.pop(context),
                                onRegistered: () async {
                                  await lock.writePatternEnabled(prefs, true);
                                  ref.read(appLockRevisionProvider.notifier).state++;
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                          return;
                        }
                      } else {
                        await lock.clearPattern();
                      }
                      await lock.writePatternEnabled(prefs, enabled);
                      ref.read(appLockRevisionProvider.notifier).state++;
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),
          SettingsSectionHeader(
            title: t['settings_sec_privacy']!,
            subtitle: t['settings_sec_privacy_sub'],
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
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t['logout']!),
            onTap: () => _confirmLogout(context, ref, t),
          ),
          const Divider(),
          const _AppVersionTile(),
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
    final message = _cloudSyncMessage(t, report);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (report.uploaded > 0) {
      await ref.read(memoryListProvider.notifier).reload();
    }
  }

  String _cloudSyncMessage(Map<String, String> t, MemoryCloudSyncReport report) {
    switch (report.skipReason) {
      case MemoryCloudSyncSkipReason.notConfigured:
        return t['cloud_sync_need_config'] ?? '클라우드가 설정되지 않은 설치본입니다.';
      case MemoryCloudSyncSkipReason.notLoggedIn:
        return t['cloud_sync_need_login'] ?? '동기화하려면 로그인이 필요합니다.';
      case MemoryCloudSyncSkipReason.localOnlyMode:
        return t['cloud_sync_local_only'] ?? '게스트·프라이버시 모드에서는 클라우드 동기화를 사용할 수 없습니다.';
      case MemoryCloudSyncSkipReason.noPro:
        return t['cloud_sync_need_pro'] ?? '클라우드 동기화는 MemoryOS Pro가 필요합니다.';
      case MemoryCloudSyncSkipReason.none:
        break;
    }
    if (report.uploaded > 0 && report.failed > 0) {
      return (t['cloud_sync_partial'] ?? '업로드 {uploaded}건 · 실패 {failed}건')
          .replaceAll('{uploaded}', '${report.uploaded}')
          .replaceAll('{failed}', '${report.failed}');
    }
    if (report.uploaded > 0) {
      return t['cloud_sync_done']!.replaceAll('{uploaded}', '${report.uploaded}');
    }
    if (report.failed > 0) {
      final base = (t['cloud_sync_failed'] ?? '업로드에 실패했습니다 ({failed}건). 나중에 다시 시도하세요.')
          .replaceAll('{failed}', '${report.failed}');
      final err = report.firstError;
      if (err != null && err.isNotEmpty) {
        final short = err.replaceAll(RegExp(r'\s+'), ' ').trim();
        return '$base (${short.length > 120 ? '${short.substring(0, 117)}…' : short})';
      }
      return base;
    }
    return t['cloud_sync_none']!;
  }

  Future<void> _openUserGuideWeb(BuildContext context, Map<String, String> t) async {
    final uri = Uri.tryParse(AppUrls.userGuide);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['user_guide_open_failed']!)),
        );
      }
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['user_guide_open_failed']!)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['user_guide_open_failed']!)),
        );
      }
    }
  }

  void _openUserGuidePdf(BuildContext context, Map<String, String> t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserGuidePdfScreen(title: t['user_guide_title']!),
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['logout_confirm_title']!),
        content: Text(t['logout_confirm_body']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t['cancel']!),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t['logout_confirm_action']!),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final prefs = ref.read(preferencesProvider);
    await writeGuestMode(prefs, false);
    ref.read(guestModeProvider.notifier).state = false;
    await FirebaseEmailAuthService.instance.signOut();
    if (!context.mounted) return;
    // 설정 화면을 닫고 AuthGate가 로그인 화면으로 전환합니다.
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                        _openUserGuidePdf(context, t);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: Text(t['user_guide_open_pdf']!),
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
                        await _openUserGuideWeb(context, t);
                      },
                      icon: const Icon(Icons.language_outlined, size: 20),
                      label: Text(t['user_guide_open_web']!),
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
              if ((t['guide_sec_film'] ?? '').isNotEmpty && (t['guide_film'] ?? '').isNotEmpty)
                _buildGuideSection(context, t['guide_sec_film']!, [
                  (Icons.movie_creation_outlined, t['guide_film']!),
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

/// 앱 버전 타일 — 로딩 중에도 높이를 유지해 스크롤 중 레이아웃 점프를 막습니다.
class _AppVersionTile extends ConsumerWidget {
  const _AppVersionTile();

  static const double _tileHeight = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return ref.watch(packageInfoProvider).when(
      data: (info) => ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(t['app_version']!),
        subtitle: Text('${info.version} (${info.buildNumber})'),
      ),
      loading: () => SizedBox(
        height: _tileHeight,
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t['app_version']!),
        ),
      ),
      error: (_, _) => const SizedBox(height: _tileHeight),
    );
  }
}
