import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/core/app_theme.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_grouping.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _gilancheonTrip = '''2026년 6월 22일 아버지, 어머니, 나, 집사람, 예린이, 태민이 이렇게 6명이서 길안천에 놀러갔었어
아버지와 어머니는 고스톰을 치며 시간을 보내셨고 나, 집사람, 예린이, 태민이는 다슬기를 잡아''';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('satellite nodes use distinct colors per kind', () {
    expect(graphNodeKindColor(GraphNodeKind.person), const Color(0xFFE91E63));
    expect(graphNodeKindColor(GraphNodeKind.place), const Color(0xFF00897B));
    expect(graphNodeKindColor(GraphNodeKind.activity), AppGraphColors.activity);
  });

  test('media-only graph note does not spawn entity_note node', () {
    final fields = buildVoiceMemoryFields(
      speechText: _gilancheonTrip,
      capturedAt: DateTime(2026, 6, 22, 14, 0),
      localeCode: 'ko',
      gpsPlace: '길안천',
    );
    final memory = Memory(
      id: 'gilancheon',
      content: fields.content,
      summary: fields.summary,
      entities: fields.entities,
      createdAt: DateTime(2026, 6, 22, 14, 0),
      lat: 36.5,
      lng: 128.7,
    );

    final mediaNote = buildMediaOnlyGraphNote(
      anchorNodeId: 'place_길안천',
      anchorLabel: '길안천',
      localeCode: 'ko',
    );
    expect(isMediaOnlyGraphNote(mediaNote), isTrue);

    final layout = buildMemoryGraphLayout(
      [memory, mediaNote],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(layout.nodes.any((n) => n.id == 'entity_note_${mediaNote.id}'), isFalse);
    expect(layout.nodes.any((n) => n.id == 'place_길안천'), isFalse,
        reason: '허브 제목에 장소가 있으면 장소 앵커 노드 생략');
    expect(
      layout.edges.any((e) => e.fromId == 'place_길안천' && e.toId.startsWith('entity_note_')),
      isFalse,
    );
  });

  test('group hub hides duplicate memory card with same title', () {
    final fields = buildVoiceMemoryFields(
      speechText: _gilancheonTrip,
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

    final layout = buildMemoryGraphLayout(
      [trip, photo],
      localeCode: 'ko',
      graphClusters: {
        clusterKeyForMemory(trip).id: GraphClusterSnapshot(
          clusterId: clusterKeyForMemory(trip).id,
          clusterTitle: '길안천 나들이',
        ),
      },
      collapseSatellitesByDefault: false,
    );

    final outingTitles = layout.nodes
        .where((n) => n.title.contains('길안천'))
        .map((n) => '${n.id}:${n.title}')
        .toList();
    expect(outingTitles.where((t) => t.contains('길안천 나들이')).length, 1);
    expect(layout.nodes.any((n) => n.id == 'memory_gilancheon'), isFalse);
    expect(layout.nodes.any((n) => n.id == 'memory_gilancheon_photo'), isFalse);
  });

  test('findGraphAnchorMemory matches person anchor', () {
    final note = buildMediaOnlyGraphNote(
      anchorNodeId: 'person_집사람',
      anchorLabel: '집사람',
      localeCode: 'ko',
    );
    final found = findGraphAnchorMemory([note], 'person_집사람');
    expect(found?.id, note.id);
  });
}
