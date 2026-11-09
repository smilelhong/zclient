import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../m2/chat_screen.dart';
import 'login_page.dart';
import 'relay_service.dart';
import 'scan_page.dart';

/// M1 debug console (kept for protocol log/diagnostics; reachable from
/// settings). The product surface is the M3 shell.
class M1ConsolePage extends ConsumerStatefulWidget {
  const M1ConsolePage({super.key});

  @override
  ConsumerState<M1ConsolePage> createState() => _M1ConsolePageState();
}

class _M1ConsolePageState extends ConsumerState<M1ConsolePage> {
  bool _chatOpened = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final t = AppLocalizations.of(context);

    if (s.phase == 'ready' && !_chatOpened) {
      _chatOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      });
    } else if (s.phase != 'ready') {
      _chatOpened = false;
    }

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
              child: Text(t.m1Intro,
                  style: Theme.of(context).textTheme.bodySmall),
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
