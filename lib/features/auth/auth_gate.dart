import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../services/local_memory_store.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session);
});

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(authSessionProvider);
    final guest = ref.watch(guestModeProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => guest ? child : const AuthScreen(),
      data: (session) => (session != null || guest) ? child : const AuthScreen(),
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
    });
    final prefs = ref.read(preferencesProvider);
    await writeGuestMode(prefs, true);
    await writePrivacyLocalMode(prefs, true);
    ref.read(guestModeProvider.notifier).state = true;
    ref.read(privacyLocalModeProvider.notifier).state = true;
    if (mounted) setState(() => _loading = false);
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
      return '이메일 발송 한도 초과입니다.\n'
          'Supabase 대시보드에서 Confirm email을 끄거나, '
          '1시간 후 다시 시도하세요.';
    }
    if (lower.contains('invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
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
              Text('MemoryOS', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                        }),
                child: Text(_isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
