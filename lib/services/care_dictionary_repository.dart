import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/care_entity_dictionary.dart';
import '../models/care_dictionary_overrides.dart';

/// 로컬 사전 저장·로드 + 시드 merge.
class CareDictionaryRepository {
  const CareDictionaryRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String prefKey = 'care_dictionary_overrides_v1';

  CareDictionaryOverrides readOverrides() {
    final raw = _prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return CareDictionaryOverrides.empty;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CareDictionaryOverrides.fromJson(json);
    } catch (_) {
      return CareDictionaryOverrides.empty;
    }
  }

  Future<void> writeOverrides(CareDictionaryOverrides overrides) async {
    final payload = overrides.copyWith(updatedAt: DateTime.now().toUtc());
    await _prefs.setString(prefKey, jsonEncode(payload.toJson()));
  }

  CareEntityDictionary loadMergedDictionary() {
    final overrides = readOverrides();
    return CareEntityDictionary.seed().merge(
      hospitals: overrides.hospitals,
      departments: overrides.departments,
      patientNames: overrides.patientNames,
      sttTypoMap: overrides.sttTypoMap,
    );
  }

  Future<CareDictionaryOverrides> addHospital(String name) async {
    final v = name.trim();
    if (v.isEmpty) return readOverrides();
    final current = readOverrides();
    if (current.hospitals.contains(v)) return current;
    final next = current.copyWith(hospitals: [...current.hospitals, v]..sort());
    await writeOverrides(next);
    return next;
  }

  Future<CareDictionaryOverrides> removeHospital(String name) async {
    final current = readOverrides();
    final next = current.copyWith(
      hospitals: current.hospitals.where((h) => h != name).toList(),
    );
    await writeOverrides(next);
    return next;
  }

  Future<CareDictionaryOverrides> addDepartment(String name) async {
    final v = name.trim();
    if (v.isEmpty) return readOverrides();
    final current = readOverrides();
    if (current.departments.contains(v)) return current;
    final next = current.copyWith(departments: [...current.departments, v]..sort());
    await writeOverrides(next);
    return next;
  }

  Future<CareDictionaryOverrides> removeDepartment(String name) async {
    final current = readOverrides();
    final next = current.copyWith(
      departments: current.departments.where((d) => d != name).toList(),
    );
    await writeOverrides(next);
    return next;
  }

  Future<CareDictionaryOverrides> addTypoMapping({required String from, required String to}) async {
    final raw = from.trim();
    final corrected = to.trim();
    if (raw.isEmpty || corrected.isEmpty) return readOverrides();
    final current = readOverrides();
    final next = current.copyWith(sttTypoMap: {...current.sttTypoMap, raw: corrected});
    await writeOverrides(next);
    return next;
  }

  Future<CareDictionaryOverrides> removeTypoMapping(String from) async {
    final current = readOverrides();
    final map = Map<String, String>.from(current.sttTypoMap)..remove(from);
    final next = current.copyWith(sttTypoMap: map);
    await writeOverrides(next);
    return next;
  }

  Future<void> replaceOverrides(CareDictionaryOverrides overrides) async {
    await writeOverrides(overrides);
  }
}
