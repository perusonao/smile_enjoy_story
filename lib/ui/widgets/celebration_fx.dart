import 'dart:math';

import 'package:flutter/material.dart';

/// Lightweight, dependency-free success micro-animations (Playable 0.4C.4
/// §19) — no external confetti package: everything here is a handful of
/// [TweenAnimationBuilder]s, so it stays a few KB of pure Dart instead of a
/// new pub dependency, and never needs network access to build.
///
/// Two intensities only, matched to event importance (§19, §21):
/// [SuccessEntrance] (fade + slight scale-up) for routine successes — offer
/// received, offer accepted, contract signed — and [ConfettiBurst] added on
/// top only for the handful of truly major, once-per-playthrough beats
/// (first assignment, founding complete). Stacking every success with
/// confetti would cheapen it (§21), so confetti is opt-in per call site,
/// never automatic from a generic "success" flag.

/// Fade + scale-up entrance for a success card. Plays once per mount —
/// intentionally not looping or repeating, so it reads as "this just
/// happened" rather than a decorative idle animation.
class SuccessEntrance extends StatelessWidget {
  const SuccessEntrance({super.key, required this.child, this.duration = const Duration(milliseconds: 380)});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        // `Opacity` drops its child from the semantics tree entirely at
        // opacity == 0.0 unless told not to — this widget starts at exactly
        // that value on its very first frame. Without this, a screen reader
        // (or an E2E driver reading the accessibility tree, same as one)
        // that happens to sample mid-entrance sees an empty subtree: no
        // headline, no CTA, nothing to act on — for content that's
        // otherwise fully interactive underneath the fade.
        alwaysIncludeSemantics: true,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: child,
    );
  }
}

/// A brief, self-contained confetti burst — reserved for the small set of
/// genuinely major, once-per-playthrough events (§20-21): first assignment,
/// founding complete. Renders ~18 small colored rects falling and fading
/// over ~1.1s, then leaves no trace (no repeat, no persistent overlay).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particleCount = 18});
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _colors = [
    Color(0xFF1565C0),
    Color(0xFF00BCD4),
    Color(0xFFFFB300),
    Color(0xFF2E7D32),
    Color(0xFFE53935),
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _particles = List.generate(widget.particleCount, (i) {
      return _Particle(
        startX: rng.nextDouble(),
        fallDistance: 0.55 + rng.nextDouble() * 0.35,
        drift: (rng.nextDouble() - 0.5) * 0.3,
        color: _colors[i % _colors.length],
        size: 5 + rng.nextDouble() * 4,
        delay: rng.nextDouble() * 0.15,
        spin: rng.nextDouble() * pi * 2,
      );
    });
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              for (final p in _particles) p.build(constraints, _controller.value),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.startX,
    required this.fallDistance,
    required this.drift,
    required this.color,
    required this.size,
    required this.delay,
    required this.spin,
  });

  final double startX;
  final double fallDistance;
  final double drift;
  final Color color;
  final double size;
  final double delay;
  final double spin;

  Widget build(BoxConstraints constraints, double t) {
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final eased = Curves.easeIn.transform(local);
    final top = constraints.maxHeight * fallDistance * eased;
    final left = (startX + drift * eased) * constraints.maxWidth;
    final opacity = local < 0.75 ? 1.0 : (1 - (local - 0.75) / 0.25).clamp(0.0, 1.0);
    return Positioned(
      left: left.clamp(0, max(0, constraints.maxWidth - size)),
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: spin * eased,
          child: Container(width: size, height: size * 0.6, color: color),
        ),
      ),
    );
  }
}
