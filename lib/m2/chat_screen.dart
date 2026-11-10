import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/devices_page.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/relay_service.dart';
import '../design/tokens.dart';
import '../protocol/conversation.dart';
import 'turn_models.dart';

/// M2 session screen — immersive chat per docs/design/design-system.md:
/// floating translucent top/input bars, user bubbles right, assistant turns
/// (status line → text/tool parts → file-changes card), pending-interaction
/// cards, streaming cursor, top-pull history paging.
class ChatScreen extends ConsumerStatefulWidget {
  /// [embedded] = lives inside HomeShell (wide: docked beside the drawer,
  /// narrow: under the root scaffold with the drawer). Non-embedded keeps
  /// the standalone pushed-page behavior (back button).
  const ChatScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  bool _stickToBottom = true;
  bool _userScrolled = false;
  Timer? _blink;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Only the user's own drag breaks stickiness — content growth (new
      // frames extend maxScrollExtent) must keep pinning to the bottom,
      // otherwise a switched-into history session rests mid-list.
      if (!_userScrolled) return;
      final atBottom = _scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 120;
      if (atBottom != _stickToBottom) setState(() => _stickToBottom = atBottom);
    });
    // Periodic rebuild while streaming: row maps mutate in place, so the
    // ChangeNotifier may not fire per delta.
    _blink = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted &&
          (ref.read(m1Provider.notifier).convState?.rows.isNotEmpty ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _blink?.cancel();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        _userScrolled = true;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
          _userScrolled = false; // dragging back to the bottom re-sticks
        }
      }
      if (n.metrics.pixels < 80 &&
          ref.read(m1Provider.notifier).hasMoreHistory) {
        ref.read(m1Provider.notifier).loadOlder();
      }
    }
    return false;
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(m1Provider.notifier).send(text);
    setState(() => _stickToBottom = true);
    _jumpToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(m1Provider.notifier);
    final s = ref.watch(m1Provider);
    final st = ctrl.convState;
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    if (st == null) {
      // Home welcome state (dsh posture): greeting by hour + device
      // context + the one action that matters right now.
      if (widget.embedded) return _WelcomeScreen(embedded: true);
      return Scaffold(
        appBar: AppBar(title: Text(t.transcript)),
        body: const _WelcomeScreen(embedded: false),
      );
    }
    final turns = groupTurns(st.rows);
    if (_stickToBottom) _jumpToBottom();

    return Scaffold(
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: [
              // ---- message list (scrolls under the floating chrome) ----
              ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 148),
                itemCount: turns.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return st.hasMore == true
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: Text(
                                '↑ 下拉加载更早消息',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  return _TurnWidget(
                    turn: turns[i - 1],
                    isLast: i == turns.length,
                  );
                },
              ),

              // ---- top chrome: back/menu circle + title capsule + stop ----
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                      widget.embedded
                          ? MediaQuery.sizeOf(context).width < 600
                              ? IconButton(
                                  icon: const Icon(Icons.menu, size: 22),
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                )
                              : const SizedBox(width: 8)
                          : IconButton(
                              icon: const Icon(Icons.arrow_back, size: 20),
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                            ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.sessionId != null ? '会话' : t.transcript,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${ctrl.deviceName ?? 'ZCode'} · ${_stateLabel(st, t)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // 停止按钮: turn running → stop icon in the top bar.
                      const SizedBox(width: 10),
                      _GlassCapsule(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.sessionId != null ? '会话' : t.transcript,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: ZColors.greenDot,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${ctrl.deviceName ?? 'ZCode'} · ${_stateLabel(st, t)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isRunning(st) && s.sessionId != null)
                        _GlassCapsule(
                          child: IconButton(
                            tooltip: '停止',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.stop_circle_outlined,
                                size: 20, color: scheme.error),
                            onPressed: () => ctrl.stopSession(s.sessionId!),
                          ),
                        ),
                    ],
                  ),
              ),

              // ---- pending interactions above the input bar ----
              Positioned(
                left: 12,
                right: 12,
                bottom: 96,
                child: _InteractionsPanel(interactions: st.pendingInteractions),
              ),

              // ---- dsh input card: near-solid white, r24, + circle,
              //      teal send circle (visual-spec §9) ----
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A203A50),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Material(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: .7),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {}, // attachments arrive with M-batch
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(Icons.add, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: t.messageHint,
                            border: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ValueListenableBuilder(
                        valueListenable: _input,
                        builder: (_, value, _) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: value.text.trim().isEmpty || s.sending
                                ? scheme.surfaceContainerHighest
                                : scheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: value.text.trim().isEmpty || s.sending
                                  ? null
                                  : _send,
                              child: Padding(
                                padding: const EdgeInsets.all(11),
                                child: Icon(Icons.arrow_upward,
                                    size: 20,
                                    color: value.text.trim().isEmpty ||
                                            s.sending
                                        ? scheme.onSurfaceVariant
                                        : scheme.onPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stateLabel(ConversationState st, AppLocalizations t) {
    final rows = st.rows;
    for (final row in rows.reversed) {
      if (row['kind'] == 'turnHeader') {
        final state = '${row['state'] ?? ''}';
        if (state == 'running' || state == 'prewarming') return t.phase_connecting;
        return t.phase_ready;
      }
    }
    return t.phase_idle;
  }

  static bool _isRunning(ConversationState st) {
    for (final row in st.rows.reversed) {
      if (row['kind'] == 'turnHeader') {
        final state = '${row['state'] ?? ''}';
        return state == 'running' || state == 'prewarming';
      }
    }
    return false;
  }
}


// ------------------------------------------------------------ turn widget

class _TurnWidget extends ConsumerWidget {
  const _TurnWidget({required this.turn, required this.isLast});

  final TurnGroup turn;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (turn.userRow != null) {
      final text = turn.userRow!['text'] as String? ?? '';
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(color: scheme.onPrimaryContainer, height: 1.5),
            ),
          ),
        ),
      ));
    }

    if (turn.header != null || turn.parts.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: _StatusLine(header: turn.header, streaming: turn.streaming),
      ));
    }

    for (final part in turn.parts) {
      if (part.type == PartType.text && part.text != null) {
        children.add(_AssistantText(
          text: part.text!,
          streaming: part.streaming && isLast,
        ));
      } else if (part.row != null) {
        children.add(_ToolTile(row: part.row!));
      }
    }

    if (turn.header?['fileChanges'] is Map) {
      children.add(const SizedBox(height: 6));
      children.add(_FileChangesBar(header: turn.header!));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// 状态行: ✓ 已完成 · N tokens · 时长 / ● 进行中 (breathing).
class _StatusLine extends StatefulWidget {
  const _StatusLine({required this.header, required this.streaming});

  final Map<String, dynamic>? header;
  final bool streaming;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = widget.header;
    final running = widget.streaming ||
        '${h?['state'] ?? ''}' == 'running' ||
        '${h?['state'] ?? ''}' == 'prewarming';
    final tokens = (h?['outputTokens'] as num?)?.toInt();
    final activeMs = (h?['activeMs'] as num?)?.toInt();
    final meta = <String>[
      if (tokens != null && tokens > 0) '$tokens tokens',
      if (activeMs != null && activeMs > 0) _fmtDuration(activeMs),
    ];

    return Row(
      children: [
        if (running)
          FadeTransition(
            opacity: Tween(begin: .35, end: 1.0).animate(_pulse),
            child: Icon(Icons.circle,
                size: 8, color: scheme.primary),
          )
        else
          Icon(Icons.check_circle, size: 14, color: scheme.tertiary),
        const SizedBox(width: 6),
        Text(
          running ? '正在工作' : '已完成',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '· ${meta.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
      ],
    );
  }

  String _fmtDuration(int ms) {
    final s = (ms / 1000).round();
    if (s < 60) return '$s 秒';
    return '${s ~/ 60} 分 ${s % 60} 秒';
  }
}

/// Assistant text rendered as markdown (fenced code, lists, emphasis) with
/// a streaming cursor while the turn is open.
class _AssistantText extends StatelessWidget {
  const _AssistantText({required this.text, required this.streaming});

  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(height: 1.6, fontSize: 14),
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              backgroundColor: scheme.primary.withValues(alpha: .07),
            ),
            codeblockDecoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
            ),
            listBullet: const TextStyle(fontSize: 14),
          ),
        ),
        if (streaming) const _Cursor(),
      ],
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 3,
        height: 16,
        margin: const EdgeInsets.only(top: 4),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Compact tool tile: icon + name + status (expandable in M3).
