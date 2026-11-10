import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

import 'tokens.dart';

/// dsh-Go pressable.dart source-exact rewrite:
/// - scale 0.97 on tap-down (AnimationController.unbounded so fluid
///   release can slightly overshoot back to 1)
/// - in scrollable content, delay showing the press by AppMotion.press
///   so scroll-past doesn't flash (and once shown, hold equally long)
/// - displacement beyond touchSlop cancels the press
/// - release: spring (not linear curve) — SpringSimulation with tight
///   tolerance
/// - reduced motion: scale stays 1
/// - haptic on own-tap mode
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = false,
    this.enabled = true,
    this.pressScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;
  final bool enabled;
  final double pressScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    duration: AppMotion.press,
    value: 1.0,
  );

  bool _pointerDown = false;
  bool _showing = false;
  Offset _startPosition = Offset.zero;
  double? _touchSlop;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  double get _slop =>
      _touchSlop ??
      MediaQuery.maybeOf(context)?.gestureSettings.touchSlop ??
      kTouchSlop;

  bool get _inScrollable => Scrollable.maybeOf(context) != null;

  void _onDown(TapDownDetails d) {
    if (!widget.enabled) return;
    _pointerDown = true;
    _startPosition = d.globalPosition;
    _showing = !_inScrollable;
    if (_showing) {
      _scale.animateTo(widget.pressScale,
          duration: AppMotion.press, curve: Curves.easeOut);
    } else {
      // dsh: delay showing while in a scrollable; once the delay elapses
      // (finger still down), start showing. Hold for the same duration
      // so even fast taps are visible.
      Future.delayed(AppMotion.press, () {
        if (_pointerDown && mounted) {
          _showing = true;
          _scale.animateTo(widget.pressScale,
              duration: AppMotion.press, curve: Curves.easeOut);
        }
      });
    }
  }

  void _onUp(TapUpDetails d) {
    _release();
  }

  void _cancel() {
    _pointerDown = false;
    _showing = false;
    _springBack();
  }

  void _release() {
    _pointerDown = false;
    _showing = false;
    _springBack();
  }

  void _springBack() {
    if (mounted) {
      _scale.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 400, damping: 28),
        _scale.value,
        1.0,
        _scale.velocity,
        tolerance: const Tolerance(distance: 0.002, velocity: 0.02),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _cancel,
      onTap: widget.onTap == null || !widget.enabled
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      onPanUpdate: (d) {
        if (_pointerDown &&
            (d.globalPosition - _startPosition).distance > _slop) {
          _cancel();
        }
      },
      child: reduced
          ? widget.child
          : AnimatedBuilder(
              animation: _scale,
              builder: (_, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: widget.child,
            ),
    );
  }
}
