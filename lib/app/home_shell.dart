import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/relay_service.dart';
import '../m2/chat_screen.dart';
import '../protocol/conversation.dart';
import 'devices_page.dart';
import 'settings_page.dart';

/// dsh-Go posture shell: the chat IS the home; the drawer carries the
/// conversation list, the device identity bar (switcher + settings), and
/// the 新会话 primary action. Landscape keeps the drawer docked as a
/// floating panel; portrait opens it as a slightly narrow side sheet.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawer = const ZDrawer();
    final wide = MediaQuery.sizeOf(context).width >= 600;

    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      final dark = scheme.brightness == Brightness.dark;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color:
                      dark ? ZColors.darkSurface : const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: dark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x1A203A50),
                            blurRadius: 24,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                child: drawer,
              ),
              const SizedBox(width: 12),
              const Expanded(child: ChatScreen(embedded: true)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawerEdgeDragWidth: 60,
      drawer: SizedBox(width: 280, child: drawer),
      body: const ChatScreen(embedded: false),
    );
  }
}

/// The drawer itself (dsh-visual-spec home skeleton): brand row →
/// 新会话 primary pill + device swap circle → filter chips → session
/// list (plain text rows, time groups) → bottom identity bar.
class ZDrawer extends ConsumerStatefulWidget {
  const ZDrawer({super.key});

  @override
  ConsumerState<ZDrawer> createState() => _ZDrawerState();
}

class _ZDrawerState extends ConsumerState<ZDrawer> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    ref.watch(m1Provider.select((x) => x.sessionsTick));
    final index = ctrl.sessionsIndex;
    final sessions = (index?.list ?? <SessionEntry>[])
        .where((e) => switch (_filter) {
          'running' => e.phase == 'running' || e.phase == 'prewarming',
          'done' => e.phase != 'running' && e.phase != 'prewarming',
          _ => true,
        })
        .toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // brand row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text('Z',
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Text('ZClient',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // 新会话 (primary pill) + device swap circle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed:
                        s.phase == 'ready' ? () => ctrl.newSession() : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(t.newSession,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                _CircleIcon(
                  icon: Icons.swap_horiz,
                  onTap: s.phase == 'ready'
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DevicesPage(),
                          ))
                      : null,
                ),
              ],
            ),
          ),
          // filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                for (final (i, f) in [
                  ('all', t.filterAll),
                  ('running', t.filterRunning),
                  ('done', t.filterDone),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _filter = f.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filter == f.$1
                            ? ZColors.ink
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _filter == f.$1
                              ? ZColors.ink
                              : scheme.outline,
                        ),
                      ),
                      child: Text(
                        f.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _filter == f.$1
                              ? Colors.white
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // session list (dsh plain rows + time group labels)
          Expanded(
            child: s.phase != 'ready'
                ? Center(
                    child: Text(t.sessionsNeedConnect,
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final e = sessions[i];
                      final active = e.sessionId == s.sessionId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Material(
                          color: active
                              ? scheme.primaryContainer.withValues(alpha: .5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              ctrl.switchSession(e.sessionId);
                              if (MediaQuery.sizeOf(context).width < 600) {
                                Navigator.of(context).maybePop();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              child: Text(
                                e.title.isEmpty
                                    ? t.untitledSession
                                    : e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // bottom identity bar: device + connection dot; two round
          // buttons (devices mgmt / settings)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DevicesPage())),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF1E4),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.terminal,
                              size: 20, color: Color(0xFF1E6B45)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ctrl.deviceName ?? 'ZCode',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                        color: ZColors.greenDot,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.phase == 'ready'
                                        ? '已连接'
                                        : '未连接',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CircleIcon(
                  icon: Icons.apps_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DevicesPage())),
                ),
                const SizedBox(width: 8),
                _CircleIcon(
                  icon: Icons.settings_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsPage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
