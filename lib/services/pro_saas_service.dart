import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/subscription_config.dart';
import '../models/memory.dart';
import '../models/subscription_status.dart';
import 'local_memory_store.dart';
import 'memory_cloud_sync_service.dart';

const String prefLastCloudSyncAt = 'pro_last_cloud_sync_at';

/// Pro SaaS — 클라우드·쿼터·동기화 상태.
class ProSaasSnapshot {
  const ProSaasSnapshot({
    required this.isPro,
    this.cloudMemoryCount = 0,
    this.localOnlyCount = 0,
    this.lastSyncAt,
    this.subscription,
    this.syncReport,
  });

  final bool isPro;
  final int cloudMemoryCount;
  final int localOnlyCount;
  final DateTime? lastSyncAt;
  final SubscriptionStatus? subscription;
  final MemoryCloudSyncReport? syncReport;

  int get chatRemaining {
    final used = subscription?.chatUsed ?? 0;
    return (SubscriptionConfig.quotaChatMonthly - used).clamp(0, SubscriptionConfig.quotaChatMonthly);
  }

  int get embeddingRemaining {
    final used = subscription?.embeddingUsed ?? 0;
    return (SubscriptionConfig.quotaEmbeddingMonthly - used)
        .clamp(0, SubscriptionConfig.quotaEmbeddingMonthly);
  }

  int get visionRemaining {
    final used = subscription?.visionUsed ?? 0;
    return (SubscriptionConfig.quotaVisionMonthly - used).clamp(0, SubscriptionConfig.quotaVisionMonthly);
  }
}

Future<ProSaasSnapshot> loadProSaasSnapshot({
  required SharedPreferences prefs,
  required SubscriptionStatus subscription,
  required List<Memory> allMemories,
  bool privacyMode = false,
  bool guestMode = false,
}) async {
  final isPro = subscription.isProActive;
  final localOnly = allMemories.where((m) => m.isLocalOnly).length;
  final cloudCount = allMemories.where((m) => !m.isLocalOnly).length;
  final lastSyncRaw = prefs.getString(prefLastCloudSyncAt);
  final lastSync = lastSyncRaw != null ? DateTime.tryParse(lastSyncRaw) : null;

  return ProSaasSnapshot(
    isPro: isPro,
    cloudMemoryCount: cloudCount,
    localOnlyCount: localOnly,
    lastSyncAt: lastSync,
    subscription: subscription,
  );
}

Future<ProSaasSnapshot> runProCloudSync({
  required SharedPreferences prefs,
  required SubscriptionStatus subscription,
  required List<Memory> allMemories,
  bool privacyMode = false,
  bool guestMode = false,
}) async {
  final report = await syncLocalMemoriesToCloud(
    prefs: prefs,
    subscription: subscription,
    privacyMode: privacyMode,
    guestMode: guestMode,
  );
  if (report.uploaded > 0) {
    await prefs.setString(prefLastCloudSyncAt, DateTime.now().toIso8601String());
  }
  final base = await loadProSaasSnapshot(
    prefs: prefs,
    subscription: subscription,
    allMemories: allMemories,
    privacyMode: privacyMode,
    guestMode: guestMode,
  );
  return ProSaasSnapshot(
    isPro: base.isPro,
    cloudMemoryCount: base.cloudMemoryCount,
    localOnlyCount: base.localOnlyCount,
    lastSyncAt: DateTime.now(),
    subscription: base.subscription,
    syncReport: report,
  );
}
