import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/status.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
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
            padding: const EdgeInsets.fromLTRB(AppSpace.screen, 8,
                AppSpace.screen, 4),
            child: ZFilterChips<String>(
              selected: _filter,
              onSelect: (v) => setState(() => _filter = v),
              options: [
                ('all', t.filterAll),
                ('running', t.filterRunning),
                ('done', t.filterDone),
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
                              horizontal: AppSpace.screen - 4, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final e = filtered[i];
                            final running = e.phase == 'running' ||
                                e.phase == 'prewarming';
                            return StaggerIn(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ZListRow(
                                  icon: running
                                      ? Icons.autorenew
                                      : Icons.task_alt_outlined,
                                  title: e.title.isEmpty
                                      ? t.untitledSession
                                      : e.title,
                                  highlighted: e.sessionId == s.sessionId,
                                  subtitle: (e.lastAssistantPreview ?? '')
                                          .isNotEmpty
                                      ? Text(
                                          _plaintext(e.lastAssistantPreview!),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      running
                                          ? const StatusDot.running()
                                          : StatusDot.solid(ZColors.okDot(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .brightness)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _relativeTime(e.lastActivityAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontFeatures:
                                                  tabularNumbers,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await ctrl.switchSession(e.sessionId);
                                    if (context.mounted) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ChatScreen()),
                                      );
                                    }
                                  },
                                ),
                              ),
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


/// Session-page helpers (plain text preview + relative time).
String _plaintext(String src) => src
    .replaceAll(RegExp(r'\*\*?([^*]+)\*\*?'), r'$1')
    .replaceAll('`', '')
    .replaceAll(RegExp(r'^#+\s*'), '')
    .trim();

String _relativeTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day) {
    return '昨天';
  }
  return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
