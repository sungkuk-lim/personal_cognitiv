/// 상용 배포용 공개 URL — `--dart-define=PRIVACY_POLICY_URL=...` 로 덮어쓸 수 있습니다.
///
/// GitHub Pages: 조직/계정 `theNext-modamnet` (GitHub는 `_` 불가 → 하이픈 사용)
/// 저장소 `personal_cognitiv` 기준.
abstract final class AppUrls {
  static const String _pagesBase =
      'https://thenext-modamnet.github.io/personal_cognitiv';

  static const String termsOfService = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: '$_pagesBase/terms.html',
  );

  static const String privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: '$_pagesBase/privacy.html',
  );

  static const String marketingSite = String.fromEnvironment(
    'MARKETING_SITE_URL',
    defaultValue: '$_pagesBase/',
  );

  static const String userGuide = String.fromEnvironment(
    'USER_GUIDE_URL',
    defaultValue: '$_pagesBase/user_guide.html',
  );
}
