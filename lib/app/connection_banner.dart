import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../m1/login_page.dart';
import '../m1/relay_service.dart';

/// Connection banner with an action per failure class (parity #5):
/// credential dead → 重新登录; anything else retryable → 重试.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    if (s.phase == 'ready' || s.phase == 'idle') return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isError = s.phase == 'error';
    final needsRelogin = (s.error ?? '').contains('登录');
    return Container(
      width: double.infinity,
      color: isError
          ? scheme.errorContainer
          : scheme.primaryContainer.withValues(alpha: .5),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isError
                  ? (s.error ?? AppLocalizations.of(context).phase_error)
                  : '正在连接 ${s.params?.deviceName ?? ''}…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isError ? scheme.onErrorContainer : scheme.onSurface,
                  ),
            ),
          ),
          if (isError && needsRelogin)
            TextButton(
              onPressed: () => _relogin(context, ref),
              child: const Text('重新登录'),
            )
          else if (isError)
            TextButton(
              onPressed: () => ref.read(m1Provider.notifier).connect(),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  Future<void> _relogin(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(m1Provider.notifier);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => M1LoginPage(
          host: M1Controller.loginHost,
          onHarvested: ctrl.onLoginHarvested,
        ),
      ),
    );
  }
}
