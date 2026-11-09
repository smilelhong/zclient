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

  /// Long-press action sheet per session (parity #7).
  Future<void> _sessionSheet(
      BuildContext context, M1Controller ctrl, SessionEntry e) async {
    final running = e.phase == 'running' || e.phase == 'prewarming';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('置顶 / 取消置顶'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            if (running)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('停止运行'),
                onTap: () => Navigator.pop(ctx, 'stop'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text('删除会话',
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        final ctrlText = TextEditingController(text: e.title);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('重命名会话'),
            content: TextField(controller: ctrlText, autofocus: true),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrlText.text.trim()),
                child: const Text('保存'),
              ),
            ],
          ),
        );
        if (name != null && name.isNotEmpty) await ctrl.renameSession(e.sessionId, name);
      case 'pin':
        await ctrl.setSessionPinned(e.sessionId, true);
      case 'stop':
        await ctrl.stopSession(e.sessionId);
      case 'delete':
        await ctrl.deleteSession(e.sessionId);
    }
  }

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
                                  onLongPress: () =>
                                      _sessionSheet(context, ctrl, e),
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
