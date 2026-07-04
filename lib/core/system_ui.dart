import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 전체화면 미디어 뷰어 등에서만 상태 표시줄을 숨깁니다.
void hideStatusBarForImmersiveViewer() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// 상태 표시줄(시간·배터리)과 내비게이션 바를 항상 표시합니다.
void ensureStatusBarVisible() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
}

SystemUiOverlayStyle systemUiOverlayForBrightness(Brightness brightness) {
  final darkIcons = brightness == Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
    statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
  );
}
