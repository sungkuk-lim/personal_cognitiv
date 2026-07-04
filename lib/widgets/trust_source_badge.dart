import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../utils/trust_source.dart';

/// 타임라인·상세에 「내 기록 / AI 보조」 표시.
class TrustSourceBadge extends StatelessWidget {
  const TrustSourceBadge({
    super.key,
    required this.memory,
    this.compact = false,
  });

  final Memory memory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final source = trustSourceForMemory(memory);
    final (icon, label, color) = switch (source) {
      MemoryTrustSource.userRecord => (
          Icons.edit_note_rounded,
          compact ? '내 기록' : '내가 남긴 기록',
          Colors.teal.shade600,
        ),
      MemoryTrustSource.aiAssist => (
          Icons.auto_awesome_rounded,
          compact ? 'AI 보조' : 'AI가 정리한 메모',
          Colors.deepPurple.shade400,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 13, color: color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
