import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/crash_reporting.dart';
import '../core/env.dart';

/// AI_OMAKASE_API_KEY 기반 클라우드 음성 전사 (OpenAI 호환 STT).
class OmakaseSttService {
  OmakaseSttService._();
  static final OmakaseSttService instance = OmakaseSttService._();

  String? _languageHintForLocale(String localeId) {
    final code = localeId.split(RegExp(r'[-_]')).first.toLowerCase();
    return switch (code) {
      'ko' => 'ko',
      'en' => 'en',
      'ja' => 'ja',
      'zh' => 'zh',
      _ => null,
    };
  }

  Future<String> transcribeFile(
    File audioFile, {
    required String localeId,
  }) async {
    if (!AppEnv.hasOmakaseStt) return '';
    if (!await audioFile.exists()) return '';
    final bytes = await audioFile.length();
    if (bytes < 1200) return '';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(AppEnv.aiOmakaseSttUrl))
        ..headers['Authorization'] = 'Bearer ${AppEnv.aiOmakaseApiKey}'
        ..fields['model'] = AppEnv.aiOmakaseSttModel
        ..fields['response_format'] = 'text';

      final lang = _languageHintForLocale(localeId);
      if (lang != null) request.fields['language'] = lang;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'speech.wav',
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 45));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        debugPrint('Omakase STT ${streamed.statusCode}: $body');
        return '';
      }
      return body.trim();
    } catch (e, stack) {
      debugPrint('Omakase STT error: $e');
      await CrashReporting.recordError(e, stack, reason: 'omakase_stt');
      return '';
    }
  }
}
