import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 让 WLED 当前颜色成为控制页的环境光，而不是额外的装饰层。
class DeviceAmbientBackground extends StatefulWidget {
  final Color color;
  final bool isActive;
  final Widget child;

  const DeviceAmbientBackground({
    super.key,
    required this.color,
    required this.isActive,
    required this.child,
  });

  @override
  State<DeviceAmbientBackground> createState() =>
      _DeviceAmbientBackgroundState();
}

class _DeviceAmbientBackgroundState extends State<DeviceAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColors = isDark
        ? const [Color(0xFF030308), Color(0xFF0C0C16)]
        : const [Color(0xFFF8FAFC), Color(0xFFEDF1F7)];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: baseColors,
            ),
          ),
        ),
        if (widget.isActive)
          RepaintBoundary(
            key: const ValueKey('device-ambient-glow'),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final drift = math.sin(_controller.value * math.pi * 2);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: -190 + drift * 30,
                      left: -170 + drift * 24,
                      child: _GlowOrb(
                        size: 560,
                        color: widget.color.withValues(
                          alpha: isDark ? 0.42 : 0.20,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -210 - drift * 20,
                      bottom: -230 + drift * 36,
                      child: _GlowOrb(
                        size: 520,
                        color: HSLColor.fromColor(widget.color)
                            .withHue(
                              (HSLColor.fromColor(widget.color).hue + 42) % 360,
                            )
                            .toColor()
                            .withValues(alpha: isDark ? 0.22 : 0.12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(alpha: widget.isActive ? 0.12 : 0.22)
              : Colors.white.withValues(alpha: 0.08),
        ),
        widget.child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
