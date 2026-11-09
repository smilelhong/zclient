import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/status.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/login_page.dart';
import '../m1/relay_service.dart';
import '../m1/scan_page.dart';
import '../state/device_store.dart';
import 'connection_banner.dart';

/// M3 devices tab: paired desktops (四段式行 per design §7.1), scan FAB,
/// login entry. Tapping a device connects (or reconnects) to it.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    final ctrl = ref.read(m1Provider.notifier);
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final devices = s.devices;
    final activeSid = s.phase == 'ready' || s.phase == 'connecting'
        ? s.params?.deviceSid
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.5),
            ),
            Text(
              '在手机上接着用电脑里的 ZCode',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t.login,
            onPressed: () => _login(context, ctrl),
            icon: Icon(
              s.jwtHost != null ? Icons.check_circle : Icons.account_circle,
              color: s.jwtHost != null ? scheme.tertiary : null,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scan(context, ctrl),
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(t.scanPair),
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          if (s.jwtHost == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: scheme.primaryContainer.withValues(alpha: .4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.loginHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _login(context, ctrl),
                        child: Text(t.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 16, 0),
            child: GroupLabel('我的设备'),
          ),
          Expanded(
            child: devices.isEmpty
                ? EmptyView(
                    icon: Icons.devices_other,
                    title: t.noDevices,
                    message: t.noDevicesHint,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.screen - 4, vertical: 8),
                    itemCount: devices.length,
                    itemBuilder: (_, i) {
                      final d = devices[i];
                      final isActive = d.sid == activeSid;
                      final connecting =
                          isActive && s.phase == 'connecting';
                      final error = isActive && s.phase == 'error';
                      return StaggerIn(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ZListRow(
                            icon: Icons.monitor,
                            title: d.name ?? d.sid,
                            highlighted: isActive && s.phase == 'ready',
                            subtitle: error
                                ? Text(s.error ?? t.phase_error)
                                : connecting
                                    ? StatusLineText.running(
                                        label: t.phase_connecting)
                                    : isActive && s.phase == 'ready'
                                        ? StatusLineText.idle(
                                            label: t.phase_ready)
                                        : Text(t.deviceIdle),
                            trailing: error
                                ? Icon(Icons.error_outline,
                                    color: scheme.error, size: 20)
                                : isActive && s.phase == 'ready'
                                    ? Icon(Icons.check_circle,
                                        color: ZColors.okDot(
                                            scheme.brightness),
                                        size: 20)
                                    : const Icon(Icons.chevron_right),
                            onTap: () => ctrl.connectDevice(d),
                            onLongPress: () =>
                                _confirmRemove(context, ctrl, d),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
    if (raw != null) await ctrl.addDeviceFromLink(raw);
  }

  Future<void> _confirmRemove(
      BuildContext context, M1Controller ctrl, PairedDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).removeDeviceTitle),
        content: Text(
            '${AppLocalizations.of(context).removeDeviceBody} ${d.name ?? d.sid}？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.removeDevice(d.sid);
  }
}
