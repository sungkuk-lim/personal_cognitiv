import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/crash_reporting.dart';
import '../core/env.dart';
import '../models/memory.dart';
import '../services/entitlement_service.dart';
import '../models/subscription_status.dart';
import 'local_memory_store.dart';

/// 로컬 전용 기억을 Pro·클라우드 활성 시 Supabase로 업로드합니다.
class MemoryCloudSyncReport {
  const MemoryCloudSyncReport({this.uploaded = 0, this.skipped = 0, this.failed = 0});

  final int uploaded;
  final int skipped;
  final int failed;

  bool get hasWork => uploaded > 0 || failed > 0;
}

Future<MemoryCloudSyncReport> syncLocalMemoriesToCloud({
  required SharedPreferences prefs,
  required SubscriptionStatus subscription,
  bool privacyMode = false,
  bool guestMode = false,
}) async {
  if (!AppEnv.isConfigured) return const MemoryCloudSyncReport(skipped: 0);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const MemoryCloudSyncReport(skipped: 0);
  if (!canUseCloudFeatures(
    prefs,
    subscription: subscription,
    privacyMode: privacyMode,
    guestMode: guestMode,
  )) {
    return const MemoryCloudSyncReport(skipped: 0);
  }

  final store = LocalMemoryStore(prefs);
  final local = store.loadAll();
  var uploaded = 0;
  var skipped = 0;
  var failed = 0;

  for (final memory in local) {
    if (!memory.isLocalOnly && memory.id.isNotEmpty) {
      skipped++;
      continue;
    }
    try {
      final response = await Supabase.instance.client
          .from('memories')
          .upsert(memory.copyWith(isLocalOnly: false).toMap(userId: userId))
          .select()
          .single();
      final saved = Memory.fromMap(response);
      await store.update(saved.copyWith(isLocalOnly: false));
      uploaded++;
    } catch (e, stack) {
      failed++;
      debugPrint('Cloud sync upload failed for ${memory.id}: $e');
      await CrashReporting.recordError(e, stack, reason: 'cloud_sync_upload');
    }
  }

  return MemoryCloudSyncReport(uploaded: uploaded, skipped: skipped, failed: failed);
}
