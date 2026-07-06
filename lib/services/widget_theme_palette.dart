import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// 홈 위젯 Material 3 팔레트 — 배경·버튼·텍스트 (라이트/다크).
class WidgetThemePalette {
  const WidgetThemePalette({
    required this.bgTop,
    required this.bgBottom,
    required this.btnPrimary,
    required this.btnSecondary,
    required this.btnPrimaryOn,
    required this.btnSecondaryOn,
    required this.graphChipBg,
    required this.graphChipOn,
    required this.countChipBg,
    required this.countChipOn,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textCard,
    required this.textCardMuted,
    required this.isDark,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color btnPrimary;
  final Color btnSecondary;
  final Color btnPrimaryOn;
  final Color btnSecondaryOn;
  final Color graphChipBg;
  final Color graphChipOn;
  final Color countChipBg;
  final Color countChipOn;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textCard;
  final Color textCardMuted;
  final bool isDark;

  static WidgetThemePalette fromSeed(Color seedColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

    final bgTop = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.34 : 0.12),
      scheme.surface,
    );
    final bgBottom = Color.alphaBlend(
      scheme.primaryContainer.withValues(alpha: isDark ? 0.22 : 0.10),
      isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
    );

    final btnPrimary = scheme.primary;
    final btnSecondary = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
      scheme.surfaceContainerHigh,
    );

    final graphChipBg = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
      scheme.surfaceContainerHighest,
    );

    return WidgetThemePalette(
      bgTop: bgTop,
      bgBottom: bgBottom,
      btnPrimary: btnPrimary,
      btnSecondary: btnSecondary,
      btnPrimaryOn: scheme.onPrimary,
      btnSecondaryOn: scheme.onSurface,
      graphChipBg: graphChipBg,
      graphChipOn: scheme.onSurface,
      countChipBg: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.58 : 0.94),
      countChipOn: scheme.onSurfaceVariant,
      cardBg: isDark ? const Color(0x1FFFFFFF) : scheme.surface.withValues(alpha: 0.90),
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurface.withValues(alpha: isDark ? 0.72 : 0.68),
      textCard: scheme.onSurface.withValues(alpha: isDark ? 0.95 : 0.92),
      textCardMuted: scheme.onSurface.withValues(alpha: isDark ? 0.50 : 0.55),
      isDark: isDark,
    );
  }

  Future<void> saveToHomeWidget() async {
    Future<void> put(String key, Color color) =>
        HomeWidget.saveWidgetData<int>(key, color.toARGB32());

    await put('widget_bg_color', bgTop);
    await put('widget_bg_color_end', bgBottom);
    await put('widget_accent_color', btnPrimary);
    await put('widget_btn_primary_color', btnPrimary);
    await put('widget_btn_secondary_color', btnSecondary);
    await put('widget_btn_primary_on_color', btnPrimaryOn);
    await put('widget_btn_secondary_on_color', btnSecondaryOn);
    await put('widget_graph_chip_bg', graphChipBg);
    await put('widget_graph_chip_on', graphChipOn);
    await put('widget_count_chip_bg', countChipBg);
    await put('widget_count_chip_on', countChipOn);
    await put('widget_card_bg', cardBg);
    await put('widget_text_primary', textPrimary);
    await put('widget_text_secondary', textSecondary);
    await put('widget_text_card', textCard);
    await put('widget_text_card_muted', textCardMuted);
    await HomeWidget.saveWidgetData<int>('widget_is_dark', isDark ? 1 : 0);
  }
}

Brightness resolveHomeWidgetBrightness(ThemeMode themeMode) {
  return switch (themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => PlatformDispatcher.instance.platformBrightness,
  };
}
