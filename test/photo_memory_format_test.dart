import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/utils/photo_memory_format.dart';
import 'package:personal_cognitive/models/image_memory_analysis.dart';

void main() {
  test('extractPlaceHintFromOcr finds road and bridge names', () {
    expect(extractPlaceHintFromOcr('종성로 3길'), '종성로 3길');
    expect(extractPlaceHintFromOcr('경주 월영교 야경'), '경주 월영교');
  });

  test('extractPlaceHintFromOcr does not treat person names as places', () {
    expect(extractPlaceHintFromOcr('정준호 환자 치과'), isNot(equals('정준호')));
    expect(extractPlaceHintFromOcr('이기동 환자는 치과로'), isNot(equals('이기동')));
    expect(extractPlaceHintFromOcr('김명희 안과 진료'), isNot(equals('김명희')));
  });

  test('buildPhotoDisplayTitle includes place and time', () {
    final title = buildPhotoDisplayTitle(
      placeLabel: '월영교',
      capturedAt: DateTime(2026, 6, 15, 14, 30),
      localeCode: 'ko',
    );
    expect(title, contains('월영교'));
    expect(title, contains('6월 15일'));
    expect(title, contains('14:30'));
  });

  test('portrait title includes people names', () {
    final title = buildPhotoDisplayTitle(
      placeLabel: '한라산',
      capturedAt: DateTime(2026, 6, 15, 9, 0),
      localeCode: 'ko',
      peopleNames: const ['민수'],
    );
    expect(title, contains('한라산'));
    expect(title, contains('민수'));
  });

  test('buildPhotoMemoryFieldsFromVision uses place and people for graph', () {
    final analysis = ImageMemoryAnalysis(
      extractedText: '',
      summary: '친구와 산책',
      entities: const ['공원'],
      category: 'Travel',
      subCategory: '여행',
      photoType: 'portrait',
      placeName: '월영교',
      peopleNames: const ['지연'],
      landmarks: const ['경주'],
    );

    final fields = buildPhotoMemoryFieldsFromVision(
      analysis: analysis,
      capturedAt: DateTime(2026, 6, 15, 18, 0),
      localeCode: 'ko',
      gpsPlace: '경주시',
    );

    expect(fields.summary, contains('월영교'));
    expect(fields.summary, contains('지연'));
    expect(fields.entities, contains('지연'));
    expect(fields.entities, contains('월영교'));
    expect(isGenericPhotoLabel(fields.summary), isFalse);
  });
}
