import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_gate.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'providers/app_providers.dart';

class MemoryOSApp extends ConsumerWidget {
  const MemoryOSApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(languageProvider),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: ref.watch(seedColorProvider), brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: ref.watch(seedColorProvider), brightness: Brightness.dark),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: const AuthGate(child: MainNavigationScreen()),
    );
  }
}
