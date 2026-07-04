import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/services/person_contact_avatar_service.dart';
import 'package:personal_cognitive/utils/person_avatar_utils.dart';

void main() {
  test('contactPhotoLookupKey keeps compound parent names', () {
    expect(contactPhotoLookupKey('예린엄마'), '예린엄마');
    expect(contactPhotoLookupKey('예린 엄마'), '예린엄마');
    expect(contactPhotoLookupKey('엄마'), contactPhotoLookupKey('어머니'));
  });

  test('contactLookupAliases links 예린엄마 and 예린어머니', () {
    final graph = contactLookupAliases('예린엄마').toSet();
    expect(graph, contains('예린엄마'));
    expect(graph, contains('예린어머니'));
  });

  test('contactIndexKeysForContact indexes structured 예린+엄마 as 예린엄마', () {
    final keys = contactIndexKeysForContact(
      displayName: '엄마',
      firstName: '예린',
      lastName: '엄마',
    );
    expect(keys, contains('예린엄마'));
    expect(keys, contains('예린어머니'));
    expect(
      contactKeysOverlap(keys, contactLookupAliases('예린엄마')),
      isTrue,
    );
  });

  test('photoForName matches graph 예린엄마 to indexed 예린어머니', () {
    final photo = Uint8List.fromList([1, 2, 3]);
    final index = {'예린어머니': photo};
    expect(PersonContactAvatarService.photoForName(index, '예린엄마'), photo);
  });

  test('normalizeContactDisplayName handles parenthesis form', () {
    expect(normalizeContactDisplayName('엄마(예린)'), '예린엄마');
    expect(contactPhotoLookupKey('엄마(예린)'), '예린엄마');
  });

  test('contactNamesLikelyMatch handles 예린엄마 variants', () {
    expect(contactNamesLikelyMatch('예린 엄마', '예린엄마'), isTrue);
    expect(contactNamesLikelyMatch('예린어머니', '예린엄마'), isTrue);
  });

  test('personAvatarInitial uses first character', () {
    expect(personAvatarInitial('민수'), '민');
    expect(personAvatarInitial('예린엄마'), '예');
  });
}
