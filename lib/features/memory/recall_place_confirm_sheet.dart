import 'package:flutter/material.dart';

enum RecallPlaceChoice { storyPlace, captureHere, disableRecall }

/// 이야기 장소와 입력 GPS가 다를 때 타임라인·회상 공통 장소를 고릅니다.
Future<RecallPlaceChoice?> showRecallPlaceConfirmSheet(
  BuildContext context, {
  required String storyPlaceLabel,
  required String capturePlaceLabel,
}) {
  return showModalBottomSheet<RecallPlaceChoice>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      final t = _RecallPlaceSheetCopy.of(Localizations.localeOf(ctx).languageCode);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                t.body.replaceAll('{story}', storyPlaceLabel).replaceAll('{here}', capturePlaceLabel),
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, RecallPlaceChoice.storyPlace),
                icon: const Icon(Icons.place_outlined),
                label: Text(t.storyButton.replaceAll('{story}', storyPlaceLabel)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, RecallPlaceChoice.captureHere),
                icon: const Icon(Icons.my_location_outlined),
                label: Text(t.hereButton.replaceAll('{here}', capturePlaceLabel)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, RecallPlaceChoice.disableRecall),
                child: Text(t.skipButton),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RecallPlaceSheetCopy {
  const _RecallPlaceSheetCopy({
    required this.title,
    required this.body,
    required this.storyButton,
    required this.hereButton,
    required this.skipButton,
  });

  final String title;
  final String body;
  final String storyButton;
  final String hereButton;
  final String skipButton;

  static _RecallPlaceSheetCopy of(String localeCode) {
    if (localeCode == 'ko') {
      return const _RecallPlaceSheetCopy(
        title: '이 기억의 장소는 어디인가요?',
        body: '지금 위치는 「{here}」인데, 기억 내용은 「{story}」에 관한 것 같아요. 타임라인·회상 알림에 쓸 장소를 골라 주세요.',
        storyButton: '{story} (추천)',
        hereButton: '지금 여기 — {here}',
        skipButton: '장소 없이 저장',
      );
    }
    return const _RecallPlaceSheetCopy(
      title: 'Where did this memory happen?',
      body: 'You are near "{here}" but this memory seems to be about "{story}". Choose the place for timeline and recall alerts.',
      storyButton: '{story} (recommended)',
      hereButton: 'Here — {here}',
      skipButton: 'Save without a place',
    );
  }
}
