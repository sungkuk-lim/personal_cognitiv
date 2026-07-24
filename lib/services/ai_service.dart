import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/crash_reporting.dart';
import '../core/env.dart';
import 'subscription_exceptions.dart';

/// OpenAI 호출을 Edge Function으로 우선 라우팅해 키 노출·남용을 줄입니다.
///
/// 프로덕션(`USE_EDGE_PROXY=true`)에서는 **쿼터·구독 게이트를 우회하는
/// 클라이언트 직접 OpenAI 폴백을 하지 않습니다.** (개발자 원가 방어)
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  Future<Map<String, dynamic>> _invokeEdge(String action, Map<String, dynamic> payload) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'openai-proxy',
        body: {'action': action, ...payload},
      );
      if (response.data == null) {
        throw Exception('Edge function returned empty data');
      }
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
    } on FunctionException catch (e) {
      _throwIfSubscriptionError(e);
      rethrow;
    }
  }

  void _throwIfSubscriptionError(FunctionException e) {
    final details = e.details;
    Map<String, dynamic>? map;
    if (details is Map<String, dynamic>) {
      map = details;
    } else if (details is Map) {
      map = Map<String, dynamic>.from(details);
    }
    final code = map?['code'] as String? ?? map?['error'] as String?;
    if (e.status == 402 || code == 'subscription_required') {
      throw SubscriptionRequiredException();
    }
    if (e.status == 429 || code == 'quota_exceeded') {
      throw QuotaExceededException(
        action: map?['action'] as String?,
        limit: map?['limit'] as int?,
        used: map?['used'] as int?,
      );
    }
  }

  /// 구독·쿼터 예외는 절대 삼키지 않습니다. Edge 사용 시 직접 OpenAI 폴백 금지.
  Future<Never> _failClosedAfterEdge(Object e, StackTrace stack, String reason) async {
    if (e is SubscriptionRequiredException || e is QuotaExceededException) {
      Error.throwWithStackTrace(e, stack);
    }
    debugPrint('Edge $reason failed (no direct OpenAI fallback): $e');
    await CrashReporting.recordError(e, stack, reason: reason);
    Error.throwWithStackTrace(e, stack);
  }

  Future<Map<String, dynamic>> _postOpenAiDirect(Map<String, dynamic> body) async {
    final key = AppEnv.openAiApiKey;
    if (key.isEmpty) {
      throw Exception('OPENAI_API_KEY not set. Deploy openai-proxy Edge Function or pass --dart-define=OPENAI_API_KEY=...');
    }
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('OpenAI error (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<double>> createEmbedding(String input) async {
    if (AppEnv.useEdgeProxy) {
      try {
        final data = await _invokeEdge('embedding', {
          'model': 'text-embedding-3-small',
          'input': input,
        });
        return List<double>.from(data['embedding'] as List);
      } catch (e, stack) {
        await _failClosedAfterEdge(e, stack, 'edge_embedding');
      }
    }

    final key = AppEnv.openAiApiKey;
    if (key.isEmpty) {
      throw Exception(
        'Embedding failed: Edge proxy unavailable and OPENAI_API_KEY not set.',
      );
    }
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': 'text-embedding-3-small', 'input': input}),
    );
    if (response.statusCode != 200) {
      throw Exception('Embedding error (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return List<double>.from(body['data'][0]['embedding'] as List);
  }

  Future<String> chatJson({
    required String systemPrompt,
    required String userPrompt,
    String model = 'gpt-4o-mini',
  }) async {
    if (AppEnv.useEdgeProxy) {
      try {
        final data = await _invokeEdge('chat', {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'response_format': {'type': 'json_object'},
        });
        return data['content'] as String;
      } catch (e, stack) {
        await _failClosedAfterEdge(e, stack, 'edge_chat_json');
      }
    }

    final body = await _postOpenAiDirect({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
    });
    return body['choices'][0]['message']['content'] as String;
  }

  Future<String> chatText({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    String model = 'gpt-4o-mini',
  }) async {
    if (AppEnv.useEdgeProxy) {
      try {
        final data = await _invokeEdge('chat', {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            ...messages,
          ],
        });
        return data['content'] as String;
      } catch (e, stack) {
        await _failClosedAfterEdge(e, stack, 'edge_chat_text');
      }
    }

    final body = await _postOpenAiDirect({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ],
    });
    return body['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>> analyzeImageVision({
    required Uint8List jpegBytes,
    required String prompt,
    required String detail,
    int maxTokens = 1200,
  }) async {
    final base64Image = base64Encode(jpegBytes);
    if (AppEnv.useEdgeProxy) {
      try {
        final data = await _invokeEdge('vision', {
          'model': 'gpt-4o-mini',
          'prompt': prompt,
          'image_base64': base64Image,
          'detail': detail,
          'max_tokens': maxTokens,
        });
        return jsonDecode(data['content'] as String) as Map<String, dynamic>;
      } catch (e, stack) {
        await _failClosedAfterEdge(e, stack, 'edge_vision');
      }
    }

    final key = AppEnv.openAiApiKey;
    if (key.isEmpty) throw Exception('Vision requires Edge Function or OPENAI_API_KEY');
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                  'detail': detail,
                },
              },
            ],
          },
        ],
        'max_tokens': maxTokens,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Vision error (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['choices'][0]['message']['content'] as String;
    return jsonDecode(content) as Map<String, dynamic>;
  }
}
