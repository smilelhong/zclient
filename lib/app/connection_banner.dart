import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../m1/login_page.dart';
import '../m1/relay_service.dart';

/// Connection notice as a soft rounded card (dsh-Go posture): a quiet
/// warning surface with a text action — never a full-bleed red slab.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    if (s.phase == 'ready' || s.phase == 'idle') return const SizedBox.shrink();
    final isError = s.phase == 'error';
    final needsRelogin = (s.error ?? '').contains('登录');
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? ZColors.warnSurface : scheme.primaryContainer.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.cloud_off_outlined : Icons.sync,
              size: 18,
              color: isError ? ZColors.warnText : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isError
                    ? (s.error ?? AppLocalizations.of(context).phase_error)
                    : '正在连接 ${s.params?.deviceName ?? ''}…',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isError ? ZColors.warnText : scheme.onSurface,
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
