import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/services/widget_theme_palette.dart';

void main() {
  test('light and dark palettes differ for buttons', () {
    const seed = Color(0xFF6750A4);
    final dark = WidgetThemePalette.fromSeed(seed, Brightness.dark);
    final light = WidgetThemePalette.fromSeed(seed, Brightness.light);

    expect(dark.btnPrimary, isNot(equals(light.btnPrimary)));
    expect(dark.bgTop, isNot(equals(light.bgTop)));
    expect(dark.btnSecondary, isNot(equals(light.btnSecondary)));
  });
}
