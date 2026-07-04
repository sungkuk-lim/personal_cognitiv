import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/system_ui.dart';
import 'features/auth/auth_gate.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'providers/app_providers.dart';

class MemoryOSApp extends ConsumerWidget {
  const MemoryOSApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seed = ref.watch(seedColorProvider);
    final lightTheme = AppTheme.theme(seed: seed, brightness: Brightness.light);
    final darkTheme = AppTheme.theme(seed: seed, brightness: Brightness.dark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: ref.watch(languageProvider),
      theme: lightTheme,
      darkTheme: darkTheme,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(systemUiOverlayForBrightness(brightness));
        ensureStatusBarVisible();
        return child ?? const SizedBox.shrink();
      },
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: const AuthGate(child: MainNavigationScreen()),
    );
  }
}
