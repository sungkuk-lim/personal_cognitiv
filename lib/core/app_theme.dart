import 'package:flutter/material.dart';

/// 모담넷(MemoryOS) 디자인 시스템 — 타이포·색·컴포넌트 1세트.
abstract final class AppTheme {
  static const double radiusSheet = 24;
  static const double radiusCard = 16;
  static const double radiusChip = 12;

  static ThemeData theme({required Color seed, required Brightness brightness}) {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: seed, brightness: brightness);
    final scheme = base.colorScheme;
    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusChip)),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusChip)),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusChip)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.55),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusChip), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusChip)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  /// 그래프 노드 카드 — 최소 가독 크기(접근성) 유지.
  static TextStyle graphNodeTitle(BuildContext context, {bool onPhoto = false, bool primary = false}) {
    final theme = Theme.of(context);
    final color = onPhoto ? Colors.white : theme.colorScheme.onSurface;
    return (primary ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)!.copyWith(
      fontSize: primary ? 12 : 11,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: onPhoto ? Colors.white : color,
    );
  }

  static TextStyle graphNodeMeta(BuildContext context, {bool onPhoto = false}) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
          fontSize: 10,
          height: 1.2,
          color: onPhoto ? Colors.white.withValues(alpha: 0.9) : Theme.of(context).colorScheme.onSurfaceVariant,
        );
  }
}

/// 관계망 노드·엣지 색 — 앱 시드와 조화되는 고정 팔레트.
abstract final class AppGraphColors {
  static const person = Color(0xFFE91E63);
  static const place = Color(0xFF00897B);
  static const activity = Color(0xFF7E57C2);
  static const event = Color(0xFF673AB7);
  static const content = Color(0xFF42A5F5);
  static const interest = Color(0xFFFF9800);
  static const pet = Color(0xFF8D6E63);
  static const food = Color(0xFFFF5722);
  static const hobby = Color(0xFF009688);
  static const organization = Color(0xFF455A64);
  static const memory = Color(0xFF5C6BC0);
  static const group = Color(0xFF546E7A);
  static const eventHub = Color(0xFF5C6BC0);
  static const semanticEdge = Color(0xFF7E57C2);
  static const relationEdge = Color(0xFF2E7D32);
  static const bridgeEdge = Color(0xFFFFB300);
  static const selfPerson = Color(0xFF7986CB);
}
