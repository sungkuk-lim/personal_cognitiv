import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/memory_relative_date.dart';

/// 말속 「어제」 등과 입력 시각이 다를 때 날짜 조정을 제안합니다.
Future<bool?> showMemoryDateConfirmSheet(
  BuildContext context, {
  required int dayOffset,
  required DateTime currentCreatedAt,
  required String localeCode,
}) {
  final label = relativeDayLabel(dayOffset, localeCode);
  final proposed = applyRelativeDayOffset(currentCreatedAt, dayOffset);
  final dateFmt = localeCode == 'ko'
      ? DateFormat('M월 d일 (E)', 'ko')
      : DateFormat('MMM d (EEE)', 'en');
  final proposedText = dateFmt.format(proposed);

  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      final isKo = localeCode == 'ko';
      final title = isKo ? '이 기억의 날짜를 맞출까요?' : 'Adjust the memory date?';
      final body = isKo
          ? '내용에 「$label」이 들어 있어요. 타임라인 날짜를 $proposedText 로 맞출까요?'
          : 'Your note mentions "$label". Set the timeline date to $proposedText?';
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isKo ? '$proposedText 로 저장' : 'Use $proposedText'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isKo ? '입력한 지금 날짜 유지' : 'Keep today\'s date'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
