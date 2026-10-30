import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'device_list_screen.dart';
import 'device_control_screen.dart';

const double _kSplitBreakpoint = 800;
const String kSplitRowKey = 'adaptive-shell-split';
const String kDeviceListPaneKey = 'adaptive-shell-device-list';
const String kSplitDividerKey = 'adaptive-shell-divider';
const String kDetailPaneKey = 'adaptive-shell-detail';

/// 设备任务由同一路由承载，路由内部根据约束切换单双栏。
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  final _deviceListStorage = PageStorageBucket();
  int _selectionGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    // 选择只保存ID；重命名和删除都以设备库中的最新对象为准。
    ref.listen(deviceListProvider, (_, devices) {
      final selected = ref.read(currentDeviceIdProvider);
      if (selected != null && !devices.any((device) => device.id == selected)) {
        ref.read(currentDeviceIdProvider.notifier).state = null;
      }
    });
    ref.listen<DeviceCommandFailure?>(deviceCommandFailureProvider, (
      previous,
      next,
    ) {
      if (next == null || next.sequence == previous?.sequence) return;
      AppToast.error(context, l10n.controlFailed);
    });
    return _AdaptiveDeviceLayout(
      showSelection: false,
      deviceListStorage: _deviceListStorage,
      onDeviceSelected: (device) async {
        final generation = ++_selectionGeneration;
        ref.read(currentDeviceIdProvider.notifier).state = device.id;
        final isWide =
            MediaQuery.sizeOf(context).width > _kSplitBreakpoint &&
            !(ref.read(duoGeometryProvider).valueOrNull?.needsSinglePane ??
                false);
        // 宽屏不播放整页进入动画；共享列表存储，让设备任务延续左栏位置。
        final route = _DeviceTaskRoute(
          enterWithoutAnimation: isWide,
          builder: (_) => _AdaptiveDeviceLayout(
            showSelection: true,
            deviceListStorage: _deviceListStorage,
            animateListEntrance: false,
            onDeviceSelected: (selected) {
              ref.read(currentDeviceIdProvider.notifier).state = selected.id;
            },
          ),
        );
        await Navigator.of(context).push<void>(route);
        // popped在退出动画开始时完成；completed才代表路由和画面已退出。
        await route.completed;
        if (mounted && generation == _selectionGeneration) {
          ref.read(currentDeviceIdProvider.notifier).state = null;
        }
      },
    );
  }
}

class _DeviceTaskRoute extends MaterialPageRoute<void> {
  _DeviceTaskRoute({
    required super.builder,
    required this.enterWithoutAnimation,
  });
  final bool enterWithoutAnimation;
  @override
  Duration get transitionDuration =>
      enterWithoutAnimation ? Duration.zero : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

class _AdaptiveDeviceLayout extends ConsumerWidget {
  const _AdaptiveDeviceLayout({
    required this.showSelection,
    required this.onDeviceSelected,
    required this.deviceListStorage,
    this.animateListEntrance = true,
  });
  final PageStorageBucket deviceListStorage;
  final bool animateListEntrance;
  final bool showSelection;
  final ValueChanged<WledDevice> onDeviceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDevice = showSelection
        ? ref.watch(currentDeviceProvider)
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final duo = ref.watch(duoGeometryProvider).valueOrNull;
        final safePadding = MediaQuery.paddingOf(context);
        final availableWidth = constraints.maxWidth - safePadding.horizontal;
        // 桥的坐标属于FlutterView，Row的坐标属于SafeArea内容区。
        final foldX = duo?.verticalFoldX == null
            ? null
            : duo!.verticalFoldX! - safePadding.left;
        final isWide =
            constraints.maxWidth > _kSplitBreakpoint &&
            !(duo?.needsSinglePane ?? false);
        if (!isWide) {
          if (selectedDevice != null) {
            return DeviceControlScreen(
              key: ValueKey(selectedDevice.id),
              device: selectedDevice,
            );
          }
          return PageStorage(
            bucket: deviceListStorage,
            child: DeviceListScreen(
              onDeviceSelected: onDeviceSelected,
              embedded: false,
              animateEntrance: animateListEntrance,
            ),
          );
        }
        final foldAligned =
            foldX != null && foldX >= 300 && foldX <= availableWidth * 0.55;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          body: AnimatedBackground(
            child: SafeArea(
              child: Row(
                key: const Key(kSplitRowKey),
                children: [
                  SizedBox(
                    key: const Key(kDeviceListPaneKey),
                    width: foldAligned ? foldX : 340,
                    child: PageStorage(
                      bucket: deviceListStorage,
                      child: DeviceListScreen(
                        embedded: true,
                        onDeviceSelected: onDeviceSelected,
                        selectedDeviceId: selectedDevice?.id,
                        systemToolbarVisible: selectedDevice == null,
                        animateEntrance: animateListEntrance,
                      ),
                    ),
                  ),
                  if (!foldAligned)
                    Container(
                      key: const Key(kSplitDividerKey),
                      width: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  Expanded(
                    key: const Key(kDetailPaneKey),
                    child: selectedDevice != null
                        ? DeviceControlScreen(
                            key: ValueKey(selectedDevice.id),
                            device: selectedDevice,
                            embedded: true,
                          )
                        : _buildEmptyDetail(context, ref),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDetail(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.selectDevices,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
