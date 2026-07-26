import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../models/care_dictionary_overrides.dart';
import 'care_dictionary_repository.dart';

class CareDictionarySyncResult {
  const CareDictionarySyncResult({this.merged, this.message = ''});

  final CareDictionaryOverrides? merged;
  final String message;
}

/// 로그인 시 사용자 사전을 Supabase `user_care_dictionary`와 병합합니다.
class CareDictionarySyncService {
  const CareDictionarySyncService._();

  static const String table = 'user_care_dictionary';

  static Future<CareDictionarySyncResult> sync({
    required SharedPreferences prefs,
    required CareDictionaryOverrides localOverrides,
  }) async {
    if (!AppEnv.isConfigured) {
      return const CareDictionarySyncResult(message: 'cloud_not_configured');
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const CareDictionarySyncResult(message: 'login_required');
    }

    try {
      final remote = await _fetchRemote(userId);
      final merged = remote != null ? localOverrides.mergeRemote(remote) : localOverrides;
      await _pushRemote(userId, merged);
      final repo = CareDictionaryRepository(prefs);
      await repo.replaceOverrides(merged);
      return CareDictionarySyncResult(merged: merged, message: 'sync_ok');
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        return CareDictionarySyncResult(merged: localOverrides, message: 'table_missing');
      }
      debugPrint('CareDictionarySync Postgrest: ${e.message}');
      return CareDictionarySyncResult(merged: localOverrides, message: 'sync_failed');
    } catch (e) {
      debugPrint('CareDictionarySync: $e');
      return CareDictionarySyncResult(merged: localOverrides, message: 'sync_failed');
    }
  }

  static Future<CareDictionaryOverrides?> _fetchRemote(String userId) async {
    final row = await Supabase.instance.client.from(table).select().eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    return CareDictionaryOverrides(
      hospitals: CareDictionaryOverrides.stringList(map['hospitals']),
      departments: CareDictionaryOverrides.stringList(map['departments']),
      patientNames: CareDictionaryOverrides.stringList(map['patient_names']),
      sttTypoMap: CareDictionaryOverrides.stringMap(map['stt_typo_map']),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  static Future<void> _pushRemote(String userId, CareDictionaryOverrides overrides) async {
    final payload = {
      'user_id': userId,
      'hospitals': overrides.hospitals,
      'departments': overrides.departments,
      'patient_names': overrides.patientNames,
      'stt_typo_map': overrides.sttTypoMap,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await Supabase.instance.client.from(table).upsert(payload);
  }
}
