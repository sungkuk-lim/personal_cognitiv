/// AI가 생성한 기억 1건 분의 관계망 조각 (방식 C — 저장 시 생성).
class GraphMemoryFragment {
  const GraphMemoryFragment({
    required this.meaningTitle,
    this.satellites = const [],
    this.relations = const [],
    this.generatedAt,
  });

  final String meaningTitle;
  final List<GraphAiSatellite> satellites;
  final List<GraphAiRelation> relations;
  final DateTime? generatedAt;

  factory GraphMemoryFragment.fromMap(Map<String, dynamic> map) {
    final rawSatellites = map['satellites'] as List? ?? [];
    final rawRelations = map['relations'] as List? ?? [];
    return GraphMemoryFragment(
      meaningTitle: (map['meaning_title'] as String? ?? '').trim(),
      satellites: rawSatellites
          .map((e) => GraphAiSatellite.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.label.isNotEmpty)
          .toList(),
      relations: rawRelations
          .map((e) => GraphAiRelation.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.targetMemoryId.isNotEmpty)
          .toList(),
      generatedAt: map['generated_at'] != null ? DateTime.tryParse(map['generated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'meaning_title': meaningTitle,
        'satellites': satellites.map((s) => s.toMap()).toList(),
        'relations': relations.map((r) => r.toMap()).toList(),
        if (generatedAt != null) 'generated_at': generatedAt!.toIso8601String(),
      };

  bool get isUsable => meaningTitle.trim().isNotEmpty;
}

/// 같은 날·같은 장소 묶음 허브용 AI 요약.
class GraphClusterSnapshot {
  const GraphClusterSnapshot({
    required this.clusterId,
    required this.clusterTitle,
    this.highlightTitles = const [],
    this.generatedAt,
  });

  final String clusterId;
  final String clusterTitle;
  final List<String> highlightTitles;
  final DateTime? generatedAt;

  factory GraphClusterSnapshot.fromMap(String clusterId, Map<String, dynamic> map) {
    return GraphClusterSnapshot(
      clusterId: clusterId,
      clusterTitle: (map['cluster_title'] as String? ?? '').trim(),
      highlightTitles: List<String>.from(map['highlights'] ?? []),
      generatedAt: map['generated_at'] != null ? DateTime.tryParse(map['generated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'cluster_title': clusterTitle,
        'highlights': highlightTitles,
        if (generatedAt != null) 'generated_at': generatedAt!.toIso8601String(),
      };

  bool get isUsable => clusterTitle.trim().isNotEmpty;
}

class GraphAiSatellite {
  const GraphAiSatellite({required this.kind, required this.label});

  final String kind;
  final String label;

  factory GraphAiSatellite.fromMap(Map<String, dynamic> map) {
    return GraphAiSatellite(
      kind: (map['kind'] as String? ?? '').trim().toLowerCase(),
      label: (map['label'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() => {'kind': kind, 'label': label};
}

class GraphAiRelation {
  const GraphAiRelation({
    required this.targetMemoryId,
    required this.relationType,
    this.label = '',
  });

  final String targetMemoryId;
  final String relationType;
  final String label;

  factory GraphAiRelation.fromMap(Map<String, dynamic> map) {
    return GraphAiRelation(
      targetMemoryId: (map['target_memory_id'] as String? ?? '').trim(),
      relationType: (map['relation_type'] as String? ?? 'related').trim(),
      label: (map['label'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'target_memory_id': targetMemoryId,
        'relation_type': relationType,
        if (label.isNotEmpty) 'label': label,
      };
}
