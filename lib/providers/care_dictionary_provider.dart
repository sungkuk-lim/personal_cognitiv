import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/care_entity_dictionary.dart';
import '../models/care_dictionary_overrides.dart';
import '../services/care_dictionary_repository.dart';
import '../services/care_dictionary_sync_service.dart';

class CareDictionaryState {
  const CareDictionaryState({
    required this.dictionary,
    required this.overrides,
    this.syncing = false,
    this.lastSyncMessage,
  });

  final CareEntityDictionary dictionary;
  final CareDictionaryOverrides overrides;
  final bool syncing;
  final String? lastSyncMessage;

  CareDictionaryState copyWith({
    CareEntityDictionary? dictionary,
    CareDictionaryOverrides? overrides,
    bool? syncing,
    String? lastSyncMessage,
  }) {
    return CareDictionaryState(
      dictionary: dictionary ?? this.dictionary,
      overrides: overrides ?? this.overrides,
      syncing: syncing ?? this.syncing,
      lastSyncMessage: lastSyncMessage,
    );
  }
}

class CareDictionaryNotifier extends StateNotifier<CareDictionaryState> {
  CareDictionaryNotifier(this._prefs)
      : _repo = CareDictionaryRepository(_prefs),
        super(CareDictionaryState(
          dictionary: CareDictionaryRepository(_prefs).loadMergedDictionary(),
          overrides: CareDictionaryRepository(_prefs).readOverrides(),
        ));

  final SharedPreferences _prefs;
  final CareDictionaryRepository _repo;

  void reload() {
    state = CareDictionaryState(
      dictionary: _repo.loadMergedDictionary(),
      overrides: _repo.readOverrides(),
    );
  }

  Future<void> addHospital(String name) async {
    final overrides = await _repo.addHospital(name);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<void> removeHospital(String name) async {
    final overrides = await _repo.removeHospital(name);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<void> addDepartment(String name) async {
    final overrides = await _repo.addDepartment(name);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<void> removeDepartment(String name) async {
    final overrides = await _repo.removeDepartment(name);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<void> addTypoMapping({required String from, required String to}) async {
    final overrides = await _repo.addTypoMapping(from: from, to: to);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<void> removeTypoMapping(String from) async {
    final overrides = await _repo.removeTypoMapping(from);
    state = state.copyWith(
      overrides: overrides,
      dictionary: _repo.loadMergedDictionary(),
    );
  }

  Future<String?> syncWithCloud() async {
    state = state.copyWith(syncing: true, lastSyncMessage: null);
    try {
      final msg = await _runCloudSync();
      state = state.copyWith(syncing: false, lastSyncMessage: msg);
      return msg;
    } catch (e, stack) {
      debugPrint('Care dictionary sync error: $e\n$stack');
      const msg = 'sync_failed';
      state = state.copyWith(syncing: false, lastSyncMessage: msg);
      return msg;
    }
  }

  /// 로그인·앱 재시작 시 백그라운드 병합 (UI 스피너 없음).
  Future<void> syncOnLoginSilently() async {
    try {
      await _runCloudSync();
      reload();
    } catch (e, stack) {
      debugPrint('Care dictionary login sync: $e\n$stack');
    }
  }

  Future<String> _runCloudSync() async {
    final result = await CareDictionarySyncService.sync(
      prefs: _prefs,
      localOverrides: state.overrides,
    );
    if (result.merged != null) {
      await _repo.replaceOverrides(result.merged!);
    }
    reload();
    return result.message;
  }
}

final careDictionaryProvider =
    StateNotifierProvider<CareDictionaryNotifier, CareDictionaryState>((ref) {
  throw UnimplementedError('careDictionaryProvider must be overridden in main()');
});

final careEntityDictionaryProvider = Provider<CareEntityDictionary>((ref) {
  return ref.watch(careDictionaryProvider).dictionary;
});
