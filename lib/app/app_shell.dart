import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import 'devices_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';

/// Shell per dsh-visual-spec §1: landscape = floating left drawer panel
/// (near-white, r36, margins) over the diagonal blue gradient; phones keep
/// the bottom nav.
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
        // Floating drawer panel (spec §1): margin 12, r36, #F7F9FA,
        // soft shadow; brand row + nav items inside.
        final scheme = Theme.of(context).colorScheme;
        final dark = scheme.brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 264,
                decoration: BoxDecoration(
                  color: dark ? ZColors.darkSurface : const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: dark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x1A203A50),
                            blurRadius: 24,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Z',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ZClient',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _DrawerNav(
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                          items: [
                            (Icons.devices_outlined, Icons.devices, t.tabDevices),
                            (Icons.forum_outlined, Icons.forum, t.tabSessions),
                            (Icons.settings_outlined, Icons.settings,
                                t.tabSettings),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: pages[_tab],
              ),
            ],
          ),
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

/// Drawer nav items: full-width pills, selected = soft tinted surface
/// (quiet, per spec §3 glass language — not a loud indicator).
class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.index,
    required this.onChanged,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Material(
              color: i == index
                  ? scheme.primaryContainer.withValues(alpha: .6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => onChanged(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        i == index ? item.$2 : item.$1,
                        size: 22,
                        color: i == index
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight:
                              i == index ? FontWeight.w600 : FontWeight.w500,
                          color: i == index
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
