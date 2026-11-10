import 'package:flutter/material.dart';

import '../m2/chat_screen.dart';
import 'z_drawer.dart';

/// ValueNotifier shared app-wide: true = landscape drawer collapsed.
final drawerHiddenNotifier = ValueNotifier<bool>(false);

/// dsh-Go posture shell: chat IS the home. Both orientations share ONE
/// drawer implementation so they behave identically:
/// - landscape (>=600): drawer docked open by default, toggle collapses
///   it with an animated width (content reflows, no overlay)
/// - portrait (<600): drawer slides over the chat with a scrim,
///   edge-swipe and hamburger both open it
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final drawer = const ZDrawer();
    final wide = MediaQuery.sizeOf(context).width >= 600;

    if (wide) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: SizedBox(width: 300, child: drawer),
        drawerEdgeDragWidth: 60,
        body: Row(
          children: [
            // Docked drawer column: collapses via the chat toggle.
            // OverflowBox keeps ZDrawer at full 300 width while the outer
            // container clips — content slides left instead of reflowing.
            ValueListenableBuilder<bool>(
              valueListenable: drawerHiddenNotifier,
              builder: (_, hidden, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: hidden ? 0 : 300,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: 300,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 300, child: drawer),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: drawerHiddenNotifier,
                builder: (_, hidden, _) => ChatScreen(
                  embedded: true,
                  onToggleDrawer: _toggle,
                  onOpenDrawer: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                  // when collapsed the leading button should reopen
                  leadingAsMenu: hidden,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawerEdgeDragWidth: 60,
      drawer: SizedBox(width: 300, child: drawer),
      body: ChatScreen(
        embedded: false,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }

  void _toggle() {
    drawerHiddenNotifier.value = !drawerHiddenNotifier.value;
  }
}
