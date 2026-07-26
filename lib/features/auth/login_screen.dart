import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../providers/care_dictionary_provider.dart';
import '../../providers/memory_notifier.dart';
import '../../services/app_lock_service.dart';
import '../../services/firebase_email_auth_service.dart';
import '../../services/local_memory_store.dart';
import 'pattern_lock_screen.dart';

enum _LoginPath { chooser, email, guest, device }

/// 상용 로그인 — 이메일 / 게스트 / 기기 보안(지문·패턴) 중 선택.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _LoginPath _path = _LoginPath.chooser;
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  bool _bioAvailable = false;
  String? _error;
  String? _info;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _probeBiometrics();
  }

  Future<void> _probeBiometrics() async {
    final ok = await AppLockService.instance.canCheckBiometrics();
    if (mounted) setState(() => _bioAvailable = ok);
  }

  @override
  void dispose() {
    _fade.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _backToChooser() {
    setState(() {
      _path = _LoginPath.chooser;
      _error = null;
      _info = null;
      _loading = false;
    });
  }

  Future<void> _enterGuestMode({bool offerLock = true}) async {
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
    if (mounted) {
      setState(() => _loading = false);
      if (offerLock) await _maybeOfferLockSetup();
    }
  }

  /// 기기 보안 경로: 게스트(기기 전용)로 진입 후 지문/패턴 설정·인증.
  Future<void> _enterWithDeviceSecurity() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final prefs = ref.read(preferencesProvider);
    final lock = AppLockService.instance;
    final bioOn = lock.readBiometricEnabled(prefs);
    final patternOn = lock.readPatternEnabled(prefs);

    if (bioOn && _bioAvailable) {
      final ok = await lock.authenticateBiometric(reason: '모담넷을 열려면 지문을 확인합니다');
      if (!ok) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = '지문 인증에 실패했습니다. 다시 시도하거나 다른 방법을 선택하세요.';
          });
        }
        return;
      }
      await _enterGuestMode(offerLock: false);
      return;
    }

    if (patternOn && await lock.hasPattern()) {
      if (!mounted) return;
      setState(() => _loading = false);
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PatternLockScreen(
            mode: PatternLockMode.unlock,
            title: '패턴으로 열기',
            subtitle: '등록한 패턴을 그려 주세요',
            onCancel: () => Navigator.pop(context, false),
            onUnlocked: () => Navigator.pop(context, true),
          ),
        ),
      );
      if (unlocked == true) {
        await _enterGuestMode(offerLock: false);
      }
      return;
    }

    // 아직 잠금 미설정 → 게스트 진입 후 설정 유도
    await _enterGuestMode(offerLock: true);
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
      await FirebaseEmailAuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _info = '$email 으로 재설정 메일을 보냈습니다.\n스팸함도 확인해 주세요.';
      });
    } catch (e) {
      setState(() => _error = FirebaseEmailAuthService.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final auth = FirebaseEmailAuthService.instance;
      if (_isLogin) {
        await auth.signIn(email: email, password: password);
      } else {
        await auth.signUp(email: email, password: password);
        if (mounted) {
          setState(() => _info = '계정이 만들어졌습니다. 바로 이용할 수 있습니다.');
        }
      }
      final prefs = ref.read(preferencesProvider);
      await writeGuestMode(prefs, false);
      await writePrivacyLocalMode(prefs, false);
      ref.read(guestModeProvider.notifier).state = false;
      ref.read(privacyLocalModeProvider.notifier).state = false;
      await ref.read(memoryListProvider.notifier).reload();
      ref.read(careDictionaryProvider.notifier).syncOnLoginSilently();
      if (mounted) await _maybeOfferLockSetup();
    } catch (e) {
      setState(() => _error = FirebaseEmailAuthService.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybeOfferLockSetup() async {
    final prefs = ref.read(preferencesProvider);
    final lock = AppLockService.instance;
    if (lock.readBiometricEnabled(prefs) || lock.readPatternEnabled(prefs)) return;
    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('기기 잠금 설정', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '다음에 앱을 열 때 지문 또는 패턴으로 빠르게 보호할 수 있습니다.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              if (_bioAvailable)
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'bio'),
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('지문 잠금 켜기'),
                ),
              if (_bioAvailable) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'pattern'),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('패턴 등록'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('나중에')),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'bio') {
      final ok = await lock.authenticateBiometric(reason: '지문 잠금을 켜려면 인증하세요');
      if (ok) {
        await lock.writeBiometricEnabled(prefs, true);
        ref.read(appLockRevisionProvider.notifier).state++;
      }
    } else if (choice == 'pattern') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => PatternLockScreen(
            mode: PatternLockMode.register,
            title: '패턴 등록',
            subtitle: '잠금 해제에 사용할 패턴을 그려 주세요',
            onCancel: () => Navigator.pop(ctx),
            onRegistered: () async {
              await lock.writePatternEnabled(prefs, true);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('패턴 잠금이 등록되었습니다.')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0D47A1).withValues(alpha: 0.95),
                    const Color(0xFF00897B).withValues(alpha: 0.9),
                    scheme.surface,
                  ],
                  stops: const [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _BrandHeader(
                          subtitle: switch (_path) {
                            _LoginPath.chooser => '로그인 방법을 선택하세요',
                            _LoginPath.email => _isLogin ? '이메일로 로그인' : '이메일로 가입',
                            _LoginPath.guest => '기기에서만 안전하게',
                            _LoginPath.device => '지문·패턴으로 열기',
                          },
                        ),
                        const SizedBox(height: 28),
                        if (_path == _LoginPath.chooser) _buildChooser(scheme, theme),
                        if (_path == _LoginPath.email) _buildEmailCard(scheme, theme),
                        if (_path == _LoginPath.guest) _buildGuestCard(scheme, theme),
                        if (_path == _LoginPath.device) _buildDeviceCard(scheme, theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooser(ColorScheme scheme, ThemeData theme) {
    return Column(
      children: [
        _MethodCard(
          icon: Icons.mail_outline_rounded,
          title: '이메일 계정',
          subtitle: '클라우드 동기화 · Pro 구독 · AI 기능',
          onTap: () => setState(() => _path = _LoginPath.email),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.phone_android_rounded,
          title: '게스트 (기기 전용)',
          subtitle: '로그인 없이 이 기기에만 기억 저장',
          onTap: () => setState(() => _path = _LoginPath.guest),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.fingerprint_rounded,
          title: '지문 · 패턴으로 열기',
          subtitle: _bioAvailable
              ? '기기 보안으로 빠르게 시작 (로컬 모드)'
              : '패턴 등록 후 빠르게 시작 (로컬 모드)',
          onTap: () => setState(() => _path = _LoginPath.device),
        ),
        const SizedBox(height: 20),
        Text(
          'Pro·AI·클라우드 동기화는 이메일 계정이 필요합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildEmailCard(ColorScheme scheme, ThemeData theme) {
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(onPressed: _loading ? null : _backToChooser, icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(
                    child: Text(
                      _isLogin ? '이메일로 로그인' : '새 계정 만들기',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('클라우드 기억·구독·AI는 이 계정으로 연결됩니다.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty || !t.contains('@')) return '이메일을 입력하세요';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: '이메일',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                validator: (v) {
                  if ((v ?? '').length < 6) return '비밀번호 6자 이상';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _Banner(text: _error!, tone: _BannerTone.error),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                _Banner(text: _info!, tone: _BannerTone.info),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        _isLogin ? '로그인' : '회원가입',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isLogin = !_isLogin;
                                _error = null;
                                _info = null;
                              }),
                      child: Text(_isLogin ? '회원가입' : '로그인으로', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (_isLogin)
                    Expanded(
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('비밀번호 찾기'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestCard(ColorScheme scheme, ThemeData theme) {
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(onPressed: _loading ? null : _backToChooser, icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(
                  child: Text('게스트로 시작', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '기억이 이 기기에만 저장됩니다. 클라우드 동기화·Pro AI·구독은 사용할 수 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Banner(text: _error!, tone: _BannerTone.error),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : () => _enterGuestMode(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('기기 전용으로 시작', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ColorScheme scheme, ThemeData theme) {
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(onPressed: _loading ? null : _backToChooser, icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(
                  child: Text('지문 · 패턴', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '기기 보안으로 앱을 엽니다. 로컬(게스트) 모드로 시작하며, 잠금이 없으면 설정 안내가 이어집니다.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniChip(icon: Icons.fingerprint_rounded, label: _bioAvailable ? '지문 가능' : '지문 없음'),
                const SizedBox(width: 8),
                const _MiniChip(icon: Icons.grid_view_rounded, label: '패턴'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Banner(text: _error!, tone: _BannerTone.error),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _enterWithDeviceSecurity,
              icon: Icon(_bioAvailable ? Icons.fingerprint_rounded : Icons.grid_view_rounded),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              label: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      _bioAvailable ? '지문으로 열기' : '패턴 · 잠금으로 시작',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF00897B)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.black.withValues(alpha: 0.55), height: 1.3, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.black.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/brand/modam_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Icon(Icons.hub_rounded, size: 48, color: Color(0xFF00897B)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '모담넷',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15, height: 1.35),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

enum _BannerTone { error, info }

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});

  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == _BannerTone.error
        ? scheme.errorContainer.withValues(alpha: 0.7)
        : scheme.primaryContainer.withValues(alpha: 0.7);
    final fg = tone == _BannerTone.error ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, height: 1.35, fontSize: 13)),
    );
  }
}
