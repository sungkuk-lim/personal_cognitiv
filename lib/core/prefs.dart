import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ocr_config.dart';

const String prefThemeMode = 'theme_mode';
const String prefGraphPositions = 'graph_node_positions';
const String prefOcrEngineMode = 'ocr_engine_mode';
const String prefOcrVisionQuality = 'ocr_vision_quality';
const String prefMemoryImagePaths = 'memory_image_paths';
const String prefOnDeviceOcr = 'on_device_ocr_enabled';
const String prefGuestMode = 'guest_mode';
const String prefOnboardingDone = 'onboarding_done';

bool readGuestMode(SharedPreferences prefs) => prefs.getBool(prefGuestMode) ?? false;

Future<void> writeGuestMode(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefGuestMode, enabled);
}

ThemeMode readSavedThemeMode(SharedPreferences prefs) {
  switch (prefs.getString(prefThemeMode)) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Future<void> saveThemeMode(SharedPreferences prefs, ThemeMode mode) async {
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
  await prefs.setString(prefThemeMode, value);
}

Map<String, Offset> readSavedGraphPositions(SharedPreferences prefs) {
  final raw = prefs.getString(prefGraphPositions);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) {
      final point = value as Map<String, dynamic>;
      return MapEntry(key, Offset((point['dx'] as num).toDouble(), (point['dy'] as num).toDouble()));
    });
  } catch (_) {
    return {};
  }
}

Future<void> saveGraphPositions(SharedPreferences prefs, Map<String, Offset> positions) async {
  final encoded = positions.map((key, value) => MapEntry(key, {'dx': value.dx, 'dy': value.dy}));
  await prefs.setString(prefGraphPositions, jsonEncode(encoded));
}

Map<String, String> readMemoryImagePaths(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryImagePaths);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(key, value as String));
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryImagePaths(SharedPreferences prefs, Map<String, String> paths) async {
  await prefs.setString(prefMemoryImagePaths, jsonEncode(paths));
}

OcrEngineMode readOcrEngineMode(SharedPreferences prefs) {
  switch (prefs.getString(prefOcrEngineMode)) {
    case 'lowCost':
      return OcrEngineMode.lowCost;
    case 'vision':
      return OcrEngineMode.vision;
    default:
      return OcrEngineMode.hybrid;
  }
}

Future<void> saveOcrEngineMode(SharedPreferences prefs, OcrEngineMode mode) async {
  await prefs.setString(prefOcrEngineMode, mode.name);
}

OcrVisionQuality readOcrVisionQuality(SharedPreferences prefs) {
  return prefs.getString(prefOcrVisionQuality) == 'high' ? OcrVisionQuality.high : OcrVisionQuality.low;
}

Future<void> saveOcrVisionQuality(SharedPreferences prefs, OcrVisionQuality quality) async {
  await prefs.setString(prefOcrVisionQuality, quality.name);
}

bool readOnDeviceOcrEnabled(SharedPreferences prefs) {
  return prefs.getBool(prefOnDeviceOcr) ?? false;
}

Future<void> saveOnDeviceOcrEnabled(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool(prefOnDeviceOcr, enabled);
}
