/// 관계망 화면 표시 방식 — 캔버스 그래프 vs 접근성 목록.
enum GraphDisplayMode {
  canvas,
  list,
}

GraphDisplayMode graphDisplayModeFromString(String? raw) {
  switch (raw) {
    case 'list':
      return GraphDisplayMode.list;
    default:
      return GraphDisplayMode.canvas;
  }
}

String graphDisplayModeToString(GraphDisplayMode mode) {
  switch (mode) {
    case GraphDisplayMode.canvas:
      return 'canvas';
    case GraphDisplayMode.list:
      return 'list';
  }
}
