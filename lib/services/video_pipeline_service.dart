import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/prefs.dart';
import '../providers/app_providers.dart';
import '../utils/memory_id.dart';
import '../utils/memory_video_paths.dart';

Future<Directory> getMemoryVideosDirectory() async {
  await warmMemoryVideosDirectoryCache();
  final dir = await getApplicationDocumentsDirectory();
  final videosDir = Directory('${dir.path}/memory_videos');
  if (!await videosDir.exists()) {
    await videosDir.create(recursive: true);
  }
  return videosDir;
}

Future<String?> appendMemoryVideo({
  required WidgetRef ref,
  required String memoryId,
  required XFile picked,
}) async {
  await warmMemoryVideosDirectoryCache();
  final id = ensureMemoryId(memoryId);
  final prefs = ref.read(preferencesProvider);
  final videosDir = await getMemoryVideosDirectory();
  final existing = resolvedVideoPathsForMemoryId(id, ref.read(memoryVideoPathsProvider));
  final index = existing.length;
  final dest = File('${videosDir.path}/${id}_$index.mp4');

  if (picked.path.isNotEmpty) {
    await File(picked.path).copy(dest.path);
  } else {
    await dest.writeAsBytes(await picked.readAsBytes(), flush: true);
  }

  await _ensureVideoThumbnailPlaceholder(dest.path);

  final updatedList = [...existing, dest.path];
  final paths = {...ref.read(memoryVideoPathsProvider), id: updatedList};
  ref.read(memoryVideoPathsProvider.notifier).state = paths;
  await saveMemoryVideoPaths(prefs, paths);
  return dest.path;
}

Future<bool> removeVideoAtIndex({
  required WidgetRef ref,
  required String memoryId,
  required int index,
}) async {
  final id = ensureMemoryId(memoryId);
  final prefs = ref.read(preferencesProvider);
  final videos = List<String>.from(resolvedVideoPathsForMemoryId(id, ref.read(memoryVideoPathsProvider)));
  if (index < 0 || index >= videos.length) return false;

  final videoPath = videos[index];
  try {
    final videoFile = File(videoPath);
    if (await videoFile.exists()) await videoFile.delete();
    final thumb = File(thumbPathForVideoFile(videoPath));
    if (await thumb.exists()) await thumb.delete();
  } catch (e) {
    // ignore delete errors
  }

  videos.removeAt(index);
  final paths = {...ref.read(memoryVideoPathsProvider)};
  if (videos.isEmpty) {
    paths.remove(id);
  } else {
    paths[id] = videos;
  }
  ref.read(memoryVideoPathsProvider.notifier).state = paths;
  await saveMemoryVideoPaths(prefs, paths);
  return true;
}

Future<void> deleteAllMemoryVideos(WidgetRef ref, String memoryId) async {
  final id = ensureMemoryId(memoryId);
  final videos = resolvedVideoPathsForMemoryId(id, ref.read(memoryVideoPathsProvider));
  for (final path in videos) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      final thumb = File(thumbPathForVideoFile(path));
      if (await thumb.exists()) await thumb.delete();
    } catch (e) {
      // ignore delete errors
    }
  }
  final prefs = ref.read(preferencesProvider);
  final paths = {...ref.read(memoryVideoPathsProvider)}..remove(id);
  ref.read(memoryVideoPathsProvider.notifier).state = paths;
  await saveMemoryVideoPaths(prefs, paths);
}

Future<void> _ensureVideoThumbnailPlaceholder(String videoPath) async {
  final thumb = File(thumbPathForVideoFile(videoPath));
  if (await thumb.exists()) return;

  await thumb.parent.create(recursive: true);

  // 실제 프레임 추출 라이브러리 충돌을 피하기 위해, 안정적인 플레이 아이콘 썸네일을 생성합니다.
  final canvas = img.Image(width: 320, height: 180);
  img.fill(canvas, color: img.ColorRgb8(32, 35, 48));
  img.fillRect(canvas, x1: 0, y1: 110, x2: 319, y2: 179, color: img.ColorRgba8(0, 0, 0, 110));

  final cx = 160;
  final cy = 90;
  final r = 38;
  img.fillCircle(canvas, x: cx, y: cy, radius: r, color: img.ColorRgba8(255, 255, 255, 220));
  // image 패키지 버전 호환을 위해 간단한 재생 아이콘(막대+삼각형 느낌)을 사각형으로 근사합니다.
  img.fillRect(canvas, x1: cx - 8, y1: cy - 13, x2: cx - 2, y2: cy + 13, color: img.ColorRgb8(45, 45, 45));
  img.fillRect(canvas, x1: cx - 1, y1: cy - 10, x2: cx + 7, y2: cy + 10, color: img.ColorRgb8(45, 45, 45));
  img.fillRect(canvas, x1: cx + 8, y1: cy - 7, x2: cx + 14, y2: cy + 7, color: img.ColorRgb8(45, 45, 45));

  final jpg = img.encodeJpg(canvas, quality: 82);
  await thumb.writeAsBytes(jpg, flush: true);
}
