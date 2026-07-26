import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/graph/graph_chat_save.dart';
import '../core/env.dart';
import '../core/crash_reporting.dart';
import '../models/memory.dart';
import '../core/prefs.dart';
import '../services/local_memory_store.dart';
import '../services/entitlement_service.dart';
import '../services/background_recall_worker.dart';
import '../services/graph_ai_orchestrator.dart';
import '../services/graph_snapshot_invalidation.dart';
import '../services/memory_cloud_sync_service.dart';
import '../services/memory_entity_reenrich_service.dart';
import '../services/memory_pulse_worker.dart';
import '../utils/graph_snapshot_store.dart';
import '../services/home_widget_service.dart';
import '../services/memory_image_storage_service.dart';
import '../utils/memory_id.dart';
import '../utils/memory_image_paths.dart';
import '../utils/memory_place_cache.dart';
import '../utils/memory_graph_semantics.dart';
import '../utils/memory_entity_cache.dart';
import 'app_providers.dart';
import 'subscription_providers.dart';

class MemoryNotifier extends StateNotifier<List<Memory>> {
  MemoryNotifier(this._prefs, this._ref) : super([]) {
    _loadMemories();
  }

  final SharedPreferences _prefs;
  final Ref _ref;

  LocalMemoryStore get _localStore => LocalMemoryStore(_prefs);

  String? get _userId =>
      AppEnv.isConfigured ? Supabase.instance.client.auth.currentUser?.id : null;

  Future<void> reload() => _loadMemories();

  Future<void> _syncPlaceNames(List<Memory> memories) async {
    final locale = _ref.read(languageProvider).languageCode;
    final names = await warmPlaceNamesForMemories(memories, _prefs, localeCode: locale);
    final addresses = await warmPlaceFullAddressesForMemories(memories, _prefs, localeCode: locale);
    _ref.read(memoryPlaceNamesProvider.notifier).state = names;
    _ref.read(memoryPlaceFullAddressesProvider.notifier).state = addresses;
  }

  Future<void> _syncImagePaths(List<Memory> memories) async {
    final reconciled = await loadReconciledImagePaths(_prefs, memories);
    _ref.read(memoryImagePathsProvider.notifier).state = reconciled;
  }

  Future<void> _syncBackgroundNotifications() async {
    if (state.isEmpty) return;
    await BackgroundRecallWorker.saveMemorySnapshot(_prefs, state);
    await MemoryPulseWorker.ensureScheduled(_prefs);
  }

  Future<void> _syncHomeWidget() async {
    final locale = _ref.read(languageProvider).languageCode;
    final seedColor = _ref.read(seedColorProvider);
    final themeMode = _ref.read(themeModeProvider);
    await HomeWidgetService.syncMemories(
      state,
      localeCode: locale,
      seedColor: seedColor,
      themeMode: themeMode,
    );
    await _syncBackgroundNotifications();
  }

  Future<List<Memory>> _applyLocalGraphReenrich(List<Memory> local) async {
    final locale = _ref.read(languageProvider).languageCode;
    final result = await reenrichLocalMemoriesIfNeeded(
      store: _localStore,
      prefs: _prefs,
      memories: local,
      localeCode: locale,
    );
    if (result.updatedCount > 0) {
      await writeGraphReenrichPendingNotice(_prefs, result.updatedCount);
      _ref.read(memoryGraphFragmentsProvider.notifier).state =
          readMemoryGraphFragments(_prefs);
    }
    return result.memories;
  }

