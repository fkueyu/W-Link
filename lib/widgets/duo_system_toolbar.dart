import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';

/// 把头部动作同步到**系统**工具栏（B 方案探针）。
///
/// 本身不渲染任何东西：它只做两件事——下发按钮/菜单描述，以及控制系统栏显隐。
/// 只有当 [visible] 为 true 且设备是折叠屏（`DuoGeometry.supported`）时，
/// 调用方才应该用系统栏替代自绘的动作行；否则一切都保持原样。
class DuoSystemToolbar extends ConsumerStatefulWidget {
  const DuoSystemToolbar({
    super.key,
    required this.visible,
    required this.addLabel,
    required this.moreLabel,
    required this.menu,
    required this.onAdd,
    required this.onMenuSelected,
  });

  /// 系统栏是否显示。页面被推入新路由时应为 false。
  final bool visible;
  final String addLabel;
  final String moreLabel;
  final List<DuoToolbarMenuEntry> menu;
  final VoidCallback onAdd;
  final ValueChanged<String> onMenuSelected;

  @override
  ConsumerState<DuoSystemToolbar> createState() => _DuoSystemToolbarState();
}

class _DuoSystemToolbarState extends ConsumerState<DuoSystemToolbar> {
  /// 在 `initState` 里取一次并缓存。
  ///
  /// **不能在 `dispose()` 里 `ref.read`**：此时 ConsumerStatefulElement 已标记
  /// 为 disposed，会抛「Cannot use "ref" after the widget was disposed」。
  /// 而 `dispose()` 恰恰是最需要收回系统栏的地方。
  DuoToolbarService? _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(duoToolbarServiceProvider);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(DuoSystemToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.addLabel != widget.addLabel ||
        oldWidget.moreLabel != widget.moreLabel ||
        oldWidget.menu != widget.menu) {
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    // 通道调用不放进 build：post-frame 里做，失败也不影响本帧布局。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync();
    });
  }

  Future<void> _sync() async {
    final service = _service;
    if (service == null || !service.isSupported) return;

    service.onAddTap = widget.onAdd;
    service.onMenuSelect = widget.onMenuSelected;

    await service.setItems(
      addLabel: widget.addLabel,
      moreLabel: widget.moreLabel,
      menu: widget.menu,
    );
    await service.setVisible(widget.visible);
  }

  @override
  void dispose() {
    // 页面销毁时务必收回系统栏，避免它残留在后续路由上。
    final service = _service;
    if (service != null) {
      service.onAddTap = null;
      service.onMenuSelect = null;
      if (service.isSupported) {
        // 不 await：dispose 是同步的。
        service.setVisible(false);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
