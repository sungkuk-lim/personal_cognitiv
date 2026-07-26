import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal_cognitive/services/care_dictionary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addHospital persists and merges into dictionary', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CareDictionaryRepository(prefs);

    await repo.addHospital('테스트병원');
    final overrides = repo.readOverrides();
    expect(overrides.hospitals, contains('테스트병원'));

    final dict = repo.loadMergedDictionary();
    expect(dict.hospitals, contains('테스트병원'));
  });

  test('removeHospital drops user override only', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CareDictionaryRepository(prefs);

    await repo.addHospital('삭제병원');
    await repo.removeHospital('삭제병원');
    expect(repo.readOverrides().hospitals, isNot(contains('삭제병원')));
  });

  test('stt typo map round-trips', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = CareDictionaryRepository(prefs);

    await repo.addTypoMapping(from: '안동병원', to: '안동병원');
    expect(repo.readOverrides().sttTypoMap['안동병원'], '안동병원');

    await repo.removeTypoMapping('안동병원');
    expect(repo.readOverrides().sttTypoMap.containsKey('안동병원'), isFalse);
  });
}
