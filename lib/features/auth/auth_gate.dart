import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_config.dart';
import '../../core/env.dart';
import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../services/local_memory_store.dart';
import 'password_recovery_screen.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  if (!AppEnv.isConfigured) {
    return Stream<Session?>.value(null);
  }
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session);
});

/// 비밀번호 재설정 링크로 앱이 열렸을 때 true.
final passwordRecoveryModeProvider = StateProvider<bool>((ref) => false);

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    if (!AppEnv.isConfigured) return;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryModeProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppEnv.isConfigured) {
      return widget.child;
    }

    final sessionAsync = ref.watch(authSessionProvider);
    final guest = ref.watch(guestModeProvider);
    final recovery = ref.watch(passwordRecoveryModeProvider);

    if (recovery) {
      return PasswordRecoveryScreen(
        onComplete: () {
          ref.read(passwordRecoveryModeProvider.notifier).state = false;
          ref.read(guestModeProvider.notifier).state = false;
        },
      );
    }

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => guest ? widget.child : const AuthScreen(),
      data: (session) => (session != null || guest) ? widget.child : const AuthScreen(),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enterGuestMode() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final prefs = ref.read(preferencesProvider);
    await writeGuestMode(prefs, true);
    await writePrivacyLocalMode(prefs, true);
    ref.read(guestModeProvider.notifier).state = true;
    ref.read(privacyLocalModeProvider.notifier).state = true;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '비밀번호 재설정할 이메일을 입력하세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseAuthRedirectUrl(),
      );
      if (!mounted) return;
      setState(() {
        _info = '$email 로 재설정 메일을 보냈습니다.\n'
            '메일 링크를 누르면 앱이 열리고 새 비밀번호 화면이 나타납니다.\n'
            '앱이 안 열리면 링크를 길게 눌러 Chrome에서 여세요. (스팸함 확인)';
      });
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _error = '이메일과 비밀번호(6자 이상)를 입력하세요');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      } else {
        await Supabase.instance.client.auth.signUp(email: email, password: password);
      }
      final prefs = ref.read(preferencesProvider);
      await writeGuestMode(prefs, false);
      ref.read(guestModeProvider.notifier).state = false;
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('email rate limit')) {
      return '이메일 발송 한도 초과입니다.\n1시간 후 다시 시도하세요.';
    }
    if (lower.contains('invalid login credentials')) {
      return '이메일 또는 비밀번호가 맞지 않습니다.\n'
          '「비밀번호 찾기」로 재설정 메일을 받아 보세요.';
    }
    if (lower.contains('email not confirmed')) {
      return '이메일 인증이 필요합니다. 가입 시 받은 메일의 링크를 눌러 주세요.';
    }
    if (lower.contains('user already registered')) {
      return '이미 가입된 이메일입니다. 로그인을 시도하세요.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('모담넷(MemoryOS)', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _isLogin ? '내 기억에 로그인' : '새 계정 만들기',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary, height: 1.4)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_isLogin ? '로그인' : '회원가입'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loading ? null : _enterGuestMode,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('게스트로 시작 (기기 전용)'),
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                          _info = null;
                        }),
                child: Text(_isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인'),
              ),
              if (_isLogin)
                TextButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: const Text('비밀번호 찾기'),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
