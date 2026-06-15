import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../core/crash_reporting.dart';
import '../models/memory.dart';
import '../core/prefs.dart';
import '../services/local_memory_store.dart';
import '../services/memory_image_storage_service.dart';
import '../utils/memory_id.dart';
import '../utils/memory_image_paths.dart';
import 'app_providers.dart';

class MemoryNotifier extends StateNotifier<List<Memory>> {
  MemoryNotifier(this._prefs, this._ref) : super([]) {
    _loadMemories();
  }

  final SharedPreferences _prefs;
  final Ref _ref;

  LocalMemoryStore get _localStore => LocalMemoryStore(_prefs);

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> reload() => _loadMemories();

  Future<void> _syncImagePaths(List<Memory> memories) async {
    final reconciled = await loadReconciledImagePaths(_prefs, memories);
    _ref.read(memoryImagePathsProvider.notifier).state = reconciled;
  }

  Future<void> _loadMemories() async {
    var local = _localStore.loadAll();
    final emptyIds = local.where((m) => m.id.isEmpty).toList();
    if (emptyIds.isNotEmpty) {
      local = local
          .map((m) => m.id.isEmpty ? m.copyWith(id: generateMemoryId()) : m)
          .toList();
      await _localStore.saveAll(local);
    }
    if (!AppEnv.isConfigured || (_userId == null && !readGuestMode(_prefs))) {
      state = local;
      await _syncImagePaths(local);
      return;
    }
    if (_userId == null) {
      state = local;
      await _syncImagePaths(local);
      return;
    }
    try {
      final response = await Supabase.instance.client.from('memories').select().order('created_at', ascending: false);
      final remote = response.map<Memory>((m) => Memory.fromMap(m)).toList();
      final localIds = local.map((m) => m.id).toSet();
      state = [...local, ...remote.where((m) => !localIds.contains(m.id))];

      final imageMemoryIds = state.where((m) => m.type == 'image').map((m) => m.id).toList();
      var restored = await loadReconciledImagePaths(_prefs, state);
      var pathsChanged = false;
      for (final id in imageMemoryIds) {
        final existing = restored[id];
        if (existing != null && File(existing).existsSync()) continue;
        final path = await MemoryImageStorageService.instance.downloadThumbnailIfMissing(id);
        if (path != null) {
          restored[id] = path;
          pathsChanged = true;
        }
      }
      if (pathsChanged) {
        await saveMemoryImagePaths(_prefs, restored);
      }
      _ref.read(memoryImagePathsProvider.notifier).state = restored;
    } catch (e, stack) {
      debugPrint("Load Error: $e");
      await CrashReporting.recordError(e, stack, reason: 'load_memories');
      state = local;
      await _syncImagePaths(local);
    }
  }

  Future<Memory?> addMemory(Memory memory) async {
    if (readPrivacyLocalMode(_prefs) || readGuestMode(_prefs)) {
      final saved = memory.copyWith(
        isLocalOnly: true,
        id: ensureMemoryId(memory.id),
      );
      await _localStore.insert(saved);
      state = [saved, ...state.where((m) => m.id != saved.id)];
      return saved;
    }
    if (!AppEnv.isConfigured || _userId == null) return null;
    try {
      final response = await Supabase.instance.client
          .from('memories')
          .insert(memory.toMap(userId: _userId))
          .select()
          .single();
      final saved = Memory.fromMap(response);
      state = [saved, ...state];
      return saved;
    } catch (e, stack) {
      debugPrint("Insert Error: $e");
      await CrashReporting.recordError(e, stack, reason: 'insert_memory');
      return null;
    }
  }

  Future<bool> deleteMemory(String id) async {
    final existing = state.where((m) => m.id == id).toList();
    if (existing.isNotEmpty && existing.first.isLocalOnly) {
      final ok = await _localStore.delete(id);
      if (ok) state = state.where((m) => m.id != id).toList();
      return ok;
    }
    try {
      await Supabase.instance.client.from('memories').delete().eq('id', id);
      await MemoryImageStorageService.instance.deleteRemoteThumbnail(id);
      state = state.where((m) => m.id != id).toList();
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
