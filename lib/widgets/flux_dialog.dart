import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 统一弹窗卡片外壳：居中卡片 + 高度上限 + 内容滚动，三件事收在一处。
///
/// 为什么要有它（折叠屏 / 小窗 / 键盘 / 横屏）：
/// - 卡片高度上限由**当前布局约束**推导，不写死像素、也不读整个窗口的
///   `MediaQuery.size.height`；折叠、分屏、键盘弹出都会改变可用高度，
///   写死高度的卡片会直接 `RenderFlex overflow`。
/// - 内容高于可用高度时**滚动**而不是溢出，标题与按钮永远可达。
/// - 键盘（`viewInsets`）弹出时整张卡片上移，输入框不会被遮住。
///
/// ⚠️ 子部件若需要**确定边长**（`StackFit.expand`、`AspectRatio`、
/// `CustomPaint` 等，例如色轮），不能直接放进本外壳：滚动方向上的高度约束是
/// 无界的。这类子部件请先用 [fluxDialogContentSize] 算出确定尺寸再包一层
/// `SizedBox`。
class FluxDialogCard extends StatelessWidget {
  const FluxDialogCard({
    super.key,
    required this.child,
    required this.isDark,
    this.radius = 24,
    this.margin = const EdgeInsets.all(32),
    this.padding = const EdgeInsets.all(24),
    this.backgroundColor,
    this.boxShadow,
  });

  final Widget child;
  final bool isDark;
  final double radius;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  /// 默认：暗色 `#1C1C1E`，亮色纯白（与改造前的 9 处弹窗一致）。
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          // 键盘弹出时把卡片抬起，避免输入框被遮住
          padding: EdgeInsets.only(bottom: keyboard),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Center 给的是松约束：maxHeight 就是这张卡片的可用高度。
              final available = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : math.max(
                      0.0,
                      media.size.height -
                          media.viewInsets.vertical -
                          media.padding.vertical,
                    );
              final maxCardHeight = math.max(0.0, available - margin.vertical);

              return Container(
                key: const ValueKey('flux-dialog-surface'),
                margin: margin,
                decoration: BoxDecoration(
                  color:
                      backgroundColor ??
                      (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: boxShadow,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxCardHeight),
                  child: SingleChildScrollView(padding: padding, child: child),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 弹窗内**内容区**的确定尺寸（已扣掉外边距与内边距）。
///
/// 给需要确定边长的子部件使用，例如 `ColorPicker` 的色轮。返回值不会是负数，
/// 但极小窗口下可能小于子部件的最小可用尺寸，调用方应自行 `clamp`。
Size fluxDialogContentSize(
  BuildContext context, {
  EdgeInsets margin = const EdgeInsets.all(32),
  EdgeInsets padding = const EdgeInsets.all(24),
}) {
  final media = MediaQuery.of(context);
  final width = media.size.width - margin.horizontal - padding.horizontal;
  final height =
      media.size.height -
      media.viewInsets.vertical -
      media.padding.vertical -
      margin.vertical -
      padding.vertical;
  return Size(math.max(0, width), math.max(0, height));
}
