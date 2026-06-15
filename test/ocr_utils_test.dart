import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/ocr_utils.dart';

void main() {
  test('isJunkOcrMetaResponse rejects empty meta phrases', () {
    expect(isJunkOcrMetaResponse(''), isTrue);
    expect(isJunkOcrMetaResponse('사진에서 글자를 찾지 못했습니다'), isTrue);
    expect(isJunkOcrMetaResponse('해리 포터와 마법사의 돌'), isFalse);
  });

  test('sanitizeEntities filters long junk keywords', () {
    final result = sanitizeEntities(['카페', '이미지에서 글자를 추출할 수 없다는 불편함', '제주도']);
    expect(result, contains('카페'));
    expect(result, contains('제주도'));
    expect(result.any((e) => e.contains('추출')), isFalse);
  });
}
