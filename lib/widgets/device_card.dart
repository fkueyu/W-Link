import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import 'widgets.dart';

/// 设备卡片组件 - 玻璃态 + 动态光效
class DeviceCard extends ConsumerStatefulWidget {
  final WledDevice device;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onDelete,
  });

  @override
  ConsumerState<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<DeviceCard> {
  double? _localBrightness;

  Color _getDeviceColor(WledState? state) {
    if (state == null || state.seg.isEmpty || state.seg.first.col.isEmpty) {
      return FluxTheme.primary;
    }
    final col = state.seg.first.col.first;
    if (col.length >= 3) {
      return Color.fromARGB(255, col[0], col[1], col[2]);
    }
    return FluxTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(deviceFamilyStateProvider(widget.device));
    final state = stateAsync.valueOrNull;

    final deviceColor = _getDeviceColor(state);
    final isOnline = stateAsync.hasValue;
    final isOn = state?.on ?? false;
    final hasGlow = isOnline && isOn;
    final glowColor = hasGlow ? deviceColor : Colors.transparent;
    final brightness = _localBrightness ?? state?.bri.toDouble() ?? 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = ref.watch(l10nProvider);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: BouncyButton(
          onTap: widget.onTap,
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showDeleteConfirm(context, ref, isDark);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                if (hasGlow)
                  BoxShadow(
                    color: glowColor.withValues(alpha: isDark ? 0.45 : 0.25),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                if (isDark) // Deep depth shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: FluxTheme.glassDecoration(
                    context,
                    radius: 36,
                    hasShadow: true,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildStatusIcon(isOnline, isOn, deviceColor, isDark),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Hero(
                                  tag: 'name_${widget.device.id}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Text(
                                      widget.device.name,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                Hero(
                                  tag: 'ip_${widget.device.id}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Text(
                                      widget.device.ip,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.black38,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildPowerToggle(
                            ref,
                            state!,
                            glowColor,
                            isDark,
                            isOnline,
                          ),
                        ],
                      ),
                      if (isOnline) ...[
                        const SizedBox(height: 28),
                        _buildBrightnessControl(
                          context,
                          ref,
                          state,
                          brightness,
                          isOn ? deviceColor : Colors.grey,
                          isDark,
                          l10n,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isOnline, bool isOn, Color color, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: !isOnline
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03))
            : (isOn
                  ? color.withValues(alpha: 0.15)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))),
        shape: BoxShape.circle,
        border: Border.all(
          color: isOn ? color.withValues(alpha: 0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          !isOnline
              ? Icons.cloud_off_rounded
              : (isOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded),
          color: !isOnline
              ? (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black26)
              : (isOn
                    ? color
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black26)),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPowerToggle(
    WidgetRef ref,
    WledState state,
    Color glowColor,
    bool isDark,
    bool isOnline,
  ) {
    if (!isOnline) return const SizedBox.shrink();
    final isOn = state.on;
    return BouncyButton(
      onTap: () {
        HapticFeedback.mediumImpact();
        final notifier = ref.read(
          deviceFamilyStateProvider(widget.device).notifier,
        );
        notifier.optimisticUpdate((s) => s.copyWith(on: !isOn), () async {
          final api = WledApiService(baseUrl: widget.device.baseUrl);
          try {
            return await api.setOn(!isOn);
          } finally {
            api.dispose();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOn
              ? (isDark
                    ? Color.lerp(
                        glowColor,
                        Colors.white,
                        0.15,
                      )!.withValues(alpha: 0.8)
                    : glowColor)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
          shape: BoxShape.circle,
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: glowColor.withValues(alpha: isDark ? 0.3 : 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            if (isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Icon(
          Icons.power_settings_new_rounded,
          color: isOn
              ? Colors.white
              : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBrightnessControl(
    BuildContext context,
    WidgetRef ref,
    WledState state,
    double brightness,
    Color deviceColor,
    bool isDark,
    AppStrings l10n,
  ) {
    final percent = (brightness / 255 * 100).round();

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 进度填充层
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (brightness / 255).clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: deviceColor.withValues(alpha: isDark ? 0.4 : 0.3),
                  borderRadius: BorderRadius.circular(19),
                  gradient: LinearGradient(
                    colors: [
                      deviceColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      deviceColor.withValues(alpha: isDark ? 0.8 : 0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 交互层 (Slider)
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 38,
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackShape: const _FullWidthTrackShape(),
            ),
            child: Slider(
              value: brightness,
              min: 0,
              max: 255,
              onChanged: (v) => setState(() => _localBrightness = v),
              onChangeEnd: (v) {
                setState(() => _localBrightness = null);
                final bri = v.round();
                ref
                    .read(deviceFamilyStateProvider(widget.device).notifier)
                    .optimisticUpdate(
                      (s) => s.copyWith(on: bri > 0, bri: bri),
                      () async {
                        final api = WledApiService(
                          baseUrl: widget.device.baseUrl,
                        );
                        try {
                          return await api.setBrightness(bri);
                        } finally {
                          api.dispose();
                        }
                      },
                    );
              },
            ),
          ),
          // 内容层 (Icon + Percentage)
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black38,
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, bool isDark) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child:
            Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? FluxTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.delete,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${l10n.deleteConfirm} (${widget.device.name})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  widget.onDelete();
                                },
                                child: Text(l10n.delete),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack)
                .fadeIn(),
      ),
    );
  }
}

class _FullWidthTrackShape extends SliderTrackShape {
  const _FullWidthTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      parentBox.size.width,
      parentBox.size.height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue;
    final double visualWidth =
        trackRect.width * (thumbCenter.dx / trackRect.width);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          trackRect.left,
          trackRect.top,
          visualWidth.clamp(0.0, trackRect.width),
          trackRect.height,
        ),
        Radius.circular(trackRect.height / 2),
      ),
      activePaint,
    );
  }
}

/// 发现的设备卡片
class DiscoveredDeviceCard extends ConsumerWidget {
  final WledDevice device;
  final bool isAdded;
  final VoidCallback onAdd;

  const DiscoveredDeviceCard({
    super.key,
    required this.device,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FluxTheme.primary.withValues(alpha: 0.2),
                    FluxTheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: FluxTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    device.ip,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdded)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.deviceAdded,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              BouncyButton(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: FluxTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: FluxTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.addDevice,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
