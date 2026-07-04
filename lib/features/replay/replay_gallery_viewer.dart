import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../memory/memory_media_viewer.dart';

/// 회상 갤러리 모드: 상세 시트 없이 사진·동영상 확대·슬라이드.
void showReplayGalleryViewer(
  BuildContext context, {
  required Memory memory,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> imageMemos,
  required Map<String, List<String>> videoPaths,
  int initialIndex = 0,
  String? swipeHint,
}) {
  showMemoryMediaViewer(
    context,
    memory: memory,
    imagePaths: imagePaths,
    imageMemos: imageMemos,
    videoPaths: videoPaths,
    initialIndex: initialIndex,
    swipeHint: swipeHint,
  );
}
