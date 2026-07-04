import 'package:flutter/material.dart';

/// 사진·동영상 우측 상단 삭제 버튼.
class MediaDeleteButton extends StatelessWidget {
  const MediaDeleteButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Colors.red.shade700,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
