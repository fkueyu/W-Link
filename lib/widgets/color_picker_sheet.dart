import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import 'app_toast.dart';

/// 颜色选择底部弹窗 (Custom HS Disc Version)
class ColorPickerSheet extends ConsumerStatefulWidget {
  final Color initialColor;
  final Future<void> Function(Color) onColorChanged;

  const ColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  ConsumerState<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<ColorPickerSheet> {
  late Color _currentColor;
  late final LatestValueDispatcher<Color> _dispatcher;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _dispatcher = LatestValueDispatcher<Color>(widget.onColorChanged);
  }

  void _selectColor(Color color) {
    setState(() => _currentColor = color);
    _dispatcher.submit(color);
  }

  @override
  void dispose() {
    _dispatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presetColors = ref.watch(quickColorPaletteProvider);
    final l10n = ref.watch(l10nProvider);

    return Container(
      decoration:
          FluxTheme.glassDecoration(
            context,
            radius: 24,
            color: Theme.of(context).cardTheme.color,
          ).copyWith(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 色盘之外固定占用的高度（手柄 40 + 间距 32 + 标题行 22 + 间距 12
          // + 快捷色条 70 + 底部 24）。色盘高度必须由这份预算推导：只按宽度取
          // 正方形时，「宽而矮」的外屏会把色盘撑到屏幕之外。
          const chromeHeight = 200.0;
          final safeBottom = MediaQuery.paddingOf(context).bottom;
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final wheelSide = math
              .min(
                constraints.maxWidth - 80,
                available - chromeHeight - safeBottom,
              )
              .clamp(96.0, 320.0);

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 24),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 自定义 HS 色盘（边长由上面的高度预算决定，任何姿态都不溢出）
                  Center(
                    child: SizedBox(
                      key: const ValueKey('color-wheel'),
                      width: wheelSide,
                      height: wheelSide,
                      child: _HSColorWheel(
                        color: _currentColor,
                        onChanged: _selectColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // 两段文案都必须可收缩：窄屏（折叠外屏 / 分屏）下
                        // 固定宽度会直接把这一行撑破。
                        Flexible(
                          child: Text(
                            l10n.quickColors,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n.longPressColorToSave,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 快捷颜色栏
                  SizedBox(
                    height: 70, // Increased height for shadows and scaling
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none, // Prevent shadow clipping
                      itemCount: presetColors.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final color = presetColors[index];
                        final isSelected =
                            _currentColor.toARGB32() == color.toARGB32();

                        return Center(
                          // Center align to allow growth
                          child: GestureDetector(
                            key: ValueKey('quick-color-$index'),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _selectColor(color);
                            },
                            onLongPress: () async {
                              HapticFeedback.heavyImpact();
                              await ref
                                  .read(quickColorPaletteProvider.notifier)
                                  .replace(index, _currentColor);
                              if (context.mounted) {
                                AppToast.success(context, l10n.quickColorSaved);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 200,
                              ), // Assuming 200.ms is an extension
                              width: isSelected ? 48 : 40,
                              height: isSelected ? 48 : 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: isSelected ? 12 : 6,
                                    spreadRadius: isSelected ? 2 : 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: color.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                      size: 24,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 高级 HS (Hue-Saturation) 色盘
class _HSColorWheel extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _HSColorWheel({required this.color, required this.onChanged});

  @override
  State<_HSColorWheel> createState() => _HSColorWheelState();
}

class _HSColorWheelState extends State<_HSColorWheel> {
  // 缓存滚轮的大小
  double _radius = 0;

  void _handleGesture(Offset localPosition) {
    // 1. 计算相对于中心的偏移
    final center = Offset(_radius, _radius);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // 2. 计算极坐标
    final distance = math.sqrt(dx * dx + dy * dy);

    // 饱和度 (Saturation) = 距离 / 半径 (限制在 0~1)
    double s = (distance / _radius).clamp(0.0, 1.0);

    // 色相 (Hue) = 角度 (0~360)
    // atan2 返回 -pi ~ pi，我们需要转换为 0 ~ 360
    double angle = math.atan2(dy, dx);
    double h = (angle * 180 / math.pi) + 90; // +90 是为了让红色在顶部（习惯设定，可选）
    if (h < 0) h += 360;

    // 3. 转换为 HSV 并转回 Color
    // 假设 Value (Brightness) = 1.0 (全亮)
    final hsv = HSVColor.fromAHSV(1.0, h, s, 1.0);
    widget.onChanged(hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _radius = constraints.maxWidth / 2;

        // 反算当前颜色的位置，用于绘制 Thumb
        final hsv = HSVColor.fromColor(widget.color);
        final theta = (hsv.hue - 90) * math.pi / 180;
        final r = hsv.saturation * _radius;
        final thumbX = _radius + r * math.cos(theta);
        final thumbY = _radius + r * math.sin(theta);

        return GestureDetector(
          onPanUpdate: (details) => _handleGesture(details.localPosition),
          onPanDown: (details) {
            HapticFeedback.selectionClick();
            _handleGesture(details.localPosition);
          },
          child: Stack(
            children: [
              // 背景色盘
              CustomPaint(
                painter: _WheelPainter(),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),

              // 指示器 Thumb
              Positioned(
                left: thumbX - 16, // 32/2
                top: thumbY - 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 绘制色相 (Hue) - 扫描渐变
    final hueShader = const SweepGradient(
      colors: [
        Color(0xFFFF0000), // 0 deg - Red
        Color(0xFFFFFF00), // Yellow (60)
        Color(0xFF00FF00), // Green (120)
        Color(0xFF00FFFF), // Cyan (180)
        Color(0xFF0000FF), // Blue (240)
        Color(0xFFFF00FF), // Magenta (300)
        Color(0xFFFF0000), // Red (360)
      ],
      // 注意：SweepGradient 默认从 0 (3点钟) 顺时针
      // 我们想要红色在顶部 (-pi/2 or 12点钟)，所以旋转 -90度
      transform: GradientRotation(math.pi / -2),
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final huePaint = Paint()..shader = hueShader;
    canvas.drawCircle(center, radius, huePaint);

    // 2. 绘制饱和度 (Saturation) - 径向渐变 (中心白 -> 边缘透明)
    final satShader = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final satPaint = Paint()..shader = satShader;
    canvas.drawCircle(center, radius, satPaint);

    // 3. 绘制外边框 (可选，增加精致感)
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
