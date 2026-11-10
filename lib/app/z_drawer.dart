import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/relay_service.dart';
import '../protocol/conversation.dart';
import 'devices_page.dart';
import 'settings_page.dart';

/// dsh-Go sessions_drawer source-exact rewrite.
/// Key patterns: contentEdge=10 / textEdge=20 dual grid; the ONLY solid
/// accent is 新会话; chips are borderless ink-on-select; identity bar
/// carries the host + two 44dp round keys.
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

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- brand row: LTRB(20,14,10,10) per dsh ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 19,
                          height: 19,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: Text('Z',
                              style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Text('ZClient',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  // 新会话: 36h stadium, the ONE solid primary (dsh #6)
                  _NewChatPill(enabled: s.phase == 'ready'),
                ],
              ),
            ),
            // ---- filter chips: borderless, ink select (dsh #7) ----
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
                    _InkChip(
                      label: f.$2,
                      selected: _filter == f.$1,
                      onTap: () => setState(() => _filter = f.$1),
                    ),
                  ],
                ],
              ),
            ),
            // ---- session list: 44h rows, primary@.09/.18 select (dsh #9) ----
            Expanded(
              child: s.phase != 'ready'
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.sessionsNeedConnect,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  : _SessionList(
                      sessions: sessions,
                      activeId: s.sessionId,
                      onTap: (id) {
                        ctrl.switchSession(id);
                        if (MediaQuery.sizeOf(context).width < 840) {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
            ),
            // ---- identity bar: LTRB(10,9,10,13), 44 keys icon 22 ----
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 13),
              child: Row(
                children: [
                  // host avatar: 36 circle
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8EEE4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.terminal,
                        size: 22, color: Color(0xFF155E66)),
                  ),
                  const SizedBox(width: 8),
                  // host name + status line (dot 6 + gap 6)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _push(context, const DevicesPage()),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.deviceName ?? 'ZCode',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: s.phase == 'ready'
                                      ? ZColors.okDot(scheme.brightness)
                                      : scheme.outline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.phase == 'ready' ? '已连接' : '未连接',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontFeatures: tabularNumbers,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // two 44 round keys icon 22 gap 8 (dsh #8)
                  _RoundKey(
                    icon: Icons.apps_outlined,
                    onTap: () => _push(context, const DevicesPage()),
                  ),
                  const SizedBox(width: 8),
                  _RoundKey(
                    icon: Icons.settings_outlined,
                    onTap: () => _push(context, const SettingsPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

/// 新会话 — 36h stadium pill, primary bg, icon 20 + label.
/// The ONLY solid-primary element in the drawer (dsh "一实多虚").
class _NewChatPill extends ConsumerWidget {
  const _NewChatPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? ZColors.accent : ZColors.accent.withValues(alpha: .4),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => ref.read(m1Provider.notifier).newSession() : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 15, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined,
                    size: 20, color: scheme.onPrimary),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).newSession,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: scheme.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Borderless ink chip (dsh capsule_chip): unselected onSurface@5%,
/// selected onSurface(ink) with surface text. fontSize 13.
class _InkChip extends StatelessWidget {
  const _InkChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : const Color(0xFF3C4C56),
              )),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          backgroundColor:
              dark ? Colors.white.withValues(alpha: .07) : ZColors.chipUnselBg,
          selectedColor:
              dark ? Colors.white : ZColors.accent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      ),
    );
  }
}

/// 44×44 round glass key, icon 22 (dsh _RoundButton).
class _RoundKey extends StatelessWidget {
  const _RoundKey({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: AppKeys.roundKeySize,
      height: AppKeys.roundKeySize,
      child: Material(
        color: scheme.surface.withValues(alpha: .8),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon,
              size: AppKeys.roundKeyIcon, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Plain-text session rows at 44dp height (dsh #9).
class _SessionList extends ConsumerWidget {
  const _SessionList({
    required this.sessions,
    required this.activeId,
    required this.onTap,
  });

  final List<SessionEntry> sessions;
  final String? activeId;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.noSessions,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: sessions.length,
      itemBuilder: (_, i) {
        final e = sessions[i];
        final active = e.sessionId == activeId;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: active
                ? scheme.primary.withValues(alpha: .18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(e.sessionId),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      e.title.isEmpty ? t.untitledSession : e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
