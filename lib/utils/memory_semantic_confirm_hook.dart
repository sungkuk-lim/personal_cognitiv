import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/memory/memory_semantic_confirm_sheet.dart';
import '../models/memory.dart';
import '../providers/memory_notifier.dart';
import '../utils/memory_graph_semantics.dart';

/// 저장 후 인원 불일치가 감지되면 보완 입력을 요청하고, 있으면 기억을 갱신합니다.
Future<void> handleSemanticQuantityAfterSave(
  BuildContext context,
  WidgetRef ref,
  Memory saved, {
  required String localeCode,
}) async {
  if (!context.mounted) return;
  final extra = await maybePromptSemanticQuantityGap(context, saved, localeCode: localeCode);
  if (extra == null || extra.isEmpty || !context.mounted) return;

  final merged = saved.copyWith(content: '${saved.content.trim()}\n$extra'.trim());
  final enriched = enrichMemoryGraphSemantics(merged, localeCode: localeCode);
  await ref.read(memoryListProvider.notifier).updateMemory(enriched);
}
