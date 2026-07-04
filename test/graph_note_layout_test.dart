import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_grouping.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('graph note does not spawn entity_note node on graph', () {
    final dinner = Memory(
      id: 'dinner',
      content: '6월 21일 병원직원 회식. 김경아 참석',
      summary: '병원 직원 회식',
      entities: const ['김경아', '배춘남'],
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );

    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_김경아',
        title: '김경아',
        subtitle: '사람',
        color: const Color(0xFFEC407A),
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    final layout = buildMemoryGraphLayout(
      [dinner, note],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(layout.nodes.where((n) => n.id.startsWith('event_hub_')).length, 0);
    expect(layout.nodes.any((n) => n.id == 'memory_dinner'), isTrue);
    expect(layout.nodes.any((n) => n.id == 'memory_${note.id}'), isFalse);
    expect(layout.nodes.any((n) => n.id.startsWith('entity_note_')), isFalse);
    expect(layout.nodes.any((n) => n.id == 'person_김경아'), isTrue);
    expect(
      layout.edges.any((e) => e.fromId == 'memory_dinner' && e.toId == 'person_김경아'),
      isTrue,
    );
  });

  test('graph note anchor appears even when satellites collapsed', () {
    final dinner = Memory(
      id: 'dinner',
      content: '6월 21일 병원직원 회식. 김경아 참석',
      summary: '병원 직원 회식',
      entities: const ['김경아', '배춘남'],
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );

    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_김경아',
        title: '김경아',
        subtitle: '사람',
        color: const Color(0xFFEC407A),
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    final layout = buildMemoryGraphLayout(
      [dinner, note],
      localeCode: 'ko',
      collapseSatellitesByDefault: true,
      satelliteExpansions: const {},
    );

    expect(layout.nodes.any((n) => n.id == 'person_김경아'), isTrue);
    expect(layout.nodes.any((n) => n.id.startsWith('entity_note_')), isFalse);
    expect(
      layout.edges.any((e) => e.fromId == 'memory_dinner' && e.toId == 'person_김경아'),
      isTrue,
    );
  });

  test('media-only anchor on collapsed satellites does not spawn orphan thumbnails', () {
    final fields = buildVoiceMemoryFields(
      speechText:
          '2026년 6월 22일 아버지, 어머니, 나, 집사람, 예린이, 태민이 길안천 나들이. 고스톰과 다슬기 잡기',
      capturedAt: DateTime(2026, 6, 22, 14, 0),
      localeCode: 'ko',
      gpsPlace: '길안천',
    );
    final trip = Memory(
      id: 'gilancheon',
      content: fields.content,
      summary: fields.summary,
      entities: fields.entities,
      createdAt: DateTime(2026, 6, 22, 14, 0),
      lat: 36.5,
      lng: 128.7,
    );
    final photo = Memory(
      id: 'gilancheon_photo',
      content: fields.content,
      summary: fields.summary,
      entities: fields.entities,
      createdAt: DateTime(2026, 6, 22, 15, 0),
      lat: 36.5,
      lng: 128.7,
      type: 'image',
    );
    final taeminMedia = buildMediaOnlyGraphNote(
      anchorNodeId: 'person_태민',
      anchorLabel: '태민',
      localeCode: 'ko',
      relatedMemoryId: trip.id,
    );
    final ghostMedia = buildMediaOnlyGraphNote(
      anchorNodeId: 'activity_고스톰',
      anchorLabel: '고스톰',
      localeCode: 'ko',
      relatedMemoryId: trip.id,
    );

    final layout = buildMemoryGraphLayout(
      [trip, photo, taeminMedia, ghostMedia],
      localeCode: 'ko',
      graphClusters: {
        clusterKeyForMemory(trip).id: GraphClusterSnapshot(
          clusterId: clusterKeyForMemory(trip).id,
          clusterTitle: '길안천 나들이',
        ),
      },
      collapseSatellitesByDefault: true,
      satelliteExpansions: const {},
    );

    expect(layout.nodes.any((n) => n.id == 'person_태민'), isFalse);
    expect(layout.nodes.any((n) => n.id == 'activity_고스톰'), isFalse);
    for (final node in layout.nodes) {
      if (node.kind == GraphNodeKind.person ||
          node.kind == GraphNodeKind.place ||
          node.kind == GraphNodeKind.activity) {
        final hasEdge = layout.edges.any((e) => e.fromId == node.id || e.toId == node.id);
        expect(hasEdge, isTrue, reason: '${node.id} must have at least one edge');
      }
    }
  });
}
