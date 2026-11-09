import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../m1/relay_service.dart';
import '../m2/chat_screen.dart';
import '../protocol/conversation.dart';
import 'connection_banner.dart';

/// M3 sessions tab: sessions of the connected workspace from the live
/// sessions index — status filter chips (全部/进行中/已完成, selected =
/// dark-ink pill per design §7.3) + time-grouped list (§7.4).
class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Rebuild on index ticks (frames) and phase changes.
    ref.watch(m1Provider.select((s) => s.sessionsTick));
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final index = ctrl.sessionsIndex;

    final sessions = index?.list ?? <SessionEntry>[];
    final filtered = sessions.where((e) {
      switch (_filter) {
        case 'running':
          return e.phase == 'running' || e.phase == 'prewarming';
        case 'done':
          return e.phase != 'running' && e.phase != 'prewarming';
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.tabSessions,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -.5),
        ),
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: t.filterAll,
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: t.filterRunning,
                  selected: _filter == 'running',
                  onTap: () => setState(() => _filter = 'running'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: t.filterDone,
                  selected: _filter == 'done',
                  onTap: () => setState(() => _filter = 'done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: s.phase != 'ready'
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 48, color: scheme.primary.withValues(alpha: .3)),
                        const SizedBox(height: 10),
                        Text(t.sessionsNeedConnect,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? Center(child: Text(t.noSessions))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            await ctrl.switchSession(s.sessionId ?? ''),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final e = filtered[i];
                            return _SessionRow(
                              entry: e,
                              active: e.sessionId == s.sessionId,
                              onTap: () async {
                                await ctrl.switchSession(e.sessionId);
                                if (context.mounted) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const ChatScreen()),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF26282E) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? const Color(0xFF26282E)
                : scheme.outline.withValues(alpha: .5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.entry, required this.active, required this.onTap});

  final SessionEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final running =
        entry.phase == 'running' || entry.phase == 'prewarming';

    return Card(
      elevation: 0,
      color: active ? scheme.primaryContainer.withValues(alpha: .35) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                running ? Icons.autorenew : Icons.check_circle_outline,
                size: 20,
                color: running ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? t.untitledSession : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if ((entry.lastAssistantPreview ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _plaintext(entry.lastAssistantPreview!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _relativeTime(entry.lastActivityAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(int ms) {
    final delta = DateTime.now().millisecondsSinceEpoch - ms;
    if (delta < 0) return '';
    final min = delta ~/ 60000;
    if (min < 1) return '刚刚';
    if (min < 60) return '$min 分钟前';
    final h = min ~/ 60;
    if (h < 24) return '$h 小时前';
    final d = h ~/ 24;
    if (d < 7) return '$d 天前';
    return '${DateTime.fromMillisecondsSinceEpoch(ms).month}/'
        '${DateTime.fromMillisecondsSinceEpoch(ms).day}';
  }

  /// Strips markdown noise so list previews read as plain text.
  static String _plaintext(String src) => src
      .replaceAll(RegExp(r'\*\*?([^*]+)\*\*?'), r'$1')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'^#+\s*'), '')
      .trim();
}
