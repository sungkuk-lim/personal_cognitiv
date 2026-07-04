import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/memory_image_paths.dart';

String? _cachedMemoryVideosDir;

Future<void> warmMemoryVideosDirectoryCache() async {
  if (_cachedMemoryVideosDir != null) return;
  final dir = await getApplicationDocumentsDirectory();
  final videosDir = Directory('${dir.path}/memory_videos');
  if (!await videosDir.exists()) {
    await videosDir.create(recursive: true);
  }
  final thumbsDir = Directory('${videosDir.path}/thumbs');
  if (!await thumbsDir.exists()) {
    await thumbsDir.create(recursive: true);
  }
  _cachedMemoryVideosDir = videosDir.path;
}

void setMemoryVideosDirectoryCacheForTest(String path) {
  _cachedMemoryVideosDir = path;
}

void resetMemoryVideosDirectoryCacheForTest() {
  _cachedMemoryVideosDir = null;
}

String thumbPathForVideoFile(String videoPath) {
  final file = File(videoPath);
  final base = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '');
  final parent = file.parent.path;
  return '$parent/thumbs/$base.jpg';
}

List<String> diskVideoPathsForMemoryId(String memoryId) {
  final dir = _cachedMemoryVideosDir;
  if (dir == null || memoryId.isEmpty) return const [];

  final paths = <String>[];
  for (var i = 0; i < 32; i++) {
    final indexed = File('$dir/${memoryId}_$i.mp4');
    if (!indexed.existsSync()) {
      if (i > 0) break;
      continue;
    }
    paths.add(indexed.path);
  }
  return paths;
}

List<String> resolvedVideoPathsForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final merged = <String>[];
  final seen = <String>{};

  void addPath(String path) {
    if (path.isEmpty || !seen.add(path)) return;
    if (File(path).existsSync()) merged.add(path);
  }

  for (final path in paths[memoryId] ?? const []) {
    addPath(path);
  }
  for (final path in diskVideoPathsForMemoryId(memoryId)) {
    addPath(path);
  }
  return merged;
}

String? primaryVideoPathForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final list = resolvedVideoPathsForMemoryId(memoryId, paths);
  return list.isEmpty ? null : list.first;
}

String? primaryVideoThumbPathForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final video = primaryVideoPathForMemoryId(memoryId, paths);
  if (video == null) return null;
  final thumb = thumbPathForVideoFile(video);
  return File(thumb).existsSync() ? thumb : null;
}

int videoCountForMemoryId(String memoryId, Map<String, List<String>> paths) {
  return resolvedVideoPathsForMemoryId(memoryId, paths).length;
}

/// 관계망·타임라인용: 사진 썸네일 우선, 없으면 동영상 썸네일.
String? primaryMediaThumbForMemoryId(
  String memoryId,
  Map<String, List<String>> imagePaths,
  Map<String, List<String>> videoPaths,
) {
  final photo = primaryImagePathForMemoryId(memoryId, imagePaths);
  if (photo != null) return photo;

  for (final video in resolvedVideoPathsForMemoryId(memoryId, videoPaths)) {
    final thumb = thumbPathForVideoFile(video);
    if (File(thumb).existsSync()) return thumb;
  }
  return null;
}

bool memoryHasVideo(String memoryId, Map<String, List<String>> videoPaths) {
  return resolvedVideoPathsForMemoryId(memoryId, videoPaths).isNotEmpty;
}