  Future<void> _loadMemories() async {
    MemoryEntityCache.clear();
    var local = _localStore.loadAll().map(normalizeGraphNoteMemory).toList();
    final emptyIds = local.where((m) => m.id.isEmpty).toList();
    if (emptyIds.isNotEmpty) {
      local = local
          .map((m) => m.id.isEmpty ? m.copyWith(id: generateMemoryId()) : m)
          .toList();
      await _localStore.saveAll(local);
    }
    local = await _applyLocalGraphReenrich(local);
    if (!AppEnv.isConfigured || (_userId == null && !readGuestMode(_prefs))) {
      state = local;
      await _syncImagePaths(local);
      await _syncPlaceNames(local);
      unawaited(_syncHomeWidget());
      return;
    }
    if (_userId == null) {
      state = local;
      await _syncImagePaths(local);
      await _syncPlaceNames(local);
      unawaited(_syncHomeWidget());
      return;
    }
    final subscription = _ref.read(subscriptionStatusProvider);
    if (!canUseCloudFeatures(
      _prefs,
      subscription: subscription,
      privacyMode: _ref.read(privacyLocalModeProvider),
      guestMode: _ref.read(guestModeProvider),
    )) {
      state = local;
      await _syncImagePaths(local);
      await _syncPlaceNames(local);
      unawaited(_syncHomeWidget());
      return;
    }
    try {
      final response = await Supabase.instance.client.from('memories').select().order('created_at', ascending: false);
      final remote = response.map<Memory>((m) => normalizeGraphNoteMemory(Memory.fromMap(m))).toList();
      final localIds = local.map((m) => m.id).toSet();
      state = [...local, ...remote.where((m) => !localIds.contains(m.id))];

      final imageMemoryIds = state.where((m) => m.type == 'image').map((m) => m.id).toList();
      var restored = await loadReconciledImagePaths(_prefs, state);
      var pathsChanged = false;
      for (final id in imageMemoryIds) {
        final existing = restored[id];
        if (existing != null && existing.isNotEmpty && File(existing.first).existsSync()) continue;
        final path = await MemoryImageStorageService.instance.downloadThumbnailIfMissing(id);
        if (path != null) {
          restored[id] = [path];
          pathsChanged = true;
        }
      }
      if (pathsChanged) {
        await saveMemoryImagePaths(_prefs, restored);
      }
      _ref.read(memoryImagePathsProvider.notifier).state = restored;
      await _syncPlaceNames(state);
      unawaited(_syncHomeWidget());
      await syncLocalMemoriesToCloud(
        prefs: _prefs,
        subscription: subscription,
        privacyMode: _ref.read(privacyLocalModeProvider),
        guestMode: _ref.read(guestModeProvider),
      );
    } catch (e, stack) {
      debugPrint("Load Error: $e");
      await CrashReporting.recordError(e, stack, reason: 'load_memories');
      state = local;
      await _syncImagePaths(local);
      await _syncPlaceNames(local);
      unawaited(_syncHomeWidget());
    }
  }

  Future<Memory?> addMemory(Memory memory) async {
    final localeCode = _ref.read(languageProvider).languageCode;
    memory = enrichMemoryGraphSemantics(memory, localeCode: localeCode);
    if (_shouldPersistLocally(memory)) {
      return _insertLocalMemory(memory);
    }
    try {
      final response = await Supabase.instance.client
          .from('memories')
          .insert(memory.toMap(userId: _userId))
          .select()
          .single();
      final saved = normalizeGraphNoteMemory(Memory.fromMap(response));
      state = [saved, ...state.where((m) => m.id != saved.id)];
      unawaited(_syncHomeWidget());
      scheduleGraphAiSync(_ref, saved);
      return saved;
    } catch (e, stack) {
      debugPrint("Insert Error: $e");
      await CrashReporting.recordError(e, stack, reason: 'insert_memory');
      return _insertLocalMemory(memory);
    }
  }

  bool _shouldPersistLocally(Memory memory) {
    if (isGraphNoteMemory(memory) || memory.isLocalOnly) return true;
    final subscription = _ref.read(subscriptionStatusProvider);
    if (readPrivacyLocalMode(_prefs) ||
        readGuestMode(_prefs) ||
        !canUseCloudFeatures(
          _prefs,
          subscription: subscription,
          privacyMode: _ref.read(privacyLocalModeProvider),
          guestMode: _ref.read(guestModeProvider),
        )) {
      return true;
    }
    return !AppEnv.isConfigured || _userId == null;
  }

  Future<Memory> _insertLocalMemory(Memory memory) async {
    final saved = normalizeGraphNoteMemory(
      memory.copyWith(
        isLocalOnly: true,
        id: ensureMemoryId(memory.id),
      ),
    );
    await _localStore.insert(saved);
    state = [saved, ...state.where((m) => m.id != saved.id)];
    unawaited(_syncHomeWidget());
    scheduleGraphAiSync(_ref, saved);
    return saved;
  }

