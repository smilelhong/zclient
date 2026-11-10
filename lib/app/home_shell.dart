import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../m2/chat_screen.dart';
import 'z_drawer.dart';

/// dsh-Go posture shell: the chat IS the home; the drawer carries the
/// conversation list, the device identity bar (switcher + settings), and
/// the 新会话 primary action. Landscape keeps the drawer docked as a
/// floating panel; portrait opens it as a slightly narrow side sheet.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawer = const ZDrawer();
    final wide = MediaQuery.sizeOf(context).width >= 600;

    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      final dark = scheme.brightness == Brightness.dark;
      // dsh live: drawer flush-left full-height, 31% width (min 280/max 420)
      final drawerW = (MediaQuery.sizeOf(context).width * 0.31)
          .clamp(280.0, 420.0);
      return Row(
        children: [
          Container(
            width: drawerW,
            color: dark ? ZColors.darkSurface : ZColors.drawerBg,
            child: drawer,
          ),
          Expanded(
            child: Container(
              // vertical gradient per live-spec
              decoration: dark
                  ? null
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD6E8F2), Color(0xFFF7F9FA)],
                      ),
                    ),
              child: const ChatScreen(embedded: true),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      drawerEdgeDragWidth: 60,
      drawer: SizedBox(width: 320, child: drawer),
      body: const ChatScreen(embedded: false),
    );
  }
}
