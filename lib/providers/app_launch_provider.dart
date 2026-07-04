import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 홈 위젯·딥링크로 앱을 열 때 수행할 동작.
enum AppLaunchTarget { none, capture, search, open, graph }

final appLaunchTargetProvider = StateProvider<AppLaunchTarget>((ref) => AppLaunchTarget.none);

AppLaunchTarget appLaunchTargetFromUri(Uri? uri) {
  if (uri == null) return AppLaunchTarget.none;
  switch (uri.host) {
    case 'capture':
      return AppLaunchTarget.capture;
    case 'search':
      return AppLaunchTarget.search;
    case 'open':
      return AppLaunchTarget.open;
    case 'graph':
      return AppLaunchTarget.graph;
    default:
      return AppLaunchTarget.none;
  }
}
