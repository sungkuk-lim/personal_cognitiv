import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_image_memos.dart';

void main() {
  final memory = Memory(
    id: 'm1',
    content: '기기에 저장된 사진',
    summary: '기기에 저장된 사진',
    entities: const [],
    createdAt: DateTime(2026, 6, 16),
    type: 'image',
    userMemo: '광안리에서 민수와',
  );

  test('photoMemosForMemoryId falls back to legacy userMemo', () {
    expect(
      photoMemosForMemoryId('m1', const {}, memory: memory, photoCount: 1),
      ['광안리에서 민수와'],
    );
  });

  test('displayMemoForMemory prefers stored per-photo memo', () {
    final memos = {'m1': ['첫 번째 메모', '두 번째']};
    expect(displayMemoForMemory(memory, memos, photoCount: 2), '첫 번째 메모');
  });
}
