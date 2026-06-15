import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_image_paths.dart';

void main() {
  late File tempImage;

  setUp(() async {
    tempImage = File('${Directory.systemTemp.path}/memoryos_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await tempImage.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  });

  tearDown(() async {
    if (await tempImage.exists()) await tempImage.delete();
  });

  final photo = Memory(
    id: 'img-1',
    content: '기기에 저장된 사진',
    summary: '기기에 저장된 사진',
    entities: const [],
    createdAt: DateTime(2025, 6, 1),
    type: 'image',
    isLocalOnly: true,
  );
  final voice1 = Memory(
    id: 'v-1',
    content: '6월 18일 여행',
    summary: '6월 18일 여행',
    entities: const [],
    createdAt: DateTime(2025, 6, 2),
    type: 'voice',
    isLocalOnly: true,
  );
  final voice2 = Memory(
    id: 'v-2',
    content: '6월 4일 근무',
    summary: '6월 4일 근무',
    entities: const [],
    createdAt: DateTime(2025, 6, 3),
    type: 'voice',
    isLocalOnly: true,
  );

  test('reconcile removes orphan key from voice memories', () {
    final path = tempImage.path;
    final paths = {'': path, 'v-1': path, 'v-2': path};
    final result = reconcileMemoryImagePaths([photo, voice1, voice2], paths);
    expect(result.containsKey(''), isFalse);
    expect(result.containsKey('v-1'), isFalse);
    expect(result.containsKey('v-2'), isFalse);
    expect(result['img-1'], path);
  });

  test('imagePathForMemory only for image type', () {
    final paths = {'img-1': tempImage.path, 'v-1': tempImage.path};
    expect(imagePathForMemory(photo, paths), tempImage.path);
    expect(imagePathForMemory(voice1, paths), isNull);
  });
}
