import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_settings.dart';
import 'app/home_shell.dart';
import 'app/notify_service.dart';
import 'design/tokens.dart';
import 'l10n/gen/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZClientApp()));
}

class ZClientApp extends ConsumerStatefulWidget {
  const ZClientApp({super.key});

  @override
  ConsumerState<ZClientApp> createState() => _ZClientAppState();
}

class _ZClientAppState extends ConsumerState<ZClientApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifyService.instance.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotifyService.instance.onLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    // Design-system v1.1: exact tokens (§2.2 light / dark counterparts),
    // quantized rhythm (§6) and one-primary-per-screen discipline.
    final light = ColorScheme.light(
      primary: ZColors.accent,
      onPrimary: Colors.white,
      primaryContainer: ZColors.lightPc,
      onPrimaryContainer: ZColors.lightOnPc,
      secondary: ZColors.accent,
      surface: ZColors.lightSurface,
      onSurface: const Color(0xFF1B1C20),
      onSurfaceVariant: const Color(0xFF4B4C55),
      surfaceContainerHighest: const Color(0xFFE9EBED),
      outline: ZColors.lightOutline,
      outlineVariant: ZColors.lightOutline,
      surfaceTint: Colors.transparent,
      tertiary: ZColors.greenDot,
      error: ZColors.danger,
    );
    final dark = ColorScheme.dark(
      primary: ZColors.darkPrimary,
      onPrimary: ZColors.darkOnPrimary,
      primaryContainer: ZColors.darkPc,
      onPrimaryContainer: ZColors.darkOnPc,
      secondary: ZColors.darkPrimary,
      surface: ZColors.darkSurface,
      onSurface: const Color(0xFFE6E9EE),
      onSurfaceVariant: const Color(0xFF9AA3AF),
      surfaceContainerHighest: const Color(0xFF242A35),
      outline: ZColors.darkOutline,
      outlineVariant: ZColors.darkOutline,
      surfaceTint: Colors.transparent,
      tertiary: ZColors.darkSuccess,
      error: const Color(0xFFF2B8B5),
    );
    final settings = ref.watch(appSettingsProvider);

    ThemeData buildTheme(ColorScheme scheme) {
      final isDark = scheme.brightness == Brightness.dark;
      return ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: ZTrack.display,
            color: scheme.onSurface,
          ),
        ),
        cardTheme: CardThemeData(
          // dsh-Go soft card: shadow only, no border (one elevation device).
          elevation: 1.5,
          color: ZColors.surface(scheme.brightness),
          shadowColor: isDark ? Colors.black54 : const Color(0x14203A50),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: ZColors.surface(scheme.brightness),
          indicatorColor: ZColors.pc(scheme.brightness),
          height: 64,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: ZTrack.label,
              color: scheme.onSurface,
            ),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: ZColors.surface(scheme.brightness),
          indicatorColor: ZColors.pc(scheme.brightness),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          iconColor: scheme.primary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: .55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: ZColors.outline(scheme.brightness),
          thickness: 1,
        ),
      );
    }

    return MaterialApp(
      onGenerateTitle: (context) => 'ZClient',
      theme: buildTheme(light),
      darkTheme: buildTheme(dark),
      themeMode: settings.theme,
      locale: settings.locale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Soft dsh-Go page gradient; dark stays flat (tokens §ZColors).
      home: DecoratedBox(
        decoration: BoxDecoration(
          gradient: settings.theme == ThemeMode.dark
              ? null
              : const LinearGradient(
                  begin: Alignment(-1, -1),
                  end: Alignment(1, 1),
                  colors: [ZColors.bgGradTop, ZColors.bgGradBottom],
                ),
          color: settings.theme == ThemeMode.dark ? ZColors.darkBg : null,
        ),
        child: const HomeShell(),
      ),
    );
  }
}
