import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _topAlignAnimation;
  late final Animation<Alignment> _bottomAlignAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // 10秒一个周期，呼吸感更强
    )..repeat(reverse: true);

    _topAlignAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.centerRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.centerRight, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_controller);

    _bottomAlignAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.centerLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.centerLeft, end: Alignment.bottomRight),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF1F5F9),
                  Color(0xFFE2E8F0),
                ],
              ),
            ),
          ),
          widget.child,
        ],
      );
    }

    // 暗色模式：曜石玻璃 + 极光氛围
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF020205)), // 极深底色

        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  // 极光 A：深靛
                  Positioned(
                    top: -150 + (250 * _topAlignAnimation.value.y),
                    left: -100 + (200 * _topAlignAnimation.value.x),
                    child: _buildBlob(
                      600,
                      const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                    ),
                  ),
                  // 极光 B：幽冥紫
                  Positioned(
                    bottom: -100 + (300 * _bottomAlignAnimation.value.y),
                    right: -100 + (250 * _bottomAlignAnimation.value.x),
                    child: _buildBlob(
                      550,
                      const Color(0xFF312E81).withValues(alpha: 0.5),
                    ),
                  ),
                  // 极光 C：品牌紫 (核心提亮)
                  Positioned(
                    top: 200 * _topAlignAnimation.value.x,
                    right: 150 * _bottomAlignAnimation.value.y,
                    child: _buildBlob(
                      450,
                      const Color(0xFF7000FF).withValues(alpha: 0.15),
                    ),
                  ),
                  // 极光 D：翡翠青 (动态修正)
                  Positioned(
                    bottom: 200 * _bottomAlignAnimation.value.x,
                    left: 100 * _topAlignAnimation.value.y,
                    child: _buildBlob(
                      500,
                      const Color(0xFF00F2FF).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // 增加一层全局微弱蒙版提升通透度
        Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2)),
        ),

        widget.child,
      ],
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}
