import 'package:flutter/material.dart';

import 'tokens.dart';

/// 四段式 list row (design §7.1): icon tile (44dp r14 tonal) + two-line
/// text + right meta/chevron. Row height snaps to 52/64.
class ZListRow extends StatelessWidget {
  const ZListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final twoLines = subtitle != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: highlighted
            ? ZColors.pc(scheme.brightness)
            : ZColors.surface(scheme.brightness),
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: twoLines ? AppSpace.rowDouble + 20 : AppSpace.rowSingle + 12,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? ZColors.pc(scheme.brightness)
                          : scheme.brightness == Brightness.dark
                              ? ZColors.darkSurface
                              : const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon,
                        size: 22,
                        color: highlighted
                            ? ZColors.onPc(scheme.brightness)
                            : scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w500)),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: DefaultTextStyle(
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                      color: scheme.onSurfaceVariant),
                              child: subtitle!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified empty state (design §7.16): big quiet glyph + title + one
/// line + at most one action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56, color: scheme.primary.withValues(alpha: .3)),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// First-appear list entrance (design §8): fade + rise 8px, staggered
/// ≤30ms, capped at the first 8 items.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.entrance);

  @override
  void initState() {
    super.initState();
    if (widget.index < 8) {
      Future.delayed(Duration(milliseconds: 30 * widget.index), _c.forward);
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: _c.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - _c.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Quiet group label (design §6): small, relaxed, muted.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 12, bottom: AppSpace.groupToCard),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
