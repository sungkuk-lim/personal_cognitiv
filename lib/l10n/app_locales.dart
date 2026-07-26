import 'package:flutter/material.dart';

/// 앱에서 선택 가능한 언어 목록 (글로벌 출시용).
class AppLocaleOption {
  final String id;
  final Locale locale;
  final String flag;
  final String nativeLabel;

  const AppLocaleOption({
    required this.id,
    required this.locale,
    required this.flag,
    required this.nativeLabel,
  });

  String get menuLabel => '$flag $nativeLabel';
}

const List<AppLocaleOption> kAppLocaleOptions = [
  AppLocaleOption(
    id: 'en',
    locale: Locale('en'),
    flag: '🇺🇸',
    nativeLabel: 'English',
  ),
  AppLocaleOption(
    id: 'ko',
    locale: Locale('ko'),
    flag: '🇰🇷',
    nativeLabel: '한국어',
  ),
  AppLocaleOption(
    id: 'ja',
    locale: Locale('ja'),
    flag: '🇯🇵',
    nativeLabel: '日本語',
  ),
  AppLocaleOption(
    id: 'zh_Hans',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    flag: '🇨🇳',
    nativeLabel: '简体中文',
  ),
  AppLocaleOption(
    id: 'zh_Hant',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    flag: '🇹🇼',
    nativeLabel: '繁體中文',
  ),
  AppLocaleOption(
    id: 'es',
    locale: Locale('es'),
    flag: '🇪🇸',
    nativeLabel: 'Español',
  ),
  AppLocaleOption(
    id: 'fr',
    locale: Locale('fr'),
    flag: '🇫🇷',
    nativeLabel: 'Français',
  ),
  AppLocaleOption(
    id: 'de',
    locale: Locale('de'),
    flag: '🇩🇪',
    nativeLabel: 'Deutsch',
  ),
  AppLocaleOption(
    id: 'pt_BR',
    locale: Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR'),
    flag: '🇧🇷',
    nativeLabel: 'Português (Brasil)',
  ),
  AppLocaleOption(
    id: 'vi',
    locale: Locale('vi'),
    flag: '🇻🇳',
    nativeLabel: 'Tiếng Việt',
  ),
];

/// SharedPreferences / UI에서 쓰는 locale id.
String localeIdFromLocale(Locale locale) {
  final language = locale.languageCode.toLowerCase();
  final script = locale.scriptCode;
  final country = locale.countryCode;

  if (language == 'zh') {
    if (script == 'Hant' || country == 'TW' || country == 'HK' || country == 'MO') {
      return 'zh_Hant';
    }
    return 'zh_Hans';
  }
  if (language == 'pt' && (country == null || country.isEmpty || country == 'BR')) {
    // 앱에서는 브라질 포르투갈어를 기본으로 사용.
    return 'pt_BR';
  }

  for (final option in kAppLocaleOptions) {
    if (option.locale.languageCode == language &&
        option.locale.scriptCode == script &&
        option.locale.countryCode == country) {
      return option.id;
    }
  }

  for (final option in kAppLocaleOptions) {
    if (option.id == language) return option.id;
  }
  return 'en';
}

Locale localeFromId(String id) {
  final normalized = id.trim();
  for (final option in kAppLocaleOptions) {
    if (option.id == normalized) return option.locale;
  }
  // 구버전 호환: 'zh' → 간체
  if (normalized == 'zh') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
  if (normalized == 'pt') {
    return const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR');
  }
  if (normalized.length >= 2) {
    return Locale(normalized.substring(0, 2));
  }
  return const Locale('en');
}

AppLocaleOption? appLocaleOptionForId(String id) {
  for (final option in kAppLocaleOptions) {
    if (option.id == id) return option;
  }
  return null;
}

List<Locale> get kSupportedLocales =>
    kAppLocaleOptions.map((e) => e.locale).toList(growable: false);
