import 'korean_person_names.dart';

/// 진료과·의료 시설·역할 토큰 — 인물/장소 분류용.
const kMedicalDepartmentSuffixPattern =
    r'(?:내과|외과|치과|안과|정형외과|소화기내과|신경과|피부과|산부인과|소아과|이비인후과|비뇨기과|영상의학과|재활의학과|응급의학과)';

const Set<String> kMedicalDepartmentLabels = {
  '안과', '치과', '정형외과', '소화기내과', '신경과', '피부과', '산부인과', '소아과',
  '이비인후과', '비뇨기과', '영상의학과', '재활의학과', '내과', '외과', '응급의학과',
};

const Set<String> kMedicalRoleTokens = {
  '환자', '보호사', '간호사', '의사', '담당자', '간호과장', '간호팀장',
};

const Set<String> kMedicalReportingNoiseTokens = {
  '외진현황', '외진현황으로', '외진현황으로는', '현황보고', '현황으로', '현황', '보고로는',
  '외진했습니다', '외진했', '진료했습니다',
};

final RegExp _medicalDepartmentPattern = RegExp(
  '^[가-힣A-Za-z0-9]{0,12}$kMedicalDepartmentSuffixPattern\$',
);

final RegExp _medicalFacilityPattern = RegExp(
  r'(?:병원|의원|클리닉|센터|요양원)$',
);

/// 「정형외과」「안과」 등 진료과 라벨.
bool isMedicalDepartmentLabel(String raw) {
  final v = raw.trim().replaceAll(RegExp(r'[.,!?…·]+$'), '');
  if (v.isEmpty) return false;
  if (kMedicalDepartmentLabels.contains(v)) return true;
  return _medicalDepartmentPattern.hasMatch(v);
}

/// 「안동병원」「대성그린병원」 등 의료 시설.
bool isMedicalFacilityLabel(String raw) {
  final v = raw.trim().replaceAll(RegExp(r'[.,!?…·]+$'), '');
  if (v.isEmpty || v.length > 28) return false;
  return _medicalFacilityPattern.hasMatch(v);
}

bool isMedicalRoleToken(String raw) {
  final v = stripTrailingKoreanParticles(raw.trim());
  return kMedicalRoleTokens.contains(v);
}

/// 「외진현황으로…」「환자는 안동병원」 등 구문 덩어리.
bool isMedicalGraphNoisePhrase(String raw) {
  final v = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (v.isEmpty) return false;
  if (kMedicalReportingNoiseTokens.contains(v)) return true;
  if (RegExp(r'외진현황|현황\s*보고|보고로는|으로는\s*총').hasMatch(v)) return true;
  if (RegExp(r'^환자는\s').hasMatch(v)) return true;
  if (RegExp(r'환자는\s+[가-힣A-Za-z0-9]+병원').hasMatch(v)) return true;
  if (v.contains(' ') && v.length > 10 && RegExp(r'(?:환자|외진|현황|보고)').hasMatch(v)) {
    return true;
  }
  return false;
}

/// 인물 후보에서 제외할 의료·행정 토큰.
bool isMedicalNonPersonToken(String raw) {
  final v = stripTrailingKoreanParticles(raw.trim());
  if (v.isEmpty) return false;
  if (isMedicalDepartmentLabel(v)) return true;
  if (isMedicalFacilityLabel(v)) return true;
  if (isMedicalRoleToken(v)) return true;
  if (isMedicalGraphNoisePhrase(v)) return true;
  if (kMedicalReportingNoiseTokens.contains(v)) return true;
  if (v == '정형외' || v == '소화기' || v == '소화기내') return true;
  return false;
}

/// 관계망·키워드에서 장소(물리적 위치)로 취급.
bool isMedicalPlaceLikeLabel(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return false;
  if (isMedicalGraphNoisePhrase(v)) return false;
  return isMedicalDepartmentLabel(v) || isMedicalFacilityLabel(v);
}

/// 본문에서 병원·진료과 토큰만 추출 (구문 덩어리 제외).
List<String> extractMedicalPlaceTokens(String text) {
  final results = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty || !seen.add(v)) return;
    if (isMedicalGraphNoisePhrase(v)) return;
    if (isMedicalFacilityLabel(v) || isMedicalDepartmentLabel(v)) {
      results.add(v);
    }
  }

  for (final m in RegExp(r'([가-힣A-Za-z0-9]{2,24}(?:병원|의원|클리닉))').allMatches(text)) {
    add(m.group(1));
  }
  for (final m in RegExp('([가-힣A-Za-z0-9]{1,12}$kMedicalDepartmentSuffixPattern)(?:에|에서|의)').allMatches(text)) {
    add(m.group(1));
  }
  return results;
}
