import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/memory_relative_date.dart';

void main() {
  test('relativeDayOffsetFromText detects 어제', () {
    expect(relativeDayOffsetFromText('어제 부산에서 놀았어'), -1);
  });

  test('applyRelativeDayOffset shifts calendar day', () {
    final base = DateTime(2026, 7, 3, 15, 30);
    final shifted = applyRelativeDayOffset(base, -1);
    expect(shifted.year, 2026);
    expect(shifted.month, 7);
    expect(shifted.day, 2);
    expect(shifted.hour, 15);
  });
}
