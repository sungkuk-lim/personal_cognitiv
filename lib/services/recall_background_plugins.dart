import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';

/// Workmanager 백그라운드 isolate에서 Geolocator·알림 등 플러그인 등록.
Future<void> ensureRecallBackgroundPlugins() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
}
