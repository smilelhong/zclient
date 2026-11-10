import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/relay_service.dart';
import '../m1/console_page.dart';
import 'app_settings.dart';
import 'automations_page.dart';
import 'update_service.dart';

/// M3 settings hub (A-枢纽页骨架): 外观(主题/语言) · 连接(诊断/断开) · 帮助与关于.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final settingsCtrl = ref.read(appSettingsProvider.notifier);
    final themeLabel = switch (settings.theme) {
      ThemeMode.light => t.themeLight,
      ThemeMode.dark => t.themeDark,
      _ => t.themeSystem,
    };
    final localeLabel = switch (settings.locale?.languageCode) {
      'zh' => '中文',
      'en' => 'English',
      _ => t.langSystem,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tabSettings,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.5),
            ),
            Text('登录、外观与关于',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ZColors.bgGradTop, ZColors.bgGradBottom],
          ),
        ),
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ---- 概览卡 (A-枢纽页骨架, screens.md #14) ----
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      s.jwtHost != null ? Icons.person : Icons.person_outline,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.jwtHost != null ? '已登录' : '未登录',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w500),
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
                              '${s.devices.length} 台设备 · '
                              '${s.phase == 'ready' ? '1 台在线' : '0 台在线'}',
                              style: Theme.of(context).textTheme.bodySmall,
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
          const SizedBox(height: 12),

          // ---- 连接 ----
          _Section(label: t.sectionConnection),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(t.login),
                  subtitle: Text(s.jwtHost ?? t.loggedInPlaceholder),
                  trailing: s.jwtHost != null
                      ? Icon(Icons.check_circle, color: scheme.tertiary)
                      : null,
                ),
                if (s.phase == 'ready')
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: Text(t.disconnect),
                    onTap: () => ctrl.disconnect(),
                  ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('定时任务'),
                  subtitle: Text(s.phase == 'ready' ? '桌面端的自动化' : '连接后可用'),
                  enabled: s.phase == 'ready',
                  onTap: s.phase == 'ready'
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AutomationsPage()),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 外观 ----
          _Section(label: t.sectionAppearance),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(t.themeMode),
                  trailing: Text(themeLabel),
                  onTap: () => _pickTheme(context, settingsCtrl),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(t.language),
                  trailing: Text(localeLabel),
                  onTap: () => _pickLocale(context, settingsCtrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 帮助与关于 ----
          _Section(label: t.sectionAbout),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.terminal),
                  title: const Text('协议控制台'),
                  subtitle: const Text('M1 调试工具：日志与收发'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const M1ConsolePage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.system_update),
                  title: const Text('检查更新'),
                  subtitle: const Text('GitHub Releases'),
                  onTap: () => _checkUpdate(context),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('ZClient'),
                  subtitle: Text('0.1.0 · 非官方 ZCode 远控客户端\n与智谱 AI / Z.ai 无关'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '会话凭证仅存本机 · 无遥测无广告',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在检查更新…')),
    );
    try {
      final check = await UpdateCheck.run();
      if (!context.mounted) return;
      if (!check.hasUpdate) {
        messenger.showSnackBar(
          SnackBar(content: Text('已是最新版（${check.currentVersion}）')),
        );
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 ${check.latestVersion}'),
          content: const Text('前往 GitHub Releases 下载（浏览器打开）？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('稍后')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('打开')),
          ],
        ),
      );
      if (go == true) {
        await launchUrl(
          Uri.parse('https://github.com/${UpdateCheck.repo}/releases/latest'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('检查更新失败（网络）')));
    }
    // keep navigator referenced for future in-page routing
    navigator.canPop();
  }

  Future<void> _pickTheme(
      BuildContext context, AppSettings ctrl) async {
    final t = AppLocalizations.of(context);
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, label) in [
              (ThemeMode.system, t.themeSystem),
              (ThemeMode.light, t.themeLight),
              (ThemeMode.dark, t.themeDark),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(ctx, mode),
              ),
          ],
        ),
      ),
    );
    if (mode != null) await ctrl.setTheme(mode);
  }

  Future<void> _pickLocale(BuildContext context, AppSettings ctrl) async {
    final t = AppLocalizations.of(context);
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in [
              (null as String?, t.langSystem),
              ('zh', '中文'),
              ('en', 'English'),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    await ctrl.setLocale(
      code == null ? null : Locale(code),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
