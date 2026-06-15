/// 빌드 시 --dart-define 으로 주입하세요.
/// 예: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppEnv {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Edge Function 미배포 시 개발용 fallback (프로덕션 빌드에서는 비워 두세요)
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const bool useEdgeProxy = bool.fromEnvironment(
    'USE_EDGE_PROXY',
    defaultValue: true,
  );

  /// Firebase Crashlytics 수집 (디버그 빌드는 기본 OFF)
  static const bool enableCrashlytics = bool.fromEnvironment(
    'ENABLE_CRASHLYTICS',
    defaultValue: true,
  );

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR_SUPABASE') && supabaseAnonKey.isNotEmpty;
}
