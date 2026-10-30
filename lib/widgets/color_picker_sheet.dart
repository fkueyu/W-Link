import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import 'app_toast.dart';
import 'glass_sheet.dart';

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
  late final TextEditingController _hexController;
  bool _invalidHex = false;
  int? _focusedQuickColor;

  String _hexValue(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(text: _hexValue(_currentColor));
    _dispatcher = LatestValueDispatcher<Color>(widget.onColorChanged);
  }

  void _selectColor(Color color) {
    setState(() {
      _currentColor = color;
      _invalidHex = false;
      _hexController.text = _hexValue(color);
    });
    _dispatcher.submit(color);
  }

  void _applyHex() {
    final value = _hexController.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) {
      setState(() => _invalidHex = true);
      return;
    }
    _selectColor(Color(0xFF000000 | int.parse(value, radix: 16)));
  }

  Future<void> _replaceQuickColor(int index, Color color) async {
    final message = ref.read(l10nProvider).quickColorSaved;
    await ref.read(quickColorPaletteProvider.notifier).replace(index, color);
    if (mounted) AppToast.success(context, message);
  }

  Future<void> _showReplaceQuickColor() async {
    final l10n = ref.read(l10nProvider);
    final isChinese = l10n is ZhStrings;
    final color = _currentColor;
    final palette = ref.read(quickColorPaletteProvider);
    final index = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isChinese ? '替换快捷色' : 'Replace quick color'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isChinese
                    ? '用当前颜色 ${_hexValue(color)} 替换选定的快捷色。'
                    : 'Replace a selected quick color with ${_hexValue(color)}.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: palette.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: palette[index],
                      ),
                    ),
                    title: Text('${l10n.quickColors} ${index + 1}'),
                    subtitle: Text(_hexValue(palette[index])),
                    onTap: () => Navigator.pop(context, index),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (index != null && mounted) await _replaceQuickColor(index, color);
  }

  @override
  void dispose() {
    _hexController.dispose();
    _dispatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presetColors = ref.watch(quickColorPaletteProvider);
    final l10n = ref.watch(l10nProvider);
    final isChinese = l10n is ZhStrings;

    // ModalBottomSheet 不会替内容避让键盘；这里让可滚动区域收到真实可用高度。
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassSheet(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 额外预留44pt替换入口的高度；宽矮屏按剩余高度缩小色轮，
            // 常规外屏仍完整显示色轮、HEX和快捷色。
            // 大字或错误提示可自然增高并滚动，不裁切输入控件。
            const chromeHeight = 224.0;
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
                        width: wheelSide,
                        height: wheelSide,
                        child: Semantics(
                          key: const ValueKey('color-wheel'),
                          container: true,
                          label: isChinese ? '色轮' : 'Color wheel',
                          value: _hexValue(_currentColor),
                          hint: isChinese
                              ? '可在下方 HEX 输入精确设置颜色'
                              : 'Enter a HEX value below to set an exact color',
                          child: ExcludeSemantics(
                            child: _HSColorWheel(
                              color: _currentColor,
                              onChanged: _selectColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        key: const ValueKey('color-hex-input'),
                        controller: _hexController,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.characters,
                        scrollPadding: const EdgeInsets.all(24),
                        onSubmitted: (_) => _applyHex(),
                        decoration: InputDecoration(
                          labelText: isChinese ? 'HEX 色值' : 'HEX color',
                          hintText: '#RRGGBB',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: const OutlineInputBorder(),
                          errorText: _invalidHex
                              ? (isChinese
                                    ? '请输入 6 位 HEX 色值，如 #12ABCD'
                                    : 'Enter 6 HEX digits, e.g. #12ABCD')
                              : null,
                          errorMaxLines: 2,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          suffixIcon: IconButton(
                            tooltip: isChinese ? '应用颜色' : 'Apply color',
                            onPressed: _applyHex,
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

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
                            child: TextButton(
                              onPressed: _showReplaceQuickColor,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                              ),
                              child: Text(
                                isChinese ? '替换快捷色' : 'Replace quick color',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 快捷颜色栏
                    SizedBox(
                      height: 54, // 48pt 热区与选中圆点，另留少量阴影空间
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
                            child: Semantics(
                              key: ValueKey('quick-color-$index'),
                              button: true,
                              selected: isSelected,
                              label: '${l10n.quickColors} ${index + 1}',
                              value: _hexValue(color),
                              hint: l10n.longPressColorToSave,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onFocusChange: (focused) => setState(() {
                                  _focusedQuickColor = focused ? index : null;
                                }),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _selectColor(color);
                                },
                                onLongPress: () async {
                                  HapticFeedback.heavyImpact();
                                  await _replaceQuickColor(
                                    index,
                                    _currentColor,
                                  );
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  foregroundDecoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: _focusedQuickColor == index
                                        ? Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                  child: Center(
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
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
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
                                              color:
                                                  color.computeLuminance() > 0.5
                                                  ? Colors.black
                                                  : Colors.white,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
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