class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kind = '${row['kind']}';
    final name = '${row['toolName'] ?? row['title'] ?? kind}';
    final status = '${row['status'] ?? ''}';
    final failed = status == 'error' || status == 'failed';
    final display = row['display'];
    final subtitle = display is Map && display['title'] is String
        ? display['title'] as String
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: failed ? .4 : .12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _iconFor(name),
            size: 16,
            color: failed ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (failed)
            Text('失败', style: TextStyle(color: scheme.error, fontSize: 11))
          else if (status == 'running')
            Text('运行中',
                style: TextStyle(color: scheme.primary, fontSize: 11)),
        ],
      ),
    );
  }

  static IconData _iconFor(String tool) {
    final t = tool.toLowerCase();
    if (t.contains('bash') || t.contains('terminal')) return Icons.terminal;
    if (t.contains('edit') || t.contains('write') || t.contains('file')) {
      return Icons.edit_note;
    }
    if (t.contains('read')) return Icons.description_outlined;
    if (t.contains('search') || t.contains('grep')) return Icons.search;
    return Icons.build_circle_outlined;
  }
}

/// 交付卡: 改动了 N 个文件 +N −N + 撤销 (preview → confirm → apply).
class _FileChangesBar extends ConsumerWidget {
  const _FileChangesBar({required this.header});

