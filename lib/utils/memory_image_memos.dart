import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';

List<String> photoMemosForMemoryId(
  String memoryId,
  Map<String, List<String>> memos, {
  Memory? memory,
  int photoCount = 0,
}) {
  final stored = List<String>.from(memos[memoryId] ?? const []);
  final fallbackMemo = memory != null ? displayUserMemoForMemory(memory) : '';
  if (stored.isEmpty && fallbackMemo.isNotEmpty) {
    if (photoCount <= 1) return [fallbackMemo];
    return [fallbackMemo, ...List.filled(photoCount - 1, '')];
  }
  if (photoCount > stored.length) {
    stored.addAll(List.filled(photoCount - stored.length, ''));
  }
  return stored;
}

String displayMemoForMemory(Memory memory, Map<String, List<String>> memos, {int photoCount = 0}) {
  for (final memo in photoMemosForMemoryId(memory.id, memos, memory: memory, photoCount: photoCount)) {
    if (memo.trim().isNotEmpty) return memo.trim();
  }
  return '';
}

Future<void> setPhotoMemoAtIndex(
  SharedPreferences prefs,
  Map<String, List<String>> memos,
  String memoryId,
  int index,
  String memo,
) async {
  final list = List<String>.from(memos[memoryId] ?? const []);
  while (list.length <= index) {
    list.add('');
  }
  list[index] = memo.trim();
  memos[memoryId] = list;
  await saveMemoryImageMemos(prefs, memos);
}

Future<void> appendPhotoMemo(
  SharedPreferences prefs,
  Map<String, List<String>> memos,
  String memoryId,
  String memo,
) async {
  final list = List<String>.from(memos[memoryId] ?? const []);
  list.add(memo.trim());
  memos[memoryId] = list;
  await saveMemoryImageMemos(prefs, memos);
}
