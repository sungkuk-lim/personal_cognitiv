import 'env.dart';

/// Supabase 비밀번호 재설정·이메일 인증 후 앱으로 돌아오는 HTTPS 콜백.
/// AndroidManifest App Links(`https` + `/auth/v1/callback`)와 Supabase Redirect URLs에 등록.
String supabaseAuthRedirectUrl() {
  final base = AppEnv.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$base/auth/v1/callback';
}

/// Android 딥링크 호스트 — manifest `android:host` 와 일치.
String? supabaseAuthRedirectHost() {
  final uri = Uri.tryParse(AppEnv.supabaseUrl);
  return uri?.host;
}
