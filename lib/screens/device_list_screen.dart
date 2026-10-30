import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import 'device_control_screen.dart';
import 'device_discovery_screen.dart';
import 'groups_management_screen.dart';
import 'settings_screen.dart';

/// 设备列表页 - 简洁首页
class DeviceListScreen extends ConsumerWidget {
  /// 双栏模式回调：选择设备时触发，不走 push 导航
  final void Function(WledDevice device)? onDeviceSelected;

  /// 双栏模式下当前选中的设备 ID（用于高亮）
  final String? selectedDeviceId;
  final bool? embedded;
  final bool animateEntrance;
  final bool systemToolbarVisible;

  const DeviceListScreen({
    super.key,
    this.onDeviceSelected,
    this.selectedDeviceId,
    this.embedded,
    this.animateEntrance = true,
    this.systemToolbarVisible = true,
  });

  Widget _headerEntrance(Widget child) => animateEntrance
      ? child.animate().scale(duration: 600.ms, curve: Curves.easeOutBack)
      : child;

  Widget _cardEntrance(Widget child, int index) => animateEntrance
      ? child.animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1)
      : child;

  /// 是否处于双栏嵌入模式
  bool get _isEmbedded => embedded ?? onDeviceSelected != null;

  void _navigateToControl(
    BuildContext context,
    WidgetRef ref,
    WledDevice device,
  ) {
    if (onDeviceSelected != null) {
      onDeviceSelected!(device);
    } else {
      ref.read(currentDeviceIdProvider.notifier).state = device.id;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DeviceControlScreen(device: device)),
      );
    }
  }

  /// 「更多」菜单的动作。自绘弹窗与系统菜单共用同一份，避免两处走岔。
  void _openMenuAction(BuildContext context, String value) {
    if (value == 'groups') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GroupsManagementScreen()),
      );
    } else if (value == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  void _navigateToDiscovery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceDiscoveryScreen()),
    );
  }

  Future<void> _refreshDevices(WidgetRef ref, List<WledDevice> devices) async {
    await Future.wait(
      devices.map(
        (device) => ref
            .read(deviceFamilyStateProvider(device.id).notifier)
            .forceRefresh(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final l10n = ref.watch(l10nProvider);
    final isWifiConnected = ref.watch(isWifiConnectedProvider);
    final onlineDevices = devices.where((device) => device.isOnline).length;

    // B 方案探针：折叠屏上把两个头部动作交给**系统**工具栏。
    // 非折叠设备（`supported` 为 false）一律走原来的自绘行，观感不变。
    final useSystemToolbar =
        ref.watch(duoToolbarReadyProvider).valueOrNull ?? false;
    // 被推入新路由时收回系统栏，回到本页再显示。
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    return Scaffold(
      backgroundColor: _isEmbedded ? Colors.transparent : null,
      body: _DeviceListBackground(
        embedded: _isEmbedded,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await _refreshDevices(ref, devices);
            },
            color: FluxTheme.primary,
            child: CustomScrollView(
              key: const PageStorageKey('device-library-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (useSystemToolbar)
                          DuoSystemToolbar(
                            visible: routeIsCurrent && systemToolbarVisible,
                            addLabel: l10n.addDevice,
                            moreLabel: l10n.moreActions,
                            menu: [
                              DuoToolbarMenuEntry(
                                id: 'groups',
                                title: l10n.deviceGroups,
                                symbol: 'square.3.layers.3d',
                              ),
                              DuoToolbarMenuEntry(
                                id: 'settings',
                                title: l10n.settings,
                                symbol: 'gearshape',
                              ),
                            ],
                            onAdd: () => _navigateToDiscovery(context),
                            onMenuSelected: (id) =>
                                _openMenuAction(context, id),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _headerEntrance(
                                    Semantics(
                                      image: true,
                                      label: l10n.appTitle,
                                      excludeSemantics: true,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.black.withValues(
                                                      alpha: 0.3,
                                                    )
                                                  : FluxTheme.primary
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.asset(
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? 'assets/icons/icon_dark.png'
                                                : 'assets/icons/icon_light.png',
                                            width: 44,
                                            height: 44,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.appTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5,
                                              ),
                                        ),
                                        Text(
                                          l10n.controllers,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white38
                                                : Colors.black38,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── 头部动作条 ──
                            //
                            // 折叠屏上整行交给系统工具栏（见上方 DuoSystemToolbar），
                            // 这里只在非折叠设备渲染。
                            if (!useSystemToolbar) ...[
                              //
                              // 「添加设备」和「更多」收进同一行，而不是用一个
                              // 底部浮动按钮：双栏模式（`_isEmbedded`）下整个
                              // Scaffold 归外壳所有，浮动按钮会被置空 —— 那样
                              // 宽屏上「添加设备」会**一个入口都不剩**。
                              //
                              // 另外这里原来是 `Icons.search_rounded` +
                              // `l10n.search`，但它 `onTap` 去的是发现页（加
                              // 设备）。读屏用户听到「搜索」却进了加设备页。
                              BouncyButton(
                                key: const ValueKey('device-list-add'),
                                semanticLabel: l10n.addDevice,
                                onTap: () => _navigateToDiscovery(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    size: 22,
                                    color: FluxTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.more_horiz_rounded,
                                    size: 22,
                                  ),
                                ),
                                offset: const Offset(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 12,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? FluxTheme.cardDark
                                    : Colors.white.withValues(alpha: 0.98),
                                onSelected: (value) =>
                                    _openMenuAction(context, value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'groups',
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: FluxTheme.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.layers_rounded,
                                            size: 18,
                                            color: FluxTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          l10n.deviceGroups,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'settings',
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.settings_rounded,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          l10n.settings,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          l10n.myDevices,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                fontSize: 22,
                              ),
                        ),
                        DeviceOverviewBar(
                          totalDevices: devices.length,
                          onlineDevices: onlineDevices,
                          isWifiConnected: isWifiConnected,
                          strings: l10n,
                          onRefresh: () => _refreshDevices(ref, devices),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 网络状态提示
                if (!isWifiConnected)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.noWifiWarning,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 设备列表
                if (devices.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: isWifiConnected
                          ? Icons.lightbulb_outline
                          : Icons.wifi_off_rounded,
                      title: isWifiConnected
                          ? l10n.noDevices
                          : l10n.notConnectedToLan,
                      message: isWifiConnected
                          ? l10n.addFirstDeviceHint
                          : l10n.wifiRequiredHint,
                      onAction: () => _navigateToDiscovery(context),
                      actionLabel: l10n.addDevice,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final device = devices[index];
                        return _cardEntrance(
                          DeviceCard(
                            device: device,
                            selected: device.id == selectedDeviceId,
                            onTap: () =>
                                _navigateToControl(context, ref, device),
                            onDelete: () {
                              ref
                                  .read(deviceListProvider.notifier)
                                  .removeDevice(device.id);
                            },
                          ),
                          index,
                        );
                      }, childCount: devices.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      // 底部不再放浮动按钮：加设备的入口在头部动作条里（见上），
      // 空列表时还有 EmptyState 自己的主行动按钮。
    );
  }
}

class _DeviceListBackground extends StatelessWidget {
  const _DeviceListBackground({required this.embedded, required this.child});

  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return embedded ? child : AnimatedBackground(child: child);
  }
}
