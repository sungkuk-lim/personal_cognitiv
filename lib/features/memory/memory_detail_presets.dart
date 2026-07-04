import '../graph/graph_chat_save.dart';
import '../graph/graph_layout.dart';
import 'memory_detail_options.dart';

/// 상세 화면 프리셋 — 호출부에서 명시적으로 사용합니다.
abstract final class MemoryDetailPresets {
  static const full = MemoryDetailOptions(presentation: MemoryDetailPresentation.full);

  static const replayShared = MemoryDetailOptions(presentation: MemoryDetailPresentation.replayShared);

  static const replayLight = MemoryDetailOptions(presentation: MemoryDetailPresentation.replayLight);

  static MemoryDetailOptions graphWithVideo({required bool hasVideo}) {
    return MemoryDetailOptions(
      presentation: MemoryDetailPresentation.full,
      autoPlayVideo: hasVideo,
    );
  }

  static MemoryDetailOptions graphFromNodeAi({
    required GraphNodeData node,
    required bool hasVideo,
  }) {
    return MemoryDetailOptions(
      presentation: MemoryDetailPresentation.full,
      autoPlayVideo: hasVideo,
      showReturnBar: true,
      graphMediaAnchorNodeId: canonicalGraphAnchorNodeIdForNode(node),
    );
  }

  /// 인물·장소·활동 노드 탭 → 해당 앵커 전용 사진·동영상 상세.
  static MemoryDetailOptions graphEntityMedia({
    required GraphNodeData node,
    required bool hasVideo,
  }) {
    return MemoryDetailOptions(
      presentation: MemoryDetailPresentation.full,
      autoPlayVideo: hasVideo,
      showReturnBar: true,
      graphMediaAnchorNodeId: canonicalGraphAnchorNodeIdForNode(node),
    );
  }
}
