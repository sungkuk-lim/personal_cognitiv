import 'package:flutter/material.dart';

/// 상용 앱 스타일 9점 패턴 잠금 패드.
class PatternLockPad extends StatefulWidget {
  const PatternLockPad({
    super.key,
    required this.onCompleted,
    this.minLength = 4,
    this.errorFlash = false,
  });

  final ValueChanged<List<int>> onCompleted;
  final int minLength;
  final bool errorFlash;

  @override
  State<PatternLockPad> createState() => _PatternLockPadState();
}

class _PatternLockPadState extends State<PatternLockPad> {
  final List<int> _selected = [];
  Offset? _finger;
  List<Offset> _centers = const [];

  void _layout(Size size) {
    const inset = 28.0;
    final cell = (size.shortestSide - inset * 2) / 3;
    final origin = Offset(
      (size.width - cell * 3) / 2 + cell / 2,
      (size.height - cell * 3) / 2 + cell / 2,
    );
    _centers = [
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++)
          origin + Offset(col * cell, row * cell),
    ];
  }

  int? _hit(Offset p) {
    for (var i = 0; i < _centers.length; i++) {
      if ((_centers[i] - p).distance <= 28) return i;
    }
    return null;
  }

  void _add(int index) {
    if (_selected.contains(index)) return;
    if (_selected.isNotEmpty) {
      final mid = _midPoint(_selected.last, index);
      if (mid != null && !_selected.contains(mid)) _selected.add(mid);
    }
    _selected.add(index);
    setState(() {});
  }

  int? _midPoint(int a, int b) {
    final ar = a ~/ 3, ac = a % 3;
    final br = b ~/ 3, bc = b % 3;
    if ((ar - br).abs() == 2 && (ac - bc).abs() == 2) return 4;
    if (ar == br && (ac - bc).abs() == 2) return ar * 3 + 1;
    if (ac == bc && (ar - br).abs() == 2) return 3 + ac;
    return null;
  }

  void _finish() {
    final path = List<int>.from(_selected);
    _selected.clear();
    _finger = null;
    setState(() {});
    if (path.length >= widget.minLength) widget.onCompleted(path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = widget.errorFlash ? scheme.error : scheme.primary;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _layout(Size(constraints.maxWidth, constraints.maxHeight));
          return GestureDetector(
            onPanStart: (d) {
              final hit = _hit(d.localPosition);
              if (hit != null) _add(hit);
              setState(() => _finger = d.localPosition);
            },
            onPanUpdate: (d) {
              final hit = _hit(d.localPosition);
              if (hit != null) _add(hit);
              setState(() => _finger = d.localPosition);
            },
            onPanEnd: (_) => _finish(),
            child: CustomPaint(
              painter: _PatternPainter(
                centers: _centers,
                selected: _selected,
                finger: _finger,
                lineColor: lineColor,
                dotColor: scheme.onSurfaceVariant,
                activeColor: lineColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.centers,
    required this.selected,
    required this.finger,
    required this.lineColor,
    required this.dotColor,
    required this.activeColor,
  });

  final List<Offset> centers;
  final List<int> selected;
  final Offset? finger;
  final Color lineColor;
  final Color dotColor;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (selected.length >= 2) {
      final path = Path()..moveTo(centers[selected.first].dx, centers[selected.first].dy);
      for (var i = 1; i < selected.length; i++) {
        path.lineTo(centers[selected[i]].dx, centers[selected[i]].dy);
      }
      canvas.drawPath(path, linePaint);
    }
    if (selected.isNotEmpty && finger != null) {
      canvas.drawLine(centers[selected.last], finger!, linePaint);
    }

    for (var i = 0; i < centers.length; i++) {
      final active = selected.contains(i);
      final c = centers[i];
      canvas.drawCircle(
        c,
        active ? 14 : 10,
        Paint()..color = (active ? activeColor : dotColor).withValues(alpha: active ? 0.25 : 0.18),
      );
      canvas.drawCircle(c, active ? 8 : 6, Paint()..color = active ? activeColor : dotColor);
      if (active) {
        canvas.drawCircle(
          c,
          18,
          Paint()
            ..color = activeColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => true;
}
