import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/organization_hierarchy.dart';
import 'ai_service.dart';

/// 규칙 파서가 못 잡은 본문을 AI로 계층 트리화합니다.
///
/// 핵심: 입력 문장의 **흐름(순서)** 과 **키워드(원문 그대로)** 를 지켜 연결합니다.
Future<OrganizationHierarchy?> generateAiRelationHierarchy({
  required String text,
  required String localeCode,
}) async {
  final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (trimmed.length < 24) return null;

  final lang = localeCode == 'ko' ? 'Korean' : 'English';
  final system = '''
You build a PERSONAL RELATIONSHIP TREE from one memory text.
Respond in $lang JSON only:
{
  "root": "main topic / hub title from the text",
  "nodes": [{"label": "exact keyword", "kind": "organization|person|project"}],
  "hierarchy_edges": [{"from": "parent", "to": "child", "label": "소속|구성|자녀|분류|영역|과목|목적지|활동"}],
  "cross_relations": [{"subject": "A", "predicate": "short verb/noun link", "object": "B"}]
}

CRITICAL accuracy rules:
1) FLOW first: follow the narrative order (who → group → members → activities → places).
2) KEYWORDS must be copied from the input (do not invent names, do not truncate words, do not glue particles like 로/은).
3) hierarchy_edges = containment / belonging / part-of (tree only, no cycles).
4) cross_relations = horizontal links (together, support, recommend, introduce, collaborate). Never put these in hierarchy_edges.
5) Every node label (except a short synthetic root of ≤12 chars) MUST appear as a contiguous substring of the input.
6) Prefer concrete nouns already written (people, teams, pets, places, subjects, projects).
7) Limits: ≤22 nodes, ≤18 hierarchy_edges, ≤10 cross_relations.
8) If the text has no clear multi-level structure, return {"root":"","nodes":[],"hierarchy_edges":[],"cross_relations":[]}.
''';

  final user = jsonEncode({'text': trimmed});
  try {
    final raw = await AiService.instance.chatJson(
      systemPrompt: system,
      userPrompt: user,
    );
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final parsed = OrganizationHierarchy.fromJsonMap(
      Map<String, dynamic>.from(data),
    );
    final sanitized = sanitizeHierarchyAgainstSource(parsed, trimmed);
    if (!sanitized.hasHierarchy) return null;
    return sanitized;
  } catch (e, stack) {
    debugPrint('AI relation hierarchy failed: $e\n$stack');
    return null;
  }
}
