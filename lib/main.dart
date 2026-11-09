import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'l10n/gen/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: ZClientApp()));
}

class ZClientApp extends StatelessWidget {
  const ZClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Design-system v1.1: seed misty-blue #3D6B9E, primary pinned exact;
    // dark scheme derived from the same seed (§2.3, full dark pass v1.2).
    const seed = Color(0xFF3D6B9E);
    final light = ColorScheme.fromSeed(seedColor: seed)
        .copyWith(primary: seed, tertiary: const Color(0xFF2E7D43));
    final dark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(tertiary: const Color(0xFF7BD88F));

    return MaterialApp(
      onGenerateTitle: (context) => 'ZClient',
      theme: ThemeData(colorScheme: light, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: dark, useMaterial3: true),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}
