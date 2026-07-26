import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/l10n/app_locales.dart';
import 'package:personal_cognitive/l10n/translations.dart';

void main() {
  test('supports the 10 global language options', () {
    expect(kAppLocaleOptions.map((e) => e.id).toList(), [
      'en',
      'ko',
      'ja',
      'zh_Hans',
      'zh_Hant',
      'es',
      'fr',
      'de',
      'pt_BR',
      'vi',
    ]);
    expect(kAppLocaleOptions.map((e) => e.menuLabel).toList(), [
      '🇺🇸 English',
      '🇰🇷 한국어',
      '🇯🇵 日本語',
      '🇨🇳 简体中文',
      '🇹🇼 繁體中文',
      '🇪🇸 Español',
      '🇫🇷 Français',
      '🇩🇪 Deutsch',
      '🇧🇷 Português (Brasil)',
      '🇻🇳 Tiếng Việt',
    ]);
  });

  test('locale id round-trips for script and country variants', () {
    expect(localeIdFromLocale(const Locale('ja')), 'ja');
    expect(
      localeIdFromLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')),
      'zh_Hans',
    );
    expect(
      localeIdFromLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
      'zh_Hant',
    );
    expect(
      localeIdFromLocale(const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR')),
      'pt_BR',
    );
    expect(localeFromId('zh_Hant').scriptCode, 'Hant');
    expect(localeFromId('pt_BR').countryCode, 'BR');
  });

  test('translations resolve for each supported locale', () {
    for (final option in kAppLocaleOptions) {
      final t = translationsFor(option.locale);
      expect(t['settings'], isNotEmpty, reason: option.id);
      expect(t['language'], isNotEmpty, reason: option.id);
      expect(t['stream'], isNotEmpty, reason: option.id);
    }
    expect(translationsFor(const Locale('ja'))['settings'], isNot(equals('Settings')));
    expect(translationsFor(const Locale('ko'))['settings'], '설정');
  });
}
