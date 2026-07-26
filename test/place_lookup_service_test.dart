import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:personal_cognitive/services/place_lookup_service.dart';

void main() {
  test('formatFullAddress combines road and lot number', () {
    final p = Placemark(
      administrativeArea: '경상북도',
      locality: '안동시',
      thoroughfare: '한화2길',
      subThoroughfare: '33-21',
    );
    expect(
      PlaceLookupService.formatFullAddress(p),
      '경상북도 안동시 한화2길 33-21',
    );
  });

  test('formatFullAddress extracts road from street field', () {
    final p = Placemark(
      administrativeArea: '경상북도',
      locality: '안동시',
      street: '한화2길 33-21',
      subThoroughfare: '33-21',
    );
    final result = PlaceLookupService.formatFullAddress(p);
    expect(result, isNotNull);
    expect(result, contains('한화2길'));
    expect(result, contains('33-21'));
    expect(PlaceLookupService.isAddressMissingRoadName(result!), isFalse);
  });

  test('does not accept admin + lot without road', () {
    final p = Placemark(
      administrativeArea: '경상북도',
      locality: '안동시',
      subThoroughfare: '33-21',
    );
    expect(PlaceLookupService.formatFullAddress(p), isNull);
    expect(
      PlaceLookupService.isAddressMissingRoadName('경상북도 안동시 33-21'),
      isTrue,
    );
  });
}
