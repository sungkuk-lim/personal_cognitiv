import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/features/graph/graph_node_context.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('graph_media_scope_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String touch(String name) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(const [1, 2, 3]);
    return file.path;
  }

  GraphNodeData person(String name) => GraphNodeData(
        id: 'person_$name',
        title: name,
        subtitle: '사람',
        color: const Color(0xFFE91E63),
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      );

  GraphNodeData place(String name) => GraphNodeData(
        id: 'place_$name',
        title: name,
        subtitle: '장소',
        color: const Color(0xFF00897B),
        kind: GraphNodeKind.place,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      );

  GraphNodeData memoryNode(String id) => GraphNodeData(
        id: 'memory_$id',
        title: '기억',
        subtitle: 'memory',
        color: const Color(0xFF5C6BC0),
        kind: GraphNodeKind.memory,
        size: const Size(140, 56),
        layoutClusterId: 'c1',
      );

  test('replay video on a memory does not stamp every satellite', () {
    final dinner = Memory(
      id: 'dinner',
      content: '어제 어머니와 강남 식당에서 저녁',
      summary: '어머니와 저녁',
      entities: const ['어머니', '강남 식당'],
      createdAt: DateTime(2026, 7, 20, 19),
      type: 'image',
    );

    final nodes = [
      memoryNode('dinner'),
      person('어머니'),
      place('강남 식당'),
    ];
    final index = buildGraphNodeMediaIndex(
      nodes: nodes,
      memories: [dinner],
      imagePaths: const {},
      videoPaths: {
        'dinner': [touch('dinner.mp4')],
      },
      edges: [
        GraphEdgeData(fromId: 'memory_dinner', toId: 'person_어머니', color: Colors.grey),
        GraphEdgeData(fromId: 'memory_dinner', toId: 'place_강남 식당', color: Colors.grey),
      ],
    );

    expect(index['memory_dinner']?.hasVideo, isTrue);
    expect(index['person_어머니']?.hasVideo, isFalse);
    expect(index['place_강남 식당']?.hasVideo, isFalse);
  });

  test('anchor media shows only on the selected entity node', () {
    final dinner = Memory(
      id: 'dinner',
      content: '어제 어머니와 강남 식당에서 저녁',
      summary: '어머니와 저녁',
      entities: const ['어머니', '강남 식당'],
      createdAt: DateTime(2026, 7, 20, 19),
    );
    final momMedia = buildMediaOnlyGraphNote(
      anchorNodeId: 'person_어머니',
      anchorLabel: '어머니',
      localeCode: 'ko',
      relatedMemoryId: 'dinner',
    );

    final nodes = [
      memoryNode('dinner'),
      person('어머니'),
      place('강남 식당'),
    ];
    final index = buildGraphNodeMediaIndex(
      nodes: nodes,
      memories: [dinner, momMedia],
      imagePaths: {
        momMedia.id: [touch('mom.jpg')],
      },
      videoPaths: {
        momMedia.id: [touch('mom.mp4')],
      },
    );

    expect(index['person_어머니']?.hasVideo, isTrue);
    expect(index['person_어머니']?.photoCount, 1);
    expect(index['place_강남 식당']?.hasVideo, isFalse);
    expect(index['place_강남 식당']?.photoCount, 0);
    expect(index['memory_dinner']?.hasVideo, isFalse);
  });
}
