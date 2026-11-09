import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../m1/relay_service.dart';

/// Shared connection status banner for the top of list pages.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(m1Provider);
    if (s.phase == 'ready' || s.phase == 'idle') return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isError = s.phase == 'error';
    return Container(
      width: double.infinity,
      color: isError
          ? scheme.errorContainer
          : scheme.primaryContainer.withValues(alpha: .5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        isError
            ? (s.error ?? '连接出错')
            : '正在连接 ${s.params?.deviceName ?? ''}…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isError ? scheme.onErrorContainer : scheme.onSurface,
            ),
      ),
    );
  }
}
