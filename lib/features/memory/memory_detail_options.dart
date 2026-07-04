/// 상세 화면 표시·편집 옵션.
enum MemoryDetailPresentation {
  /// 타임라인·관계망: 사진·동영상 추가·삭제 가능.
  full,
  /// 회상(공통): 보기만, 추가 버튼 없음.
  replayShared,
  /// 회상(가벼운): 사진·메모·동영상만 크게.
  replayLight,
}

class MemoryDetailOptions {
  const MemoryDetailOptions({
    this.presentation = MemoryDetailPresentation.full,
    this.autoPlayVideo = false,
    this.showReturnBar = false,
    this.graphMediaAnchorNodeId,
  });

  final MemoryDetailPresentation presentation;
  final bool autoPlayVideo;
  /// 관계망 AI 시트 등 이전 화면으로 돌아가기 버튼.
  final bool showReturnBar;
  /// 관계망에서 노드를 탭한 뒤 사진·동영상을 붙일 때 대상 앵커 노드 ID.
  final String? graphMediaAnchorNodeId;

  bool get allowAddPhoto => presentation == MemoryDetailPresentation.full;
  bool get allowAddVideo => presentation == MemoryDetailPresentation.full;
  bool get allowDeletePhoto => presentation == MemoryDetailPresentation.full;
  bool get allowDeleteVideo => presentation == MemoryDetailPresentation.full;
  bool get isLight => presentation == MemoryDetailPresentation.replayLight;
  bool get isEditable => presentation == MemoryDetailPresentation.full;
}