  Future<Memory?> updateMemory(Memory memory) async {
    MemoryEntityCache.clear();
    final localeCode = _ref.read(languageProvider).languageCode;
    memory = enrichMemoryGraphSemantics(memory, localeCode: localeCode);
    await invalidateGraphSnapshotsForMemory(_prefs, _ref, memory);
    if (_shouldPersistLocally(memory) || memory.isLocalOnly) {
      final updated = await _localStore.update(memory.copyWith(isLocalOnly: true));
      if (updated == null) {
        return _insertLocalMemory(memory);
      }
      final normalized = normalizeGraphNoteMemory(updated);
      state = state.map((m) => m.id == normalized.id ? normalized : m).toList();
      unawaited(_syncHomeWidget());
      unawaited(_syncPlaceNames(state));
      scheduleGraphAiSync(_ref, normalized);
      return normalized;
    }
    try {
      await Supabase.instance.client.from('memories').update(memory.toMap(userId: _userId)).eq('id', memory.id);
      state = state.map((m) => m.id == memory.id ? memory : m).toList();
      unawaited(_syncHomeWidget());
      unawaited(_syncPlaceNames(state));
      scheduleGraphAiSync(_ref, memory);
      return memory;
    } catch (e, stack) {
      debugPrint("Update Error: $e");
      await CrashReporting.recordError(e, stack, reason: 'update_memory');
      final updated = await _localStore.update(memory.copyWith(isLocalOnly: true));
      if (updated != null) {
        final normalized = normalizeGraphNoteMemory(updated);
        state = state.map((m) => m.id == normalized.id ? normalized : m).toList();
        unawaited(_syncHomeWidget());
        scheduleGraphAiSync(_ref, normalized);
        return normalized;
      }
      return _insertLocalMemory(memory);
    }
  }

  /// AI 계층 태그 병합 전용 — Graph AI 재스케줄을 돌리지 않습니다.
  Future<Memory?> mergeEntitiesWithoutAiResync(Memory memory) async {
    MemoryEntityCache.clear();
    final localeCode = _ref.read(languageProvider).languageCode;
    final enriched = enrichMemoryGraphSemantics(memory, localeCode: localeCode);
    if (_shouldPersistLocally(enriched) || enriched.isLocalOnly) {
      final updated = await _localStore.update(enriched.copyWith(isLocalOnly: true));
      final saved = normalizeGraphNoteMemory(updated ?? enriched);
      state = state.map((m) => m.id == saved.id ? saved : m).toList();
      if (!state.any((m) => m.id == saved.id)) {
        state = [saved, ...state];
      }
      return saved;
    }
    try {
      await Supabase.instance.client
          .from('memories')
          .update(enriched.toMap(userId: _userId))
          .eq('id', enriched.id);
      state = state.map((m) => m.id == enriched.id ? enriched : m).toList();
      return enriched;
    } catch (e, stack) {
      debugPrint('mergeEntitiesWithoutAiResync: $e');
      await CrashReporting.recordError(e, stack, reason: 'merge_hierarchy_entities');
      final updated = await _localStore.update(enriched.copyWith(isLocalOnly: true));
      final saved = normalizeGraphNoteMemory(updated ?? enriched);
      state = state.map((m) => m.id == saved.id ? saved : m).toList();
      return saved;
    }
  }

  Future<bool> deleteMemory(String id) async {
    MemoryEntityCache.clear();
    final existing = state.where((m) => m.id == id).toList();
    final prefs = _prefs;
    await removeMemoryGraphFragment(prefs, id);
    if (existing.isNotEmpty && existing.first.isLocalOnly) {
      final ok = await _localStore.delete(id);
      if (ok) {
        state = state.where((m) => m.id != id).toList();
        await _syncHomeWidget();
      }
      return ok;
    }
    try {
      await Supabase.instance.client.from('memories').delete().eq('id', id);
      await MemoryImageStorageService.instance.deleteRemoteThumbnail(id);
      state = state.where((m) => m.id != id).toList();
      unawaited(_syncHomeWidget());
      return true;
    } catch (e, stack) {
      debugPrint("Server Delete Failed: $e");
      await CrashReporting.recordError(e, stack, reason: 'delete_memory');
      return false;
    }
  }
}

final memoryListProvider = StateNotifierProvider<MemoryNotifier, List<Memory>>(
  (ref) => MemoryNotifier(ref.read(preferencesProvider), ref),
);
