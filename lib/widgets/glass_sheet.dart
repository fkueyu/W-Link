import 'dart:ui';

import 'package:flutter/material.dart';

/// 底部弹层的玻璃外壳（模糊 + 顶圆角 + 半透明填充）。
///
/// 为什么必须是「模糊 + 半透明」，不能只有半透明：玻璃填充本身是透的
/// （浅色 0.65 / 深色 0.82），**只铺一层半透明色块时，底下页面的文字会原样
/// 透上来和弹层文字叠在一起**——真机上「快捷色」和背后的「颜色」两行字就是
/// 重叠的。设备设置弹层一直是「ClipRRect + BackdropFilter(blur 30) + 0.85
/// 填充」，色盘弹层漏了模糊，所以只有它看起来像一张白纸。
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    this.radius = 24,
    this.opacity = 0.85,
    this.blurSigma = 30,
    required this.child,
  });

  /// 顶部圆角半径，只作用于上两角。
  final double radius;

  /// 填充不透明度。0.85 与设备设置弹层一致。
  final double opacity;

  final double blurSigma;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = (isDark ? const Color(0xFF1C1C1E) : Colors.white).withValues(
      alpha: opacity,
    );

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(color: fill, child: child),
      ),
    );
  }
}
