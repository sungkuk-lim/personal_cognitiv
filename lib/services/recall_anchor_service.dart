import 'package:flutter/material.dart';

import '../features/memory/memory_date_confirm_sheet.dart';
import '../features/memory/memory_refinement_sheet.dart';
import '../features/memory/recall_place_confirm_sheet.dart';
import '../models/memory.dart';
import '../services/place_lookup_service.dart';
import '../utils/memory_place_policy.dart';
import '../utils/memory_relative_date.dart';
import '../utils/memory_save_refinement.dart';
import '../utils/recall_anchor.dart';

/// 저장 직전 이야기 장소·날짜·회상 앵커를 확정합니다.
Future<Memory> resolveRecallAnchorForMemory(
  BuildContext context,
  Memory draft, {
  required String localeCode,
  String? capturePlaceLabel,
  double? captureLat,
  double? captureLng,
}) async {
  final dayOffset = relativeDayOffsetFromText(draft.content);
  final storyPlace = primaryStoryPlaceLabel(draft, localeCode: localeCode);
  final captureAvailable = captureLat != null && captureLng != null;

  if (shouldShowMemoryRefinementSheet(draft, localeCode: localeCode)) {
    final initialDate = dayOffset != null
        ? applyRelativeDayOffset(draft.createdAt, dayOffset)
        : draft.createdAt;
    final initialMode = initialPlaceModeForRefinement(
      draft: draft,
      captureLat: captureLat,
      captureLng: captureLng,
      storyPlace: storyPlace,
    );

    final refined = await showMemoryRefinementSheet(
      context,
      initialDate: initialDate,
      initialSummary: draft.summary,
      localeCode: localeCode,
      initialPlaceMode: initialMode,
      initialCustomPlace: storyPlace,
      capturePlaceLabel: capturePlaceLabel,
      captureAvailable: captureAvailable,
    );

    if (refined != null && context.mounted) {
      return applyRefinementToMemory(
        draft,
        refined,
        localeCode: localeCode,
        captureLat: captureLat,
        captureLng: captureLng,
        capturePlaceLabel: capturePlaceLabel,
      );
    }

    return draft.copyWith(recallEnabled: false, lat: null, lng: null);
  }

  var resolved = await _resolveStoryPlace(
    context,
    draft,
    localeCode: localeCode,
    capturePlaceLabel: capturePlaceLabel,
  );
  if (!context.mounted) return resolved;

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

Future<Memory> applyRefinementToMemory(
  Memory draft,
  MemoryRefinementResult refined, {
  required String localeCode,
  double? captureLat,
  double? captureLng,
  String? capturePlaceLabel,
}) async {
  final summary = refined.summary.trim().isNotEmpty ? refined.summary.trim() : draft.summary;
  var updated = draft.copyWith(
    createdAt: refined.date,
    summary: summary,
  );

  switch (refined.placeMode) {
    case MemoryPlaceMode.none:
      return updated.copyWith(
        lat: null,
        lng: null,
        recallLat: null,
        recallLng: null,
        recallPlaceLabel: null,
        recallEnabled: false,
      );
    case MemoryPlaceMode.captureHere:
      if (captureLat == null || captureLng == null) {
        return updated.copyWith(recallEnabled: false, lat: null, lng: null);
      }
      final hereLabel = _captureLabel(capturePlaceLabel, localeCode);
      return updated.copyWith(
        lat: captureLat,
        lng: captureLng,
        recallLat: captureLat,
        recallLng: captureLng,
        recallPlaceLabel: hereLabel,
        recallEnabled: true,
      );
    case MemoryPlaceMode.custom:
      final place = refined.customPlace?.trim() ?? '';
      if (place.isEmpty) {
        return updated.copyWith(recallEnabled: false, lat: null, lng: null);
      }
      try {
        final coords = await PlaceLookupService.resolveCoordinatesForPlace(place, localeCode: localeCode);
        if (coords != null) {
          return updated.copyWith(
            lat: coords.lat,
            lng: coords.lng,
            recallLat: coords.lat,
            recallLng: coords.lng,
            recallPlaceLabel: place,
            recallEnabled: true,
          );
        }
      } catch (_) {}
      return updated.copyWith(
        lat: null,
        lng: null,
        recallLat: null,
        recallLng: null,
        recallPlaceLabel: place,
        recallEnabled: false,
      );
  }
}

String _captureLabel(String? capturePlaceLabel, String localeCode) {
  final raw = capturePlaceLabel?.trim() ?? '';
  if (raw.isEmpty || isGenericCapturePlaceLabel(raw)) {
    return localeCode == 'ko' ? '지금 위치' : 'Current location';
  }
  return raw;
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
  final captureLabel = _captureLabel(capturePlaceLabel, localeCode);

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
  if (!isPhotoCaptureMemoryType(draft.type)) {
    return draft.copyWith(recallEnabled: false);
  }
  return draft.copyWith(
    recallLat: draft.lat,
    recallLng: draft.lng,
    recallPlaceLabel: capturePlaceLabel?.trim().isNotEmpty == true ? capturePlaceLabel!.trim() : null,
    recallEnabled: true,
  );
}
