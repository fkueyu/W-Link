import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'device_list_screen.dart';
import 'device_control_screen.dart';

/// 宽屏阈值：超过此宽度启用双栏布局
const double _kSplitBreakpoint = 800;

/// 自适应布局壳
/// - 宽屏（iPad 横屏 / macOS）：左边设备列表 + 右边控制页
/// - 窄屏（iPhone / iPad 竖屏）：传统的 push 导航
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  WledDevice? _selectedDevice;

  void _onDeviceSelected(WledDevice device) {
    setState(() => _selectedDevice = device);
    ref.read(currentDeviceIdProvider.notifier).state = device.id;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > _kSplitBreakpoint;

        if (!isWide) {
          // 窄屏：直接使用原有的设备列表页（带 push 导航）
          return const DeviceListScreen();
        }

        // 宽屏：双栏布局
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: AnimatedBackground(
            child: SafeArea(
              child: Row(
                children: [
                  // ── 左栏：设备列表 ──
                  SizedBox(
                    width: 340,
                    child: DeviceListScreen(
                      onDeviceSelected: _onDeviceSelected,
                      selectedDeviceId: _selectedDevice?.id,
                    ),
                  ),
                  // ── 分隔线 ──
                  Container(
                    width: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  // ── 右栏：控制页 ──
                  Expanded(
                    child: _selectedDevice != null
                        ? DeviceControlScreen(
                            key: ValueKey(_selectedDevice!.id),
                            device: _selectedDevice!,
                            embedded: true,
                          )
                        : _buildEmptyDetail(isDark),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDetail(bool isDark) {
    final l10n = ref.watch(l10nProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.selectDevices,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}
