import 'package:flutter/material.dart';

import 'graph_layout.dart';

/// 위성 레일(카드 왼쪽 1/5) 한 줄.
class SatelliteRailSegment {
  const SatelliteRailSegment({
    required this.mode,
    required this.icon,
    required this.count,
    required this.shortLabel,
  });

  final GraphSatelliteExpandMode mode;
  final IconData icon;
  final int count;
  final String shortLabel;
}

double memorySatelliteRailWidth(Size nodeSize) => nodeSize.width * 0.2;

/// 카드 왼쪽 위성 레일 탭 영역 — 전체 세로, 너비 1/5.
Rect memorySatelliteRailRect(Offset center, Size nodeSize) {
  final railWidth = memorySatelliteRailWidth(nodeSize);
  return Rect.fromLTWH(
    center.dx - nodeSize.width / 2,
    center.dy - nodeSize.height / 2,
    railWidth,
    nodeSize.height,
  );
}

GraphSatelliteExpandMode? _modeForBadgePart(String part) {
  final value = part.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('사람') || value.startsWith('👤')) {
    return GraphSatelliteExpandMode.person;
  }
  if (value.startsWith('장소') || value.startsWith('📍')) {
    return GraphSatelliteExpandMode.place;
  }
  return GraphSatelliteExpandMode.all;
}

int _countFromBadgePart(String part) {
  final match = RegExp(r'(\d+)\s*$').firstMatch(part.trim());
  if (match != null) return int.tryParse(match.group(1)!) ?? 0;
  return 0;
}

String _shortLabelFromBadgePart(String part, {required bool isKo}) {
  final value = part.trim();
  if (value.startsWith('사람') || value.startsWith('👤')) return isKo ? '사람' : 'Ppl';
  if (value.startsWith('장소') || value.startsWith('📍')) return isKo ? '장소' : 'Plc';
  if (value.startsWith('활동') || value.startsWith('Act')) return isKo ? '활동' : 'Act';
  if (value.startsWith('기타') || value.startsWith('+')) return isKo ? '기타' : 'Etc';
  return value.split(RegExp(r'\s+')).first;
}

IconData _iconForMode(GraphSatelliteExpandMode mode) {
  return switch (mode) {
    GraphSatelliteExpandMode.person => Icons.person_outline_rounded,
    GraphSatelliteExpandMode.place => Icons.place_outlined,
    GraphSatelliteExpandMode.personAndPlace => Icons.people_outline_rounded,
    GraphSatelliteExpandMode.all => Icons.hub_outlined,
  };
}

bool satelliteSegmentsIncludePersonAndPlace(List<SatelliteRailSegment> segments) {
  final hasPerson = segments.any((s) => s.mode == GraphSatelliteExpandMode.person);
  final hasPlace = segments.any((s) => s.mode == GraphSatelliteExpandMode.place);
  return hasPerson && hasPlace;
}

/// 레일 탭 시 실제 펼침 모드 — 왼쪽 레일은 그 기억의 위성 **전체**를 펼칩니다.
///
/// 세그먼트(사람/장소)별 부분 펼침은 배지 숫자와 실제 노드가 어긋나기 쉬워
/// 상용 UX에서는 한 번에 모두 펼치는 쪽이 예측 가능합니다.
GraphSatelliteExpandMode expandModeFromRailTap({
  required List<SatelliteRailSegment> segments,
  required GraphSatelliteExpandMode tappedSegmentMode,
}) {
  if (segments.isEmpty) return GraphSatelliteExpandMode.all;
  // 단일 종류만 있으면 그 종류만(가볍게), 여러 종류면 전체.
  if (segments.length == 1) return segments.first.mode;
  return GraphSatelliteExpandMode.all;
}

