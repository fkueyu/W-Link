import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import 'bouncy_button.dart';

class DeviceOverviewBar extends StatefulWidget {
  final int totalDevices;
  final int onlineDevices;
  final bool isWifiConnected;
  final AppStrings strings;
  final Future<void> Function() onRefresh;

  const DeviceOverviewBar({
    super.key,
    required this.totalDevices,
    required this.onlineDevices,
    required this.isWifiConnected,
    required this.strings,
    required this.onRefresh,
  });

  @override
  State<DeviceOverviewBar> createState() => _DeviceOverviewBarState();
}

class _DeviceOverviewBarState extends State<DeviceOverviewBar> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    HapticFeedback.selectionClick();
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final onlineColor = widget.onlineDevices > 0
        ? FluxTheme.success
        : FluxTheme.offline;
    final semanticsLabel =
        '${widget.strings.onlineCount(widget.onlineDevices)}, '
        '${widget.strings.deviceCount(widget.totalDevices)}, '
        '${widget.isWifiConnected ? widget.strings.networkReady : widget.strings.networkUnavailable}';

    final items = <Widget>[
      _StatusItem(
        color: onlineColor,
        label: widget.strings.onlineCount(widget.onlineDevices),
      ),
      Text(
        widget.strings.deviceCount(widget.totalDevices),
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      SizedBox.square(
        dimension: 16,
        child: _isRefreshing
            ? const CircularProgressIndicator(
                strokeWidth: 1.8,
                color: FluxTheme.primary,
              )
            : Icon(
                widget.isWifiConnected
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                size: 15,
                color: widget.isWifiConnected ? muted : FluxTheme.warning,
              ),
      ),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
    return BouncyButton(
      semanticLabel: semanticsLabel,
      onTap: _refresh,
      scaleTarget: 0.97,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.065)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : FluxTheme.primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: onlineColor.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: largeText
            ? Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: items,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  items[0],
                  _divider(isDark),
                  items[1],
                  _divider(isDark, horizontalMargin: 7),
                  items[2],
                ],
              ),
      ),
    );
  }

  Widget _divider(bool isDark, {double horizontalMargin = 8}) {
    return Container(
      width: 1,
      height: 14,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 7),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }
}
