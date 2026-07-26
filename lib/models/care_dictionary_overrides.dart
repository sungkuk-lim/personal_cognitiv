/// 사용자·기관이 추가한 사전 항목 (시드 데이터와 merge).
class CareDictionaryOverrides {
  const CareDictionaryOverrides({
    this.hospitals = const [],
    this.departments = const [],
    this.patientNames = const [],
    this.sttTypoMap = const {},
    this.updatedAt,
  });

  final List<String> hospitals;
  final List<String> departments;
  final List<String> patientNames;
  final Map<String, String> sttTypoMap;
  final DateTime? updatedAt;

  static const empty = CareDictionaryOverrides();

  CareDictionaryOverrides copyWith({
    List<String>? hospitals,
    List<String>? departments,
    List<String>? patientNames,
    Map<String, String>? sttTypoMap,
    DateTime? updatedAt,
  }) {
    return CareDictionaryOverrides(
      hospitals: hospitals ?? this.hospitals,
      departments: departments ?? this.departments,
      patientNames: patientNames ?? this.patientNames,
      sttTypoMap: sttTypoMap ?? this.sttTypoMap,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CareDictionaryOverrides.fromJson(Map<String, dynamic> json) {
    return CareDictionaryOverrides(
      hospitals: stringList(json['hospitals']),
      departments: stringList(json['departments']),
      patientNames: stringList(json['patient_names']),
      sttTypoMap: stringMap(json['stt_typo_map']),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  static List<String> stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  static Map<String, String> stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString().trim(), v.toString().trim()));
  }

  Map<String, dynamic> toJson() => {
        'hospitals': hospitals,
        'departments': departments,
        'patient_names': patientNames,
        'stt_typo_map': sttTypoMap,
        if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      };

  CareDictionaryOverrides mergeRemote(CareDictionaryOverrides remote) {
    if (remote.updatedAt != null &&
        updatedAt != null &&
        !remote.updatedAt!.isAfter(updatedAt!)) {
      return this;
    }
    return CareDictionaryOverrides(
      hospitals: {...hospitals, ...remote.hospitals}.toList()..sort(),
      departments: {...departments, ...remote.departments}.toList()..sort(),
      patientNames: {...patientNames, ...remote.patientNames}.toList()..sort(),
      sttTypoMap: {...remote.sttTypoMap, ...sttTypoMap},
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
