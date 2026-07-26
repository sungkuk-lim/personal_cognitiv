import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/features/graph/graph_satellite_tap.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  test('rail tap returns all when badge has person and place', () {
    const center = Offset(100, 100);
    const size = Size(204, 124);
    const badge = '사람 4 · 장소 1';
    final rect = memorySatelliteRailRect(center, size);
    final upper = satelliteModeFromRailTap(
      canvasPos: Offset(rect.center.dx, rect.top + rect.height * 0.2),
      nodeCenter: center,
      nodeSize: size,
      badgeText: badge,
    );
    final lower = satelliteModeFromRailTap(
      canvasPos: Offset(rect.center.dx, rect.top + rect.height * 0.55),
      nodeCenter: center,
      nodeSize: size,
      badgeText: badge,
    );
    expect(upper, GraphSatelliteExpandMode.all);
    expect(lower, GraphSatelliteExpandMode.all);
  });

  test('rail tap with person·place·activity expands all', () {
    const center = Offset(100, 100);
    const size = Size(204, 124);
    const badge = '사람 2 · 장소 9 · 활동 1';
    final rect = memorySatelliteRailRect(center, size);
    final mode = satelliteModeFromRailTap(
      canvasPos: Offset(rect.center.dx, rect.top + rect.height * 0.3),
      nodeCenter: center,
      nodeSize: size,
      badgeText: badge,
    );
    expect(mode, GraphSatelliteExpandMode.all);
  });

  test('tap outside rail returns null', () {
    const center = Offset(100, 100);
    const size = Size(204, 124);
    final mode = satelliteModeFromRailTap(
      canvasPos: Offset(center.dx + 50, center.dy),
      nodeCenter: center,
      nodeSize: size,
      badgeText: '사람 4',
    );
    expect(mode, isNull);
  });

  test('parseSatelliteRailSegments extracts counts', () {
    final segments = parseSatelliteRailSegments('사람 4 · 장소 1', localeCode: 'ko');
    expect(segments, hasLength(2));
    expect(segments[0].count, 4);
    expect(segments[1].count, 1);
  });

  test('shouldCollapseSatellitesOnBadgeTap when personAndPlace already expanded', () {
    expect(
      shouldCollapseSatellitesOnBadgeTap(
        activeMode: GraphSatelliteExpandMode.personAndPlace,
        tappedMode: GraphSatelliteExpandMode.personAndPlace,
      ),
      isTrue,
    );
  });

  test('shouldCollapseSatellitesOnBadgeTap when already expanded with all', () {
    expect(
      shouldCollapseSatellitesOnBadgeTap(
        activeMode: GraphSatelliteExpandMode.all,
        tappedMode: GraphSatelliteExpandMode.person,
      ),
      isTrue,
    );
  });

  test('mergeDefaultSatelliteExpansions auto-expands small graphs with badge', () {
    final memory = Memory(
      id: 'rich',
      content: '아버지 어머니 집사람 태민과 길안천 나들이',
      summary: '길안천',
      entities: const ['아버지', '어머니', '집사람', '태민'],
      createdAt: DateTime(2026, 6, 22),
    );
    final auto = mergeDefaultSatelliteExpansions(
      memories: [memory],
      userExpansions: const {},
      graphFragments: const {},
      localeCode: 'ko',
    );
    expect(auto['rich'], GraphSatelliteExpandMode.all);

    final expanded = mergeDefaultSatelliteExpansions(
      memories: [memory],
      userExpansions: {memory.id: GraphSatelliteExpandMode.all},
      graphFragments: const {},
      localeCode: 'ko',
    );
    expect(expanded['rich'], GraphSatelliteExpandMode.all);

    final collapsed = mergeDefaultSatelliteExpansions(
      memories: [memory],
      userExpansions: {memory.id: GraphSatelliteExpandMode.all},
      collapsedMemoryIds: {'rich'},
      graphFragments: const {},
      localeCode: 'ko',
    );
    expect(collapsed.containsKey('rich'), isFalse);
  });
}
