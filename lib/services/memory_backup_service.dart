import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/memory.dart';
import '../providers/app_providers.dart';
import '../providers/memory_notifier.dart';
import '../services/local_memory_store.dart';

const int kBackupFormatVersion = 1;
const _backupChannel = MethodChannel('com.thenext.personal_cognitive/backup');

class MemoryBackupBundle {
  const MemoryBackupBundle({
    required this.version,
    required this.exportedAt,
    required this.memories,
    this.imagePaths = const {},
    this.imageMemos = const {},
    this.videoPaths = const {},
  });

  final int version;
  final DateTime exportedAt;
  final List<Memory> memories;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> imageMemos;
  final Map<String, List<String>> videoPaths;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toIso8601String(),
        'memories': memories.map((m) => m.toLocalJson()).toList(),
        'image_paths': imagePaths,
        'image_memos': imageMemos,
        'video_paths': videoPaths,
      };

  factory MemoryBackupBundle.fromJson(Map<String, dynamic> json) {
    final memories = (json['memories'] as List<dynamic>? ?? [])
        .map((e) => Memory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    Map<String, List<String>> readListMap(String key) {
      final raw = json[key];
      if (raw is! Map) return {};
      return raw.map(
        (k, v) => MapEntry(k.toString(), List<String>.from(v as List? ?? const [])),
      );
    }

    return MemoryBackupBundle(
      version: json['version'] as int? ?? 1,
      exportedAt: DateTime.tryParse(json['exported_at'] as String? ?? '') ?? DateTime.now(),
      memories: memories,
      imagePaths: readListMap('image_paths'),
      imageMemos: readListMap('image_memos'),
      videoPaths: readListMap('video_paths'),
    );
  }
}

class MemoryBackupService {
  MemoryBackupService(this._ref);
  final Ref _ref;

  Future<String> exportToTempFile() async {
    final memories = _ref.read(memoryListProvider);
    final bundle = MemoryBackupBundle(
      version: kBackupFormatVersion,
      exportedAt: DateTime.now(),
      memories: memories,
      imagePaths: _ref.read(memoryImagePathsProvider),
      imageMemos: _ref.read(memoryImageMemosProvider),
      videoPaths: _ref.read(memoryVideoPathsProvider),
    );
    final dir = await getTemporaryDirectory();
    final stamp = bundle.exportedAt.toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/memoryos_backup_$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundle.toJson()),
      flush: true,
    );
    return file.path;
  }

  Future<void> shareBackup() async {
    final path = await exportToTempFile();
    await Share.shareXFiles([XFile(path)], text: 'MemoryOS backup');
  }

  Future<int> importFromPicker() async {
    if (!Platform.isAndroid) return 0;

    final raw = await _backupChannel.invokeMethod<String?>('pickJsonBackup');
    if (raw == null || raw.trim().isEmpty) return 0;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    final bundle = MemoryBackupBundle.fromJson(Map<String, dynamic>.from(decoded));
    return _applyImport(bundle);
  }

  Future<int> _applyImport(MemoryBackupBundle bundle) async {
    if (bundle.memories.isEmpty) return 0;

    final prefs = _ref.read(preferencesProvider);
    final store = LocalMemoryStore(prefs);
    final existing = store.loadAll();
    final byId = {for (final m in existing) m.id: m};

    for (final memory in bundle.memories) {
      byId[memory.id] = memory.copyWith(isLocalOnly: true);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await store.saveAll(merged);

    _ref.read(memoryImagePathsProvider.notifier).state = {
      ..._ref.read(memoryImagePathsProvider),
      ...bundle.imagePaths,
    };
    _ref.read(memoryImageMemosProvider.notifier).state = {
      ..._ref.read(memoryImageMemosProvider),
      ...bundle.imageMemos,
    };
    _ref.read(memoryVideoPathsProvider.notifier).state = {
      ..._ref.read(memoryVideoPathsProvider),
      ...bundle.videoPaths,
    };

    await _ref.read(memoryListProvider.notifier).reload();
    return bundle.memories.length;
  }
}

final memoryBackupServiceProvider = Provider((ref) => MemoryBackupService(ref));
