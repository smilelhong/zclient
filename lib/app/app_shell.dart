import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'devices_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';

/// M3 shell: phone bottom nav (设备/会话/设置) per design-system §4.1;
/// tablet ≥600dp renders a left navigation rail instead (§4.2).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DevicesPage(),
      const SessionsPage(),
      const SettingsPage(),
    ];
    final t = AppLocalizations.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      if (wide) {
        return Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.devices_outlined),
                  selectedIcon: const Icon(Icons.devices),
                  label: Text(t.tabDevices),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.forum_outlined),
                  selectedIcon: const Icon(Icons.forum),
                  label: Text(t.tabSessions),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(t.tabSettings),
                ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: .4),
            ),
            Expanded(child: pages[_tab]),
          ],
        );
      }
      return Scaffold(
        body: pages[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.devices_outlined),
              selectedIcon: const Icon(Icons.devices),
              label: t.tabDevices,
            ),
            NavigationDestination(
              icon: const Icon(Icons.forum_outlined),
              selectedIcon: const Icon(Icons.forum),
              label: t.tabSessions,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: t.tabSettings,
            ),
          ],
        ),
      );
    });
  }
}
