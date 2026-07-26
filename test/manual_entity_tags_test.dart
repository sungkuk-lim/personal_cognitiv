import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_edit.dart';
import 'package:personal_cognitive/utils/memory_theme_tags.dart';

void main() {
  test('manual entity tags are shown even when not in content', () {
    final memory = Memory(
      id: 'm1',
      content: '오늘 수박을 먹었다',
      summary: '수박',
      entities: ['김경희', 'tag:entities_manual'],
      createdAt: DateTime(2025, 6, 1),
    );

    final tags = displayTagsForMemory(memory);
    expect(tags, contains('김경희'));
    expect(displayEntitiesForMemory(memory), contains('김경희'));
  });
}
