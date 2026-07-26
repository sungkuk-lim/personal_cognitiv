/// 상용 배포용 공개 URL — `--dart-define=PRIVACY_POLICY_URL=...` 로 덮어쓸 수 있습니다.
///
/// Soft launch 기본값 = 현재 동작 중인 GitHub Pages (`sungkuk-lim`).
/// 조직 `theNext-modamnet` 이전 후에는 dart-define 또는 이 기본값을 교체하세요.
/// 자세한 절차: `docs/GITHUB_PAGES.md`
abstract final class AppUrls {
  static const String _pagesBase =
      'https://sungkuk-lim.github.io/personal_cognitiv';

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