  final Map<String, dynamic> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final changes = (header['fileChanges'] as Map).cast<String, dynamic>();
    final adds = (changes['additions'] as num?)?.toInt() ?? 0;
    final dels = (changes['deletions'] as num?)?.toInt() ?? 0;
    final files = (changes['files'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          Icon(Icons.difference_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '改动了 $files 个文件',
                style: const TextStyle(fontSize: 12.5),
                children: [
                  if (adds > 0)
                    TextSpan(
                      text: '  +$adds',
                      style: TextStyle(color: scheme.tertiary),
                    ),
                  if (dels > 0)
                    TextSpan(
                      text: '  -$dels',
                      style: TextStyle(color: scheme.error),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _rewindFlow(context, ref),
            child: const Text('撤销', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _rewindFlow(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(m1Provider.notifier);
    final preview = await ctrl.rewindPreview(header);
    if (!context.mounted) return;
    if (preview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回滚预检失败，见协议日志')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('回滚这些文件改动？'),
        content: Text(_previewSummary(preview)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('回滚'),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.applyRewind(header);
  }

  static String _previewSummary(Map<String, dynamic> preview) {
    final files = preview['files'];
    if (files is List) {
      final names = files
          .map((f) => f is Map ? '${f['path'] ?? f['name'] ?? '?'}' : '$f')
          .take(8)
          .join('\n');
      return '将恢复以下 ${files.length} 个文件:\n$names';
    }
    return '桌面端确认后文件将恢复到本条消息之前的状态。';
  }
}

/// 待确认卡 panel above the input bar.
class _InteractionsPanel extends ConsumerWidget {
  const _InteractionsPanel({required this.interactions});

  final List<Map<String, dynamic>> interactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (interactions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final ctrl = ref.read(m1Provider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final it in interactions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(width: 4, color: scheme.primary),
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1E283A54), blurRadius: 14, offset: Offset(0, 2)),
              ],
            ),
            child: _InteractionCard(interaction: it, ctrl: ctrl),
          ),
      ],
    );
  }
}

class _InteractionCard extends StatelessWidget {
  const _InteractionCard({required this.interaction, required this.ctrl});

  final Map<String, dynamic> interaction;
  final M1Controller ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final payload = interaction['payload'];
    final p = payload is Map ? payload : const <String, dynamic>{};
    final id = '${interaction['interactionId'] ?? ''}';
    final title = '${p['title'] ?? p['prompt'] ?? p['message'] ?? '等待确认'}';
    final options = p['options'] is List ? p['options'] as List : const [];

    // Plan approval (parity #10): rides the userInput channel with
    // toolName exitplanmode; render its options like a confirm card.
    final isPlanApproval = p['kind'] == 'userInput' &&
        ('${p['toolName'] ?? ''}'.toLowerCase() == 'exitplanmode' ||
            (p['schema'] is Map &&
                '${(p['schema'] as Map)['interaction'] ?? ''}' ==
                    'plan_approval'));
    if (isPlanApproval) {
      final planOptions = p['options'] is List
          ? p['options'] as List
          : (p['schema'] is Map && (p['schema'] as Map)['options'] is List)
              ? (p['schema'] as Map)['options'] as List
              : const [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.isEmpty ? '计划确认' : title,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                for (final opt in planOptions)
                  if (opt is Map)
                    OutlinedButton(
                      onPressed: () => ctrl.resolveInteraction(
                          id,
                          optionId:
                              '${opt['id'] ?? opt['optionId'] ?? ''}'),
                      child: Text('${opt['label'] ?? opt['name'] ?? '...'}'),
                    ),
                if (planOptions.isEmpty)
                  FilledButton(
                    onPressed: () => ctrl.resolveInteraction(id),
                    child: const Text('同意计划'),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if ('${p['kind']}' == 'workspaceHookReview') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => ctrl.trustHookReview(
                p.cast<String, dynamic>(),
              ),
              child: const Text('信任并继续'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: [
              for (final opt in options)
                if (opt is Map)
                  OutlinedButton(
                    onPressed: () =>
                        ctrl.resolveInteraction(id, optionId: '${opt['id']}'),
                    child: Text('${opt['label'] ?? opt['id'] ?? '...'}'),
                  ),
              if (options.isEmpty)
                FilledButton(
                  onPressed: () => ctrl.resolveInteraction(id),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                  ),
                  child: const Text('确认'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Home greeting (dsh posture): 时段问候 + 一句副题 + 单一主行动。
class _WelcomeScreen extends ConsumerWidget {
  const _WelcomeScreen({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? '夜深了'
        : hour < 11
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 19
                    ? '下午好'
                    : '晚上好';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greeting,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('今天想让 ZCode 做点什么？',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            if (s.phase == 'ready')
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
                onPressed: () => ctrl.newSession(),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t.newSession,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )
            else if (s.phase == 'connecting')
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DevicesPage()),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('连接一台桌面端',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Glass capsule (visual-spec §3): white 90%, pill radius, no border,
/// whisper shadow — the top-chrome shape of the reference app.
class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14203A50),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
