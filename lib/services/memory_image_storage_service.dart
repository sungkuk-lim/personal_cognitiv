import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'image_pipeline_service.dart';

const String memoryImagesBucket = 'memory-images';

/// 썸네일을 Supabase Storage에 백업하고, 재설치 후 복원합니다.
class MemoryImageStorageService {
  MemoryImageStorageService._();
  static final MemoryImageStorageService instance = MemoryImageStorageService._();

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  String _objectPath(String memoryId) => '$_userId/$memoryId.jpg';

  Future<void> uploadThumbnail(String memoryId, Uint8List jpegBytes) async {
    if (!AppEnv.isConfigured || _userId == null) return;
    final thumbnail = createThumbnailBytes(jpegBytes);
    if (thumbnail == null) return;
    try {
      await Supabase.instance.client.storage.from(memoryImagesBucket).uploadBinary(
            _objectPath(memoryId),
            thumbnail,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } catch (e) {
      debugPrint('Thumbnail upload error: $e');
    }
  }

  Future<String?> downloadThumbnailIfMissing(String memoryId) async {
    if (!AppEnv.isConfigured || _userId == null) return null;
    final imagesDir = await getMemoryImagesDirectory();
    final localFile = File('${imagesDir.path}/$memoryId.jpg');
    if (await localFile.exists()) return localFile.path;

    try {
      final bytes = await Supabase.instance.client.storage.from(memoryImagesBucket).download(_objectPath(memoryId));
      await localFile.writeAsBytes(bytes, flush: true);
      return localFile.path;
    } catch (e) {
      debugPrint('Thumbnail download skip ($memoryId): $e');
      return null;
    }
  }

  Future<void> syncThumbnailsForMemories(List<String> memoryIds) async {
    if (!AppEnv.isConfigured || _userId == null || memoryIds.isEmpty) return;
    for (final id in memoryIds) {
      await downloadThumbnailIfMissing(id);
    }
  }

  Future<void> deleteRemoteThumbnail(String memoryId) async {
    if (!AppEnv.isConfigured || _userId == null) return;
    try {
      await Supabase.instance.client.storage.from(memoryImagesBucket).remove([_objectPath(memoryId)]);
    } catch (e) {
      debugPrint('Thumbnail delete error: $e');
    }
  }
}
