import 'package:flutter/material.dart';

import '../models/memory.dart';
import 'memory_input_category.dart';

/// 관계망 맥락 렌즈 — 입력 카테고리와 동일한 축으로 그래프를 좁혀 봅니다.
enum GraphContextLens {
  all,
  general,
  family,
  lover,
  friend,
  pet,
  company,
  study,
  travel,
}

extension GraphContextLensX on GraphContextLens {
  String get prefValue => name;

  /// `memoryInputCategories`의 id. [all]·[general]은 null.
  String? get inputCategoryId => switch (this) {
        GraphContextLens.all || GraphContextLens.general => null,
        GraphContextLens.family => 'family',
        GraphContextLens.lover => 'lover',
        GraphContextLens.friend => 'friend',
        GraphContextLens.pet => 'pet',
        GraphContextLens.company => 'company',
        GraphContextLens.study => 'study',
        GraphContextLens.travel => 'travel',
      };

  IconData get icon => switch (this) {
        GraphContextLens.all => Icons.hub_outlined,
        GraphContextLens.general => Icons.layers_outlined,
        GraphContextLens.family => Icons.family_restroom_rounded,
        GraphContextLens.lover => Icons.favorite_rounded,
        GraphContextLens.friend => Icons.people_rounded,
        GraphContextLens.pet => Icons.pets_rounded,
        GraphContextLens.company => Icons.business_center_rounded,
        GraphContextLens.study => Icons.school_rounded,
        GraphContextLens.travel => Icons.flight_takeoff_rounded,
      };

  static GraphContextLens fromPref(String? raw) {
    if (raw == null || raw.isEmpty) return GraphContextLens.all;
    return GraphContextLens.values.firstWhere(
      (lens) => lens.name == raw,
      orElse: () => GraphContextLens.all,
    );
  }

  String labelFor(String localeCode, Map<String, String> t) {
    return switch (this) {
      GraphContextLens.all => t['graph_lens_all']!,
      GraphContextLens.general => t['graph_lens_general']!,
      _ => memoryInputCategoryById(inputCategoryId)?.labelFor(localeCode) ?? name,
    };
  }
}

/// 입력 시 고른 맥락(subCategory)과 일치하는지 봅니다.
bool memoryMatchesInputCategory(Memory memory, MemoryInputCategory category, String localeCode) {
  final sub = memory.subCategory.trim();
  if (sub.isEmpty) return false;
  return sub == category.subCategoryFor(localeCode);
}

bool memoryHasKnownInputContext(Memory memory, String localeCode) {
  final sub = memory.subCategory.trim();
  if (sub.isEmpty) return false;
  for (final category in memoryInputCategories) {
    if (sub == category.subCategoryFor(localeCode)) return true;
  }
  return false;
}

bool memoryMatchesGraphLens(Memory memory, GraphContextLens lens, String localeCode) {
  switch (lens) {
    case GraphContextLens.all:
      return true;
    case GraphContextLens.general:
      return !memoryHasKnownInputContext(memory, localeCode);
    default:
      final categoryId = lens.inputCategoryId;
      final category = memoryInputCategoryById(categoryId);
      if (category == null) return true;
      return memoryMatchesInputCategory(memory, category, localeCode);
  }
}

List<Memory> filterMemoriesForGraphLens(
  List<Memory> memories,
  GraphContextLens lens,
  String localeCode,
) {
  if (lens == GraphContextLens.all) return memories;
  return memories.where((m) => memoryMatchesGraphLens(m, lens, localeCode)).toList();
}
