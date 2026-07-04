import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_maturity.dart';
import '../core/env.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../models/subscription_status.dart';
import '../providers/app_providers.dart';
import '../providers/subscription_providers.dart';
import '../services/entitlement_service.dart';
import '../services/graph_ai_service.dart';
import '../providers/memory_notifier.dart';
import '../services/local_memory_store.dart';
import '../utils/graph_snapshot_store.dart';
import '../utils/memory_grouping.dart';

/// 관계망 AI 사용 가능 여부 (설정 + 클라우드 + 비게스트).
bool isGraphAiActive({
  required SharedPreferences prefs,
  required bool graphAiEnabled,
  required bool privacyMode,
  required bool guestMode,
  required SubscriptionStatus subscription,
}) {
  if (!graphAiEnabled) return false;
  if (privacyMode || guestMode) return false;
  if (!requiresProCloudForGraphAi) return true;
  if (!AppEnv.isConfigured) return false;
  if (!hasProEntitlement(subscription)) return false;
  return true;
}

/// 방식 C: 저장 시 기억 조각 + 묶음 변경 시 클러스터 요약.
class GraphAiOrchestrator {
  GraphAiOrchestrator(this._prefs, this._ref);

  final SharedPreferences _prefs;
  final Ref _ref;

  Future<void> syncAfterMemorySaved(Memory memory, List<Memory> allMemories) async {
    if (!_isActive()) return;
    if (isGraphNoteMemory(memory)) return;

    final locale = _ref.read(languageProvider).languageCode;
    final clusterKey = clusterKeyForMemory(memory);
    final siblings = allMemories.where((m) => clusterKeyForMemory(m) == clusterKey).toList();

    final fragment = await GraphAiService.instance.generateMemoryFragment(
      memory: memory,
      localeCode: locale,
      clusterSiblings: siblings,
    );

    if (fragment != null) {
      await saveMemoryGraphFragment(_prefs, memory.id, fragment);
      _ref.read(memoryGraphFragmentsProvider.notifier).state = {
        ..._ref.read(memoryGraphFragmentsProvider),
        memory.id: fragment,
      };
    }

    if (siblings.length >= 2) {
      await _syncCluster(clusterKey.id, siblings, locale);
    }
  }

  Future<void> _syncCluster(String clusterId, List<Memory> memories, String localeCode) async {
    final snapshot = await GraphAiService.instance.generateClusterSnapshot(
      clusterId: clusterId,
      memories: memories,
      localeCode: localeCode,
    );
    if (snapshot == null) return;

    await saveMemoryGraphCluster(_prefs, clusterId, snapshot);
    _ref.read(memoryGraphClustersProvider.notifier).state = {
      ..._ref.read(memoryGraphClustersProvider),
      clusterId: snapshot,
    };
  }

  bool _isActive() {
    return isGraphAiActive(
      prefs: _prefs,
      graphAiEnabled: _ref.read(graphAiEnabledProvider),
      privacyMode: _ref.read(privacyLocalModeProvider),
      guestMode: isLocalOnlyMode(
        _prefs,
        privacyMode: _ref.read(privacyLocalModeProvider),
        guestMode: _ref.read(guestModeProvider),
      ),
      subscription: _ref.read(subscriptionStatusProvider),
    );
  }
}

final _graphAiSyncQueue = <String, Memory>{};
Timer? _graphAiSyncTimer;

/// 편집·무효화 직후 예약된 AI 동기화를 취소합니다.
void cancelGraphAiSyncForMemory(String memoryId) {
  _graphAiSyncQueue.remove(memoryId);
}

/// 저장 후 백그라운드 동기화 — UI 블로킹 없음, 5초 디바운스로 비용 절감.
void scheduleGraphAiSync(Ref ref, Memory memory) {
  if (isGraphNoteMemory(memory)) return;

  final prefs = ref.read(preferencesProvider);
  if (!isGraphAiActive(
    prefs: prefs,
    graphAiEnabled: ref.read(graphAiEnabledProvider),
    privacyMode: ref.read(privacyLocalModeProvider),
    guestMode: isLocalOnlyMode(
      prefs,
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    ),
    subscription: ref.read(subscriptionStatusProvider),
  )) {
    return;
  }

  _graphAiSyncQueue[memory.id] = memory;
  _graphAiSyncTimer?.cancel();
  _graphAiSyncTimer = Timer(const Duration(seconds: 5), () {
    final batch = Map<String, Memory>.from(_graphAiSyncQueue);
    _graphAiSyncQueue.clear();
    Future.microtask(() async {
      final memories = ref.read(memoryListProvider);
      final orchestrator = GraphAiOrchestrator(prefs, ref);
      for (final item in batch.values) {
        try {
          await orchestrator.syncAfterMemorySaved(item, memories);
        } catch (e, stack) {
          debugPrint('scheduleGraphAiSync failed for ${item.id}: $e\n$stack');
        }
      }
    });
  });
}
