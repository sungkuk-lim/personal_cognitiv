/// 타임라인·캡처 입력 전 사용자가 고르는 관계·맥락 카테고리.
class MemoryInputCategory {
  const MemoryInputCategory({
    required this.id,
    required this.labelKo,
    required this.labelEn,
    required this.memoryCategory,
    required this.subCategoryKo,
    required this.subCategoryEn,
    required this.iconName,
  });

  final String id;
  final String labelKo;
  final String labelEn;
  final String memoryCategory;
  final String subCategoryKo;
  final String subCategoryEn;
  final String iconName;

  String labelFor(String localeCode) => localeCode == 'ko' ? labelKo : labelEn;

  String subCategoryFor(String localeCode) => localeCode == 'ko' ? subCategoryKo : subCategoryEn;
}

const String kMemoryInputCategoryNone = 'none';

const List<MemoryInputCategory> memoryInputCategories = [
  MemoryInputCategory(
    id: 'family',
    labelKo: '가족',
    labelEn: 'Family',
    memoryCategory: 'Social',
    subCategoryKo: '가족',
    subCategoryEn: 'Family',
    iconName: 'family',
  ),
  MemoryInputCategory(
    id: 'lover',
    labelKo: '연인',
    labelEn: 'Partner',
    memoryCategory: 'Social',
    subCategoryKo: '연인',
    subCategoryEn: 'Partner',
    iconName: 'lover',
  ),
  MemoryInputCategory(
    id: 'friend',
    labelKo: '친구',
    labelEn: 'Friends',
    memoryCategory: 'Social',
    subCategoryKo: '친구',
    subCategoryEn: 'Friends',
    iconName: 'friend',
  ),
  MemoryInputCategory(
    id: 'pet',
    labelKo: '반려견/반려묘',
    labelEn: 'Pets',
    memoryCategory: 'Social',
    subCategoryKo: '반려견/반려묘',
    subCategoryEn: 'Pets',
    iconName: 'pet',
  ),
  MemoryInputCategory(
    id: 'company',
    labelKo: '회사',
    labelEn: 'Work',
    memoryCategory: 'Work',
    subCategoryKo: '회사',
    subCategoryEn: 'Work',
    iconName: 'company',
  ),
  MemoryInputCategory(
    id: 'study',
    labelKo: '공부',
    labelEn: 'Study',
    memoryCategory: 'Study',
    subCategoryKo: '공부',
    subCategoryEn: 'Study',
    iconName: 'study',
  ),
  MemoryInputCategory(
    id: 'travel',
    labelKo: '여행',
    labelEn: 'Travel',
    memoryCategory: 'Travel',
    subCategoryKo: '여행',
    subCategoryEn: 'Travel',
    iconName: 'travel',
  ),
];

MemoryInputCategory? memoryInputCategoryById(String? id) {
  if (id == null || id.isEmpty || id == kMemoryInputCategoryNone) return null;
  for (final item in memoryInputCategories) {
    if (item.id == id) return item;
  }
  return null;
}

/// 사용자가 고른 맥락을 기억 필드에 반영합니다.
({String category, String subCategory}) applyMemoryInputCategory({
  required String localeCode,
  required MemoryInputCategory? inputCategory,
  required String fallbackCategory,
  required String fallbackSubCategory,
}) {
  if (inputCategory == null) {
    return (category: fallbackCategory, subCategory: fallbackSubCategory);
  }
  return (
    category: inputCategory.memoryCategory,
    subCategory: inputCategory.subCategoryFor(localeCode),
  );
}
