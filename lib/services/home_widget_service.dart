import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/memory.dart';
import '../providers/app_launch_provider.dart';
import 'widget_theme_palette.dart';

/// Android 홈 화면 "Memory Pulse" 위젯 — 최신 기억 미리보기 + 원탭 캡처/검색.
class HomeWidgetService {
  HomeWidgetService._();

  static const androidProvider =
      'com.theNext.personal_cognitive.MemoryPulseWidgetProvider';

  static Future<void> initialize(void Function(Uri? uri) onWidgetTap) async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.setAppGroupId('group.com.theNext.personal_cognitive');
      HomeWidget.widgetClicked.listen(onWidgetTap);
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) onWidgetTap(initial);
    } catch (e, stack) {
      debugPrint('HomeWidget init: $e\n$stack');
    }
  }

  /// 앱 테마 시드·밝기에 맞춘 Material 3 위젯 팔레트를 저장합니다.
  static Future<void> saveThemeColors(
    Color seedColor, {
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    final brightness = resolveHomeWidgetBrightness(themeMode);
    await WidgetThemePalette.fromSeed(seedColor, brightness).saveToHomeWidget();
  }

  static Future<void> syncMemories(
    List<Memory> memories, {
    String localeCode = 'ko',
    Color? seedColor,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final latest = memories.isNotEmpty ? memories.first : null;
      final empty = localeCode == 'ko' ? '마이크로 첫 기억을 남겨 보세요' : 'Tap mic to save your first memory';
      final title = localeCode == 'ko' ? '모담넷' : 'MemoryOS';
      final countLabel = localeCode == 'ko' ? '${memories.length}개 기억' : '${memories.length} memories';

      String timeLabel = '';
      if (latest != null) {
        final fmt = localeCode == 'ko'
            ? DateFormat('M월 d일 HH:mm', 'ko')
            : DateFormat('MMM d, HH:mm', 'en');
        timeLabel = fmt.format(latest.createdAt);
      }

      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_count', countLabel);
      await HomeWidget.saveWidgetData<String>(
        'widget_latest',
        latest?.summary.isNotEmpty == true ? latest!.summary : (latest?.content ?? empty),
      );
      await HomeWidget.saveWidgetData<String>('widget_time', timeLabel);
      await HomeWidget.saveWidgetData<String>(
        'widget_mic_label',
        localeCode == 'ko' ? '기억 저장' : 'Save',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_search_label',
        localeCode == 'ko' ? '검색' : 'Search',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_graph_label',
        localeCode == 'ko' ? '관계망' : 'Graph',
      );

      if (seedColor != null) {
        await saveThemeColors(seedColor, themeMode: themeMode);
      }

      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e, stack) {
      debugPrint('HomeWidget sync: $e\n$stack');
    }
  }

  /// 테마 색만 바꿨을 때 위젯 배경을 즉시 반영합니다.
  static Future<void> refreshTheme(Color seedColor, {ThemeMode themeMode = ThemeMode.system}) async {
    if (!Platform.isAndroid) return;
    try {
      await saveThemeColors(seedColor, themeMode: themeMode);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e, stack) {
      debugPrint('HomeWidget theme: $e\n$stack');
    }
  }
}

void handleWidgetUri(Uri? uri, void Function(AppLaunchTarget target) apply) {
  final target = appLaunchTargetFromUri(uri);
  if (target != AppLaunchTarget.none) apply(target);
}
