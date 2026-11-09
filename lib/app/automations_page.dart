import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../m1/relay_service.dart';
import '../protocol/automation.dart';

/// 定时任务 page (P2, screens.md #10/#11): list of the connected
/// desktop's automations with enable switches, delete, and a simple
/// create form (title + prompt + every-N-hours or daily cron).
class AutomationsPage extends ConsumerStatefulWidget {
  const AutomationsPage({super.key});

  @override
  ConsumerState<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends ConsumerState<AutomationsPage> {
  List<AutomationItem> _items = [];
  bool _loading = true;
  String? _error;

  AutomationPort? get _port {
    final bridge = ref.read(m1Provider.notifier).bridgeForCommands;
    if (bridge == null) return null;
    return AutomationPort(
      (method, args) => bridge.channels.call('zcode-agent', method, args),
    );
  }

  Future<void> _load() async {
    final port = _port;
    if (port == null) {
      setState(() { _loading = false; _error = '先连接一台桌面端'; });
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await port.list().timeout(const Duration(seconds: 20));
      setState(() { _items = items; _loading = false; _error = null; });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('定时任务')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _port == null ? null : _createSheet,
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyView(
                  icon: Icons.cloud_off,
                  title: '无法加载',
                  message: _error,
                  action: TextButton(onPressed: _load, child: const Text('重试')),
                )
              : _items.isEmpty
                  ? EmptyView(
                      icon: Icons.schedule,
                      title: '还没有定时任务',
                      message: '新建一个，让桌面端在指定时间自动跑',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.screen - 4, vertical: 8),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ZListRow(
                              icon: Icons.schedule,
                              title: it.title.isEmpty ? '未命名任务' : it.title,
                              subtitle: Text(it.prompt.isEmpty
                                  ? _humanCron(it.cronExpr, it.interval,
                                      it.intervalUnit)
                                  : it.prompt),
                              highlighted: it.enabled,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: it.enabled,
                                    onChanged: (v) async {
                                      await _port?.setEnabled(it.id, v);
                                      _load();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 20, color: scheme.error),
                                    onPressed: () async {
                                      await _port?.remove(it.id);
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  static String _humanCron(String cron, int? interval, String? unit) {
    if (cron.isNotEmpty) return cron;
    if (interval != null) return '每 $interval ${unit ?? '小时'}';
    return '一次性任务';
  }

  Future<void> _createSheet() async {
    final title = TextEditingController();
    final prompt = TextEditingController();
    final everyHours = TextEditingController(text: '24');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, bottom: 20,
          top: 8 + MediaQuery.of(ctx).viewInsets.bottom * 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '任务名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prompt,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '提示词（要做什么）'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: everyHours,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '间隔（小时，24=每天）',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final hours = int.tryParse(everyHours.text) ?? 24;
    try {
      await _port?.create(AutomationInput(
        title: title.text.trim(),
        prompt: prompt.text.trim(),
        trigger: AutomationInput.triggerInterval,
        interval: hours,
        intervalUnit: 'h',
      )).timeout(const Duration(seconds: 20));
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('创建失败，见协议日志')));
      }
    }
  }
}
