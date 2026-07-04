import 'package:flutter/material.dart';

/// 스크롤 위치에 따라 월 헤더·그리드에 서로 다른 속도로 이동시킵니다.
class ReplayParallaxSection extends StatefulWidget {
  const ReplayParallaxSection({
    super.key,
    required this.sectionKey,
    required this.header,
    required this.content,
  });

  final int sectionKey;
  final Widget header;
  final Widget content;

  @override
  State<ReplayParallaxSection> createState() => ReplayParallaxSectionState();
}

class ReplayParallaxSectionState extends State<ReplayParallaxSection> {
  final GlobalKey _boxKey = GlobalKey();
  double _headerShift = 0;
  double _contentShift = 0;

  void updateFromScroll(BuildContext context) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = box.localToGlobal(Offset.zero).dy;
    final centerRatio = (top + box.size.height * 0.5) / screenHeight - 0.5;
    final parallax = centerRatio.clamp(-1.0, 1.0);

    final header = parallax * 14;
    final content = parallax * 6;
    if ((header - _headerShift).abs() < 0.4 && (content - _contentShift).abs() < 0.4) return;

    setState(() {
      _headerShift = header;
      _contentShift = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _boxKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            offset: Offset(0, _headerShift),
            child: widget.header,
          ),
          Transform.translate(
            offset: Offset(0, _contentShift),
            child: widget.content,
          ),
        ],
      ),
    );
  }
}

/// ListView 스크롤 시 등록된 [ReplayParallaxSection]을 갱신합니다.
mixin ReplayParallaxController {
  final Map<int, GlobalKey<ReplayParallaxSectionState>> parallaxSectionKeys = {};

  GlobalKey<ReplayParallaxSectionState> keyForSection(int index) {
    return parallaxSectionKeys.putIfAbsent(index, GlobalKey<ReplayParallaxSectionState>.new);
  }

  void refreshParallaxSections(BuildContext context) {
    for (final key in parallaxSectionKeys.values) {
      key.currentState?.updateFromScroll(context);
    }
  }
}
