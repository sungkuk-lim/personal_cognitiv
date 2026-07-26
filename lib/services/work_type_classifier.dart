import '../core/memory_work_type.dart';

/// ③ 업무 종류 분류 (로컬 규칙 우선 — AI 없이도 동작).
class WorkTypeClassifier {
  const WorkTypeClassifier._();

  static MemoryWorkType classify(String text) {
    final t = text.trim();
    if (t.isEmpty) return MemoryWorkType.general;

    if (_matchesHomeVisitMedical(t)) return MemoryWorkType.homeVisitMedical;
    if (_matchesTravel(t)) return MemoryWorkType.travel;
    if (_matchesSocial(t)) return MemoryWorkType.social;
    if (_matchesWork(t)) return MemoryWorkType.workGeneral;
    return MemoryWorkType.general;
  }

  static bool _matchesHomeVisitMedical(String t) {
    const keys = [
      '외진', '방문간호', '방문 간호', '환자', '병원', '진료과', '보호사', '간호사',
      '인솔', '내원', '외래', '총인원', '총 ',
    ];
    var score = 0;
    for (final k in keys) {
      if (t.contains(k)) score++;
    }
    return score >= 2 || RegExp(r'[가-힣]+병원').hasMatch(t) && t.contains('환자');
  }

  static bool _matchesTravel(String t) {
    return RegExp(r'여행|나들이|관광|출장').hasMatch(t);
  }

  static bool _matchesSocial(String t) {
    return RegExp(r'회식|모임|만났|함께|같이\s+밥|친구').hasMatch(t);
  }

  static bool _matchesWork(String t) {
    return RegExp(r'회의|미팅|업무|보고|프로젝트').hasMatch(t);
  }
}
