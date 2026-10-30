import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 控制页的微弱环境光：限制在安全区内部，主色光交给设备卡片本身。
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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(DeviceAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || !widget.isActive) {
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
                final breath =
                    0.94 + 0.06 * math.sin(_controller.value * math.pi * 2);
                final safe = MediaQuery.paddingOf(context);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    safe.left + 24,
                    safe.top + 24,
                    safe.right + 24,
                    safe.bottom + 24,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.min(constraints.maxWidth, 560.0);
                        final height = math.min(
                          constraints.maxHeight,
                          math.min(width * 0.85, 320.0),
                        );
                        return SizedBox(
                          width: width,
                          height: height,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  widget.color.withValues(
                                    alpha: (isDark ? 0.07 : 0.035) * breath,
                                  ),
                                  widget.color.withValues(
                                    alpha: (isDark ? 0.015 : 0.008) * breath,
                                  ),
                                  widget.color.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.55, 1],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