/// 배지 문자열(사람 4 · 장소 1)을 레일 세그먼트로 파싱합니다.
List<SatelliteRailSegment> parseSatelliteRailSegments(String badgeText, {String localeCode = 'ko'}) {
  final isKo = localeCode == 'ko';
  final parts = badgeText.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final segments = <SatelliteRailSegment>[];
  for (final part in parts) {
    final mode = _modeForBadgePart(part);
    if (mode == null) continue;
    segments.add(SatelliteRailSegment(
      mode: mode,
      icon: _iconForMode(mode),
      count: _countFromBadgePart(part),
      shortLabel: _shortLabelFromBadgePart(part, isKo: isKo),
    ));
  }
  return segments;
}

GraphSatelliteExpandMode? _modeFromRailTapPosition({
  required Offset canvasPos,
  required Rect railRect,
  required List<SatelliteRailSegment> segments,
}) {
  if (segments.isEmpty) return GraphSatelliteExpandMode.all;
  if (segments.length == 1) return segments.first.mode;

  // 하단 chevron 영역(~18%) 제외하고 세그먼트 구분.
  final contentHeight = railRect.height * 0.82;
  final relY = ((canvasPos.dy - railRect.top) / contentHeight).clamp(0.0, 0.999);
  final index = (relY * segments.length).floor().clamp(0, segments.length - 1);
  return expandModeFromRailTap(
    segments: segments,
    tappedSegmentMode: segments[index].mode,
  );
}

/// 왼쪽 위성 레일 탭 시 해당 위성 종류를 반환합니다.
GraphSatelliteExpandMode? satelliteModeFromRailTap({
  required Offset canvasPos,
  required Offset nodeCenter,
  required Size nodeSize,
  required String badgeText,
  String localeCode = 'ko',
}) {
  final rect = memorySatelliteRailRect(nodeCenter, nodeSize);
  if (!rect.contains(canvasPos)) return null;
  if (badgeText.trim().isEmpty) return null;
  final segments = parseSatelliteRailSegments(badgeText, localeCode: localeCode);
  return _modeFromRailTapPosition(
    canvasPos: canvasPos,
    railRect: rect,
    segments: segments,
  );
}

@Deprecated('Use satelliteModeFromRailTap')
GraphSatelliteExpandMode? satelliteModeFromBadgeTap({
  required Offset canvasPos,
  required Offset nodeCenter,
  required Size nodeSize,
  required String badgeText,
}) =>
    satelliteModeFromRailTap(
      canvasPos: canvasPos,
      nodeCenter: nodeCenter,
      nodeSize: nodeSize,
      badgeText: badgeText,
    );

/// 배지 탭으로 접을지 — 현재 펼침 모드와 탭한 모드가 같을 때 true.
bool shouldCollapseSatellitesOnBadgeTap({
  required GraphSatelliteExpandMode? activeMode,
  required GraphSatelliteExpandMode tappedMode,
}) {
  if (activeMode == null) return false;
  if (activeMode == tappedMode) return true;
  if (activeMode == GraphSatelliteExpandMode.all &&
      (tappedMode == GraphSatelliteExpandMode.person ||
          tappedMode == GraphSatelliteExpandMode.place ||
          tappedMode == GraphSatelliteExpandMode.personAndPlace)) {
    return true;
  }
  if (activeMode == GraphSatelliteExpandMode.personAndPlace &&
      (tappedMode == GraphSatelliteExpandMode.personAndPlace ||
          tappedMode == GraphSatelliteExpandMode.person ||
          tappedMode == GraphSatelliteExpandMode.place)) {
    return true;
  }
  return false;
}

String satelliteModeLabel(GraphSatelliteExpandMode mode, String localeCode) {
  if (localeCode == 'ko') {
    return switch (mode) {
      GraphSatelliteExpandMode.person => '👤 사람',
      GraphSatelliteExpandMode.place => '📍 장소',
      GraphSatelliteExpandMode.personAndPlace => '👤📍 사람·장소',
      GraphSatelliteExpandMode.all => '전체',
    };
  }
  return switch (mode) {
    GraphSatelliteExpandMode.person => '👤 People',
    GraphSatelliteExpandMode.place => '📍 Places',
    GraphSatelliteExpandMode.personAndPlace => '👤📍 People·Places',
    GraphSatelliteExpandMode.all => 'All',
  };
}
