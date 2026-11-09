import 'package:flutter/material.dart';

import 'pressable.dart';
import 'tokens.dart';

/// Status as a colored dot + quiet text (design §6): running breathes,
/// done/online stays solid. Never a colored shouting pill.
class StatusDot extends StatefulWidget {
  const StatusDot.running({super.key})
      : color = null,
        breathing = true;
  const StatusDot.solid(this.color, {super.key}) : breathing = false;

  final Color? color;
  final bool breathing;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.breathe)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.color ?? Theme.of(context).colorScheme.primary;
    final child = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    );
    if (!widget.breathing) return child;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: child,
    );
  }
}

/// A one-line running / done / offline descriptor with its dot.
class StatusLineText extends StatelessWidget {
  const StatusLineText.running({super.key, required this.label})
      : running = true;
  const StatusLineText.idle({super.key, required this.label})
      : running = false;

  final String label;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        running
            ? const StatusDot.running()
            : StatusDot.solid(ZColors.okDot(scheme.brightness)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: running ? scheme.primary : ZColors.okDot(scheme.brightness),
          ),
        ),
      ],
    );
  }
}

/// Filter chip row with the dark-ink selected state (design §7.3):
/// selected = #26282E solid + white, unselected = quiet outline.
class ZFilterChips<T> extends StatelessWidget {
  const ZFilterChips({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.options,
  });

  final T selected;
  final ValueChanged<T> onSelect;
  final List<(T value, String label)> options;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Row(
      children: [
        for (final (i, opt) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          _Chip(
            label: opt.$2,
            selected: opt.$1 == selected,
            darkInk: !dark,
            onTap: () => onSelect(opt.$1),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.selected,
      required this.darkInk,
      required this.onTap});

  final String label;
  final bool selected;
  final bool darkInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = darkInk ? ZColors.ink : scheme.surface;
    final fg = darkInk ? Colors.white : scheme.onSurface;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? fill : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? fill : ZColors.outline(scheme.brightness),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? fg : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
