import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../../utils/memory_quantity_validate.dart';

/// 저장 직후 인원 불일치가 있으면 확인 시트를 띄웁니다. 보완 텍스트가 있으면 반환합니다.
Future<String?> maybePromptSemanticQuantityGap(
  BuildContext context,
  Memory memory, {
  required String localeCode,
}) async {
  final report = quantityReportFromMemory(memory, localeCode: localeCode);
  if (report == null || !report.hasMismatch || !context.mounted) return null;

  final isKo = localeCode == 'ko';
  final controller = TextEditingController();
  final result = await showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(report.message, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: isKo ? '나머지 ${report.gap.abs()}명 정보를 입력해 주세요' : 'Enter the remaining ${report.gap.abs()}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(isKo ? '추가하고 다시 저장' : 'Add and save again'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isKo ? '이대로 두기' : 'Dismiss'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result is String && result.isNotEmpty ? result : null;
}
