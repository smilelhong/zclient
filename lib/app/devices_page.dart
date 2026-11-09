import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: Text(
          'ZClient',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -.5),
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
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_other,
                            size: 56, color: scheme.primary.withValues(alpha: .3)),
                        const SizedBox(height: 12),
                        Text(t.noDevices,
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          t.noDevicesHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: devices.length,
                    itemBuilder: (_, i) {
                      final d = devices[i];
                      final isActive = d.sid == activeSid;
                      final connecting =
                          isActive && s.phase == 'connecting';
                      return _DeviceCard(
                        device: d,
                        active: isActive && s.phase == 'ready',
                        connecting: connecting,
                        error: isActive && s.phase == 'error',
                        onTap: () => ctrl.connectDevice(d),
                        onRemove: () => _confirmRemove(context, ctrl, d),
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.active,
    required this.connecting,
    required this.error,
    required this.onTap,
    required this.onRemove,
  });

  final PairedDevice device;
  final bool active;
  final bool connecting;
  final bool error;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final status = error
        ? t.phase_error
        : connecting
            ? t.phase_connecting
            : active
                ? t.phase_ready
                : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: active
              ? scheme.primary.withValues(alpha: .5)
              : scheme.outline.withValues(alpha: .4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onRemove,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.monitor,
                  color: active ? scheme.onPrimaryContainer : scheme.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? device.sid,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status ?? t.deviceIdle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: active ? scheme.tertiary : null,
                          ),
                    ),
                  ],
                ),
              ),
              if (status != null && !error)
                Icon(
                  active ? Icons.check_circle : Icons.sync,
                  size: 18,
                  color: active ? scheme.tertiary : scheme.primary,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
