import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/place_lookup_service.dart';
import '../utils/recall_anchor.dart';
import '../utils/memory_relative_date.dart';
import '../features/memory/recall_place_confirm_sheet.dart';
import '../features/memory/memory_date_confirm_sheet.dart';

/// 저장 직전 이야기 장소·날짜·회상 앵커를 확정합니다.
Future<Memory> resolveRecallAnchorForMemory(
  BuildContext context,
  Memory draft, {
  required String localeCode,
  String? capturePlaceLabel,
}) async {
  var resolved = await _resolveStoryPlace(context, draft, localeCode: localeCode, capturePlaceLabel: capturePlaceLabel);
  if (!context.mounted) return resolved;

  final dayOffset = relativeDayOffsetFromText(resolved.content);
  if (dayOffset != null && dayOffset != 0) {
    final adjust = await showMemoryDateConfirmSheet(
      context,
      dayOffset: dayOffset,
      currentCreatedAt: resolved.createdAt,
      localeCode: localeCode,
    );
    if (!context.mounted || adjust == null) return resolved;
    if (adjust) {
      resolved = resolved.copyWith(createdAt: applyRelativeDayOffset(resolved.createdAt, dayOffset));
    }
  }
  return resolved;
}

Future<Memory> _resolveStoryPlace(
  BuildContext context,
  Memory draft, {
  required String localeCode,
  String? capturePlaceLabel,
}) async {
  final storyPlace = primaryStoryPlaceLabel(draft, localeCode: localeCode);
  if (storyPlace == null || storyPlace.trim().isEmpty) {
    return _anchorCaptureGps(draft, capturePlaceLabel);
  }

  final storyCoords = await PlaceLookupService.resolveCoordinatesForPlace(
    storyPlace,
    localeCode: localeCode,
  );

  final needsConfirm = shouldConfirmRecallPlace(
    capturePlaceLabel: capturePlaceLabel,
    storyPlaceLabel: storyPlace,
    captureLat: draft.lat,
    captureLng: draft.lng,
    storyLat: storyCoords?.lat,
    storyLng: storyCoords?.lng,
  );

  if (!needsConfirm) {
    if (draft.lat == null || draft.lng == null) {
      if (storyCoords == null) {
        return draft.copyWith(recallPlaceLabel: storyPlace, recallEnabled: false);
      }
      return _withStoryCoordinates(draft, storyPlace: storyPlace, coords: storyCoords);
    }
    return draft.copyWith(
      recallLat: draft.lat,
      recallLng: draft.lng,
      recallPlaceLabel: storyPlace,
      recallEnabled: true,
    );
  }

  if (!context.mounted) return draft;
  final captureLabel = (capturePlaceLabel?.trim().isNotEmpty ?? false)
      ? capturePlaceLabel!.trim()
      : (localeCode == 'ko' ? '지금 위치' : 'current location');

  final choice = await showRecallPlaceConfirmSheet(
    context,
    storyPlaceLabel: storyPlace,
    capturePlaceLabel: captureLabel,
  );
  if (!context.mounted || choice == null) {
    return draft.copyWith(recallEnabled: false);
  }

  switch (choice) {
    case RecallPlaceChoice.storyPlace:
      if (storyCoords != null) {
        return _withStoryCoordinates(draft, storyPlace: storyPlace, coords: storyCoords);
      }
      return draft.copyWith(
        recallPlaceLabel: storyPlace,
        recallEnabled: false,
      );
    case RecallPlaceChoice.captureHere:
      if (draft.lat == null || draft.lng == null) return draft.copyWith(recallEnabled: false);
      return draft.copyWith(
        lat: draft.lat,
        lng: draft.lng,
        recallLat: draft.lat,
        recallLng: draft.lng,
        recallPlaceLabel: captureLabel,
        recallEnabled: true,
      );
    case RecallPlaceChoice.disableRecall:
      return draft.copyWith(recallEnabled: false);
  }
}

Memory _withStoryCoordinates(
  Memory draft, {
  required String storyPlace,
  required ({double lat, double lng}) coords,
}) {
  return draft.copyWith(
    lat: coords.lat,
    lng: coords.lng,
    recallLat: coords.lat,
    recallLng: coords.lng,
    recallPlaceLabel: storyPlace,
    recallEnabled: true,
  );
}

Memory _anchorCaptureGps(Memory draft, String? capturePlaceLabel) {
  if (draft.lat == null || draft.lng == null) {
    return draft.copyWith(recallEnabled: false);
  }
  return draft.copyWith(
    recallLat: draft.lat,
    recallLng: draft.lng,
    recallPlaceLabel: capturePlaceLabel?.trim().isNotEmpty == true ? capturePlaceLabel!.trim() : null,
    recallEnabled: true,
  );
}
