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

/// 双栏结构的定位键。布局判据按名字找这些节点，避免在测试里复制字符串。
const String kSplitRowKey = 'adaptive-shell-split';
const String kDeviceListPaneKey = 'adaptive-shell-device-list';
const String kSplitDividerKey = 'adaptive-shell-divider';
const String kDetailPaneKey = 'adaptive-shell-detail';

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
    final l10n = ref.watch(l10nProvider);
    ref.listen<DeviceCommandFailure?>(deviceCommandFailureProvider, (
      previous,
      next,
    ) {
      if (next == null || next.sequence == previous?.sequence) return;
      AppToast.error(context, l10n.controlFailed);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final duo = ref.watch(duoGeometryProvider).valueOrNull;

        // 半折/横折时内容会被折痕拦腰切断，横向双栏必须让位给单栏。
        // 拿不到折叠信息（非折叠设备、系统低于 iOS 27.1）时两条都为 false，
        // 布局与改动前逐像素一致。
        final foldX = duo?.verticalFoldX;
        final isWide =
            constraints.maxWidth > _kSplitBreakpoint &&
            !(duo?.needsSinglePane ?? false);

        if (!isWide) {
          // 窄屏：直接使用原有的设备列表页（带 push 导航）
          return const DeviceListScreen();
        }

        // 竖折时把分隔线对到折痕上：两栏各自完整地待在半个屏幕上，
        // 分隔线就是物理折痕，不再额外画一条。折痕位置超出可用区间
        // （太窄的左栏 / 太宽的左栏）就退回固定 340，不硬套。
        final foldAligned =
            foldX != null &&
            foldX >= 300 &&
            foldX <= constraints.maxWidth * 0.55;

        // 宽屏：双栏布局
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: AnimatedBackground(
            child: SafeArea(
              child: Row(
                key: const Key(kSplitRowKey),
                children: [
                  // ── 左栏：设备列表 ──
                  SizedBox(
                    key: const Key(kDeviceListPaneKey),
                    width: foldAligned ? foldX : 340,
                    child: DeviceListScreen(
                      onDeviceSelected: _onDeviceSelected,
                      selectedDeviceId: _selectedDevice?.id,
                    ),
                  ),
                  // ── 分隔线（折痕对齐时由硬件折痕充当） ──
                  if (!foldAligned)
                    Container(
                      key: const Key(kSplitDividerKey),
                      width: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  // ── 右栏：控制页 ──
                  Expanded(
                    key: const Key(kDetailPaneKey),
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
