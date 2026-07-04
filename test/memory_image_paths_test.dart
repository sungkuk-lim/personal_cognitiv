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
    final paths = {'': [path], 'v-1': [path], 'v-2': [path]};
    final result = reconcileMemoryImagePaths([photo, voice1, voice2], paths);
    expect(result.containsKey(''), isFalse);
    expect(result.containsKey('v-1'), isFalse);
    expect(result.containsKey('v-2'), isFalse);
    expect(result['img-1'], [path]);
  });

  test('imagePathForMemory only for image type', () {
    final paths = {'img-1': [tempImage.path], 'v-1': [tempImage.path]};
    expect(imagePathForMemory(photo, paths), tempImage.path);
    expect(imagePathsForMemory(photo, paths).length, 1);
    expect(imagePathForMemory(voice1, paths), isNull);
  });

  test('primaryImagePathForMemoryId reads disk when prefs empty', () {
    final dir = Directory('${Directory.systemTemp.path}/memoryos_img_dir_${DateTime.now().microsecondsSinceEpoch}');
    dir.createSync(recursive: true);
    setMemoryImagesDirectoryCacheForTest(dir.path);
    final diskFile = File('${dir.path}/img-1_0.jpg');
    diskFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);

    expect(primaryImagePathForMemoryId('img-1', const {}), diskFile.path);
    expect(imageCountForMemoryId('img-1', const {}), 1);

    diskFile.deleteSync();
    dir.deleteSync();
    resetMemoryImagesDirectoryCacheForTest();
  });

  test('resolvedImagePaths prefers prefs over disk legacy duplicate', () {
    final dir = Directory('${Directory.systemTemp.path}/memoryos_img_dup_${DateTime.now().microsecondsSinceEpoch}');
    dir.createSync(recursive: true);
    setMemoryImagesDirectoryCacheForTest(dir.path);
    final legacy = File('${dir.path}/dup-1.jpg');
    final indexed = File('${dir.path}/dup-1_0.jpg');
    legacy.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    indexed.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);

    final fromPrefs = resolvedImagePathsForMemoryId('dup-1', {
      'dup-1': [indexed.path],
    });
    expect(fromPrefs, [indexed.path]);
    expect(fromPrefs.length, 1);

    legacy.deleteSync();
    indexed.deleteSync();
    dir.deleteSync();
    resetMemoryImagesDirectoryCacheForTest();
  });
}
