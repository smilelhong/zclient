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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color:
                      dark ? ZColors.darkSurface : const Color(0xFFF7F9FA),
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
                child: drawer,
              ),
              const SizedBox(width: 12),
              const Expanded(child: ChatScreen(embedded: true)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawerEdgeDragWidth: 60,
      drawer: SizedBox(width: 320, child: drawer),
      body: const ChatScreen(embedded: false),
    );
  }
}
