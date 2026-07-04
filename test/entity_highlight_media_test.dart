import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/entity_highlight_media.dart';
import 'package:personal_cognitive/utils/memory_image_paths.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  File _tempJpg(String name) {
    final file = File('${Directory.systemTemp.path}/highlight_test_$name.jpg');
    file.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    return file;
  }

  test('collectEntityHighlightSlides gathers photos from matching memories', () {
    final a = _tempJpg('a');
    final b = _tempJpg('b');
    addTearDown(() {
      if (a.existsSync()) a.deleteSync();
      if (b.existsSync()) b.deleteSync();
    });

    final memories = [
      Memory(
        id: 'trip',
        content: '집사람과 길안천 나들이',
        summary: '길안천 나들이',
        entities: const ['집사람', '길안천'],
        createdAt: DateTime(2026, 6, 22),
        type: 'image',
      ),
      Memory(
        id: 'work',
        content: '회사 회의',
        summary: '회의',
        entities: const ['민수'],
        createdAt: DateTime(2026, 6, 1),
      ),
    ];
    final paths = {
      'trip': [a.path, b.path],
      'work': [_tempJpg('x').path],
    };

    final slides = collectEntityHighlightSlides(
      entityLabel: '집사람',
      allMemories: memories,
      imagePaths: paths,
      imageMemos: const {},
      videoPaths: const {},
      localeCode: 'ko',
    );

    expect(slides.length, 2);
    expect(slides.every((s) => s.memoryId == 'trip'), isTrue);
    expect(slides.first.dateLabel, contains('2026'));
  });

  test('collectEntityHighlightSlides includes graph anchor media', () {
    final photo = _tempJpg('minsoo');
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });

    final anchor = Memory(
      id: 'anchor-note',
      content: '',
      summary: '',
      entities: const [],
      createdAt: DateTime(2026, 7, 1),
      type: 'graph_note',
      userMemo: 'graph_anchor:person_민수',
    );
    final paths = {'anchor-note': [photo.path]};

    final slides = collectEntityHighlightSlides(
      entityLabel: '민수',
      allMemories: [anchor],
      imagePaths: paths,
      imageMemos: const {},
      videoPaths: const {},
      localeCode: 'ko',
    );

    expect(slides.length, 1);
    expect(slides.first.memoryId, 'anchor-note');
  });

  test('collectEntityHighlightSlides uses connected memories from graph node', () {
    final photo = _tempJpg('cafe');
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });

    final memory = Memory(
      id: 'm1',
      content: '민수와 카페',
      summary: '카페',
      entities: const ['민수'],
      createdAt: DateTime(2026, 5, 10),
      type: 'image',
    );
    final paths = {'m1': [photo.path]};
    const node = GraphNodeData(
      id: 'person_민수',
      title: '민수',
      subtitle: '인물',
      color: Color(0xFFE91E63),
      kind: GraphNodeKind.person,
      size: Size(100, 50),
      layoutClusterId: 'c1',
    );
    const edges = [
      GraphEdgeData(fromId: 'person_민수', toId: 'memory_m1', color: Color(0xFFE91E63)),
    ];

    final slides = collectEntityHighlightSlides(
      entityLabel: '민수',
      allMemories: [memory],
      imagePaths: paths,
      imageMemos: const {},
      videoPaths: const {},
      node: node,
      edges: edges,
      localeCode: 'ko',
    );

    expect(slides.length, 1);
  });
}
