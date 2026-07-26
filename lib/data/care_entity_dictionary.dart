/// 도메인 엔티티 사전 — 병원·진료과·STT 보정 (내부 파이프라인용).
/// 사용자/기관별 항목은 [merge]로 확장 (prefs·동기화 연동 예정).
class CareEntityDictionary {
  const CareEntityDictionary({
    this.hospitals = const {},
    this.departments = const {},
    this.patientNames = const {},
    this.sttTypoMap = const {},
  });

  final Set<String> hospitals;
  final Set<String> departments;
  final Set<String> patientNames;
  final Map<String, String> sttTypoMap;

  static CareEntityDictionary seed() {
    return const CareEntityDictionary(
      hospitals: {
        '대성그린병원',
        '성소병원',
        '안동병원',
        '서울아산병원',
        '세브란스병원',
        '삼성서울병원',
      },
      departments: {
        '안과', '치과', '정형외과', '소화기내과', '신경과', '피부과', '내과', '외과',
        '산부인과', '소아과', '이비인후과', '비뇨기과', '영상의학과', '재활의학과',
      },
      sttTypoMap: {
        '성수병원': '성소병원',
        '성서병원': '성소병원',
        '성소 병원': '성소병원',
        '안동 병원': '안동병원',
        '대성 그린병원': '대성그린병원',
        '정형 회과': '정형외과',
        '정형외 과': '정형외과',
        '소화기 내과': '소화기내과',
      },
    );
  }

  CareEntityDictionary merge({
    Iterable<String>? hospitals,
    Iterable<String>? departments,
    Iterable<String>? patientNames,
    Map<String, String>? sttTypoMap,
  }) {
    return CareEntityDictionary(
      hospitals: {...this.hospitals, ...?hospitals},
      departments: {...this.departments, ...?departments},
      patientNames: {...this.patientNames, ...?patientNames},
      sttTypoMap: {...this.sttTypoMap, ...?sttTypoMap},
    );
  }
}

/// 편집 거리 — 짧은 한글 병원명 오타 보정용.
int careNameEditDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final m = a.length;
  final n = b.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[m][n];
}

class DictionaryLookupResult {
  const DictionaryLookupResult({
    required this.raw,
    required this.value,
    required this.matched,
    this.confidence = 1.0,
    this.needsUserConfirm = false,
  });

  final String raw;
  final String value;
  final bool matched;
  final double confidence;
  final bool needsUserConfirm;
}

DictionaryLookupResult lookupHospital(String raw, CareEntityDictionary dict) {
  final v = raw.trim();
  if (v.isEmpty) {
    return const DictionaryLookupResult(raw: '', value: '', matched: false);
  }
  if (dict.sttTypoMap.containsKey(v)) {
    final corrected = dict.sttTypoMap[v]!;
    return DictionaryLookupResult(
      raw: v,
      value: corrected,
      matched: true,
      confidence: 0.95,
    );
  }
  if (dict.hospitals.contains(v)) {
    return DictionaryLookupResult(raw: v, value: v, matched: true, confidence: 1.0);
  }
  String? best;
  var bestDist = 999;
  for (final h in dict.hospitals) {
    final d = careNameEditDistance(v, h);
    if (d < bestDist) {
      bestDist = d;
      best = h;
    }
  }
  if (best != null && bestDist <= 2 && v.length >= 3) {
    return DictionaryLookupResult(
      raw: v,
      value: best,
      matched: true,
      confidence: bestDist == 0 ? 1.0 : 0.82,
      needsUserConfirm: bestDist > 0,
    );
  }
  return DictionaryLookupResult(raw: v, value: v, matched: false, confidence: 0.5);
}

DictionaryLookupResult lookupDepartment(String raw, CareEntityDictionary dict) {
  final v = raw.trim();
  if (v.isEmpty) {
    return const DictionaryLookupResult(raw: '', value: '', matched: false);
  }
  if (dict.sttTypoMap.containsKey(v)) {
    return DictionaryLookupResult(raw: v, value: dict.sttTypoMap[v]!, matched: true, confidence: 0.95);
  }
  if (dict.departments.contains(v)) {
    return DictionaryLookupResult(raw: v, value: v, matched: true);
  }
  for (final d in dict.departments) {
    if (v.contains(d) || d.contains(v)) {
      return DictionaryLookupResult(raw: v, value: d, matched: true, confidence: 0.9);
    }
  }
  return DictionaryLookupResult(raw: v, value: v, matched: false, confidence: 0.5);
}
