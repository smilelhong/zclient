import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/gen/app_localizations.dart';

import 'm1/login_page.dart';
import 'm1/relay_service.dart';
import 'm1/scan_page.dart';

void main() {
  runApp(const ProviderScope(child: ZClientApp()));
}

class ZClientApp extends StatelessWidget {
  const ZClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Design-system v1.1: seed misty-blue #3D6B9E, primary pinned exact.
    const seed = Color(0xFF3D6B9E);
    final scheme = ColorScheme.fromSeed(seedColor: seed).copyWith(primary: seed);
    return MaterialApp(
      onGenerateTitle: (context) => 'ZClient',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const M1ConsolePage(),
    );
  }
}

class M1ConsolePage extends ConsumerWidget {
  const M1ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final t = AppLocalizations.of(context);
    final phaseLabel = switch (s.phase) {
      'connecting' => t.phase_connecting,
      'paired' => t.phase_paired,
      'bootstrapped' => t.phase_bootstrapped,
      'ready' => t.phase_ready,
      'error' => t.phase_error,
      _ => t.phase_idle,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.m1Title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text(phaseLabel),
                visualDensity: VisualDensity.compact,
                backgroundColor: s.phase == 'error'
                    ? Theme.of(context).colorScheme.errorContainer
                    : s.phase == 'ready'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                t.m1Intro,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _login(context, ctrl),
                    icon: const Icon(Icons.login),
                    label: Text(
                      s.jwtHost != null ? t.loggedIn(s.jwtHost!) : t.login,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _scan(context, ctrl),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                      s.params != null
                          ? t.linkReady(s.params!.passHash.isEmpty ? '4' : '3')
                          : t.scanPair,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: s.params == null || s.phase == 'connecting'
                        ? null
                        : ctrl.connect,
                    icon: const Icon(Icons.bolt),
                    label: Text(t.connect),
                  ),
                ],
              ),
            ),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  s.error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: s.phase == 'ready',
                      decoration: InputDecoration(hintText: t.messageHint),
                      onSubmitted: s.sending ? null : ctrl.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: s.phase == 'ready' && !s.sending
                        ? () => ctrl.send('你好，这是 ZClient M1 的第一条消息。')
                        : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [Tab(text: t.transcript), Tab(text: t.log)],
                    ),
                    const Expanded(
                      child: TabBarView(
                        children: [_TranscriptView(), _LogView()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context, M1Controller ctrl) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => M1LoginPage(
          host: M1Controller.loginHost,
          onHarvested: ctrl.onLoginHarvested,
        ),
      ),
    );
  }

  Future<void> _scan(BuildContext context, M1Controller ctrl) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const M1ScanPage()),
    );
    if (raw != null) ctrl.setLink(raw);
  }
}

class _TranscriptView extends ConsumerWidget {
  const _TranscriptView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(m1Provider.select((s) => s.rows));
    if (rows.isEmpty) {
      return const Center(child: Text('—'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SelectableText(rows[i]),
      ),
    );
  }
}

class _LogView extends ConsumerWidget {
  const _LogView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(m1Provider.select((s) => s.log));
    return Container(
      color: const Color(0xFF10141B),
      width: double.infinity,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: log.length,
        itemBuilder: (_, i) => SelectableText(
          log[i],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: Color(0xFF9FE8B5),
          ),
        ),
      ),
    );
  }
}
