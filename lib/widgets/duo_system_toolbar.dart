import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';

/// 把头部动作同步到**系统**工具栏（B 方案探针）。
///
/// 本身不渲染任何东西：它只做两件事——下发按钮/菜单描述，以及控制系统栏显隐。
/// 调用方只在 `duoToolbarReadyProvider` 为 true 时挂载，失败时保留 Flutter 入口。
class DuoSystemToolbar extends ConsumerStatefulWidget {
  const DuoSystemToolbar({
    super.key,
    required this.visible,
    required this.addLabel,
    required this.moreLabel,
    required this.menu,
    required this.onAdd,
    required this.onMenuSelected,
    this.backLabel,
    this.onBack,
    this.addSymbol = 'plus',
    this.addEnabled = true,
    this.showMenu = true,
    this.showPrimary = true,
    this.addDestructive = false,
    this.addBusy = false,
  });

  /// 系统栏是否显示。页面被推入新路由时应为 false。
  final bool visible;
  final String addLabel;
  final String moreLabel;
  final List<DuoToolbarMenuEntry> menu;
  final VoidCallback onAdd;
  final ValueChanged<String> onMenuSelected;
  final String? backLabel;
  final VoidCallback? onBack;
  final String addSymbol;
  final bool addEnabled;
  final bool showMenu;
  final bool showPrimary;
  final bool addDestructive;
  final bool addBusy;

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
  int _syncGeneration = 0;

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
        oldWidget.backLabel != widget.backLabel ||
        oldWidget.onBack != widget.onBack ||
        oldWidget.addSymbol != widget.addSymbol ||
        oldWidget.addEnabled != widget.addEnabled ||
        oldWidget.showMenu != widget.showMenu ||
        oldWidget.showPrimary != widget.showPrimary ||
        oldWidget.addDestructive != widget.addDestructive ||
        oldWidget.addBusy != widget.addBusy ||
        oldWidget.onAdd != widget.onAdd ||
        oldWidget.onMenuSelected != widget.onMenuSelected ||
        oldWidget.menu != widget.menu) {
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    final generation = ++_syncGeneration;
    // 通道调用不放进 build：post-frame 里做，失败也不影响本帧布局。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _syncGeneration) return;
      _sync(generation);
    });
  }

  Future<void> _sync(int generation) async {
    final service = _service;
    if (service == null || !service.isSupported) return;

    if (!widget.visible) {
      service.release(this);
      return;
    }
    service.claim(this);
    service.onAddTap =
        widget.showPrimary && widget.addEnabled && !widget.addBusy
        ? widget.onAdd
        : null;
    service.onBackTap = widget.onBack;
    service.onMenuSelect = widget.onMenuSelected;
    final applied = await service.setItems(
      addLabel: widget.addLabel,
      moreLabel: widget.moreLabel,
      menu: widget.menu,
      backLabel: widget.backLabel,
      addSymbol: widget.addSymbol,
      addEnabled: widget.addEnabled,
      showMenu: widget.showMenu,
      showPrimary: widget.showPrimary,
      addDestructive: widget.addDestructive,
      addBusy: widget.addBusy,
    );
    if (!mounted ||
        generation != _syncGeneration ||
        !widget.visible ||
        !service.isOwnedBy(this)) {
      return;
    }
    if (!applied) {
      ref.read(duoToolbarFallbackProvider.notifier).state = true;
      return;
    }
    final shown = await service.setVisible(true);
    if (!shown &&
        mounted &&
        generation == _syncGeneration &&
        widget.visible &&
        service.isOwnedBy(this)) {
      ref.read(duoToolbarFallbackProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _syncGeneration++;
    // 页面销毁时务必收回系统栏，避免它残留在后续路由上。
    final service = _service;
    if (service != null) {
      service.release(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
