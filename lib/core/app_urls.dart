/// 상용 배포용 공개 URL — `--dart-define=PRIVACY_POLICY_URL=...` 로 덮어쓸 수 있습니다.
abstract final class AppUrls {
  static const String privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://thenext-dev.github.io/personal_cognitiv/privacy.html',
  );

  static const String marketingSite = String.fromEnvironment(
    'MARKETING_SITE_URL',
    defaultValue: 'https://thenext-dev.github.io/personal_cognitiv/',
  );

  static const String userGuide = String.fromEnvironment(
    'USER_GUIDE_URL',
    defaultValue: 'https://thenext-dev.github.io/personal_cognitiv/user_guide.html',
  );
}
