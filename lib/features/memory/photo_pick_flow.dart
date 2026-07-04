import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 카메라 또는 갤러리 선택.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context, Map<String, String> t) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(t['photo_source_camera']!),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t['photo_source_gallery']!),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 사진 저장 전 선택 메모 입력.
Future<String?> showPhotoMemoDialog(BuildContext context, Map<String, String> t) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t['photo_memo_title']!),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: t['photo_memo_hint']!,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(t['photo_memo_skip']!)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(t['save']!)),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// 기존 기억에 사진 추가 시 간단 메모 (선택).
Future<String?> showAddPhotoMemoDialog(BuildContext context, Map<String, String> t) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t['add_photo_memo_title']!),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: t['add_photo_memo_hint']!,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(t['photo_memo_skip']!)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(t['add_photo']!)),
      ],
    ),
  );
  controller.dispose();
  return result;
}
