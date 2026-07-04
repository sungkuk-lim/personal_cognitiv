import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import '../utils/korean_person_names.dart';
import '../utils/memory_entity_extract.dart';
import '../utils/ocr_utils.dart';
import 'ai_service.dart';

/// 관계망 전용 AI — 기억·묶음 단위 그래프 조각 생성 (방식 C).
class GraphAiService {
  GraphAiService._();
  static final GraphAiService instance = GraphAiService._();

  Future<GraphMemoryFragment?> generateMemoryFragment({
    required Memory memory,
    required String localeCode,
    List<Memory> clusterSiblings = const [],
  }) async {
    final lang = localeCode == 'ko' ? 'Korean' : 'English';
    final siblings = clusterSiblings
        .where((m) => m.id != memory.id)
        .take(6)
        .map((m) => {
              'id': m.id,
              'content': m.content.trim(),
              'summary': m.summary.trim(),
            })
        .toList();

    final system = '''
You design a personal life ENTITY graph (not keyword graph). Respond in $lang JSON only.
Return: {
  "event_title": "core event in 4-12 words (e.g. 병원 직원 회식). NEVER food items.",
  "meaning_title": "same as event_title or one evocative sentence",
  "satellites": [
    {"kind": "person|place|organization|activity|emotion", "label": "short noun, max 12 chars"}
  ],
  "relations": [
    {"target_memory_id": "uuid from siblings", "relation_type": "family|place|theme|emotion|goal", "label": "short edge label"}
  ]
}
Priority (strict): person ★★★★★ > event ★★★★★ > place ★★★★ > organization ★★★★ > emotion ★★★ > food ★ (NEVER as satellite).
Rules:
- event_title: the MAIN occasion (회식, 회의, 여행). Not "탕수육" or "술".
- satellites: max 12 persons, max 3 places, max 3 organizations. NO food (탕수육, 자장면, 술, 음식).
- person: real human names only. Strip titles (간호과장 → name only).
- organization: 병원, 간호과, 보호사팀 etc.
- place: restaurant/location names only.
- Never put people names as place. No lot numbers alone as place.
- relations: only to sibling ids listed; max 3 meaningful links.
- Skip meta phrases like "오늘 있었던 일".
''';

    final user = jsonEncode({
      'memory': {
        'id': memory.id,
        'content': memory.content,
        'summary': memory.summary,
        'entities': memory.entities,
        'category': memory.category,
        'sub_category': memory.subCategory,
        'created_at': memory.createdAt.toIso8601String(),
      },
      'siblings_same_day_place': siblings,
    });

    try {
      final raw = await AiService.instance.chatJson(systemPrompt: system, userPrompt: user);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final eventTitle = (data['event_title'] as String? ?? data['meaning_title'] as String? ?? '').trim();
      final fragment = GraphMemoryFragment.fromMap({
        ...data,
        'meaning_title': eventTitle.isNotEmpty ? eventTitle : data['meaning_title'],
        'generated_at': DateTime.now().toIso8601String(),
      });
      if (!fragment.isUsable || isGraphMetaContent(fragment.meaningTitle)) return null;
      return _sanitizeFragment(fragment);
    } catch (e, stack) {
      debugPrint('Graph AI memory fragment failed: $e\n$stack');
      return null;
    }
  }

  Future<GraphClusterSnapshot?> generateClusterSnapshot({
    required String clusterId,
    required List<Memory> memories,
    required String localeCode,
  }) async {
    if (memories.length < 2) return null;

    final lang = localeCode == 'ko' ? 'Korean' : 'English';
    final items = memories
        .where((m) => !isGraphMetaContent(m.content.trim()))
        .map((m) => {
              'content': m.content.trim(),
              'summary': m.summary.trim(),
            })
        .toList();
    if (items.isEmpty) return null;

    final system = '''
You summarize a cluster of memories from the same day and place for a life graph hub card.
Focus on EVENT and PEOPLE, not food items.
Respond in $lang JSON only: {
  "cluster_title": "one evocative event sentence for the whole cluster (not a list, not food)",
  "highlights": ["short phrase", ...] 
}
highlights: max 4 short phrases about people/events/places. Skip food and meta headlines.
''';

    final user = jsonEncode({'memories': items});

    try {
      final raw = await AiService.instance.chatJson(systemPrompt: system, userPrompt: user);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = GraphClusterSnapshot.fromMap(clusterId, {
        ...data,
        'generated_at': DateTime.now().toIso8601String(),
      });
      if (!snapshot.isUsable) return null;
      return snapshot;
    } catch (e, stack) {
      debugPrint('Graph AI cluster snapshot failed: $e\n$stack');
      return null;
    }
  }

  GraphMemoryFragment _sanitizeFragment(GraphMemoryFragment fragment) {
    final seen = <String>{};
    final satellites = <GraphAiSatellite>[];
    var personCount = 0;
    for (final s in fragment.satellites) {
      final label = s.label.trim();
      if (label.isEmpty || isGraphJunkTitle(label) || isGraphMetaContent(label)) continue;
      if (isGraphFoodOrNoiseToken(label) || isBlockedPersonName(label)) continue;
      if (!seen.add(label)) continue;
      if (!_allowedKinds.contains(s.kind)) continue;
      if (s.kind == 'person') {
        if (!isLikelyKoreanPersonName(normalizeKoreanPersonName(label))) continue;
        if (personCount >= kGraphMaxPeopleSatellites) continue;
        personCount++;
      }
      satellites.add(GraphAiSatellite(kind: s.kind, label: label));
      if (satellites.length >= 16) break;
    }

    final relations = fragment.relations.take(4).toList();
    return GraphMemoryFragment(
      meaningTitle: fragment.meaningTitle.trim(),
      satellites: satellites,
      relations: relations,
      generatedAt: fragment.generatedAt ?? DateTime.now(),
    );
  }

  static const _allowedKinds = {'person', 'place', 'organization', 'activity', 'goal', 'emotion'};
}
