import 'package:flutter/material.dart';

import 'app_locales.dart';
import 'generated_catalogs.dart';

/// 테스트·하위 호환용. 실제 소스는 [generatedLocaleCatalogs].
Map<String, Map<String, String>> get translationsData => generatedLocaleCatalogs;

/// 선택 언어 카탈로그 + 영어 fallback.
Map<String, String> translationsFor(Locale locale) {
  final id = localeIdFromLocale(locale);
  final en = generatedLocaleCatalogs['en'] ?? const <String, String>{};
  final specific = generatedLocaleCatalogs[id];
  if (specific == null || specific.isEmpty) {
    return Map<String, String>.from(
      generatedLocaleCatalogs['ko'] ?? en,
    );
  }
  if (id == 'en') return Map<String, String>.from(specific);
  // 누락 키는 영어로 메워 글로벌 출시 중에도 UI가 비지 않게 합니다.
  return {...en, ...specific};
}
