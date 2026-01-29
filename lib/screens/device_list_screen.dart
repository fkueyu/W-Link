import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'device_control_screen.dart';
import 'device_discovery_screen.dart';
import 'groups_management_screen.dart';
import 'settings_screen.dart';

/// 设备列表页 - 简洁首页
class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  void _navigateToControl(
    BuildContext context,
    WidgetRef ref,
    WledDevice device,
  ) {
    ref.read(currentDeviceIdProvider.notifier).state = device.id;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceControlScreen(device: device)),
    );
  }

  void _navigateToDiscovery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceDiscoveryScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // 顶部标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                BouncyButton(
                                  onTap:
                                      () {}, // Could show app info or easter egg
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.black.withValues(
                                                  alpha: 0.3,
                                                )
                                              : FluxTheme.primary.withValues(
                                                  alpha: 0.15,
                                                ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
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
                                ).animate().scale(
                                  duration: 600.ms,
                                  curve: Curves.easeOutBack,
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.appTitle,
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
                              ],
                            ),
                          ),

                          // Action buttons
                          BouncyButton(
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
                                Icons.search_rounded,
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
                                Theme.of(context).brightness == Brightness.dark
                                ? FluxTheme.cardDark
                                : Colors.white.withValues(alpha: 0.98),
                            onSelected: (value) {
                              if (value == 'groups') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const GroupsManagementScreen(),
                                  ),
                                );
                              } else if (value == 'settings') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              }
                            },
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
                                        borderRadius: BorderRadius.circular(8),
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
                                        borderRadius: BorderRadius.circular(8),
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
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.myDevices,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 设备列表
              if (devices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.lightbulb_outline,
                    title: l10n.noDevices,
                    message: "点击下方按钮或右下角添加您的第一个 WLED 设备",
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
                      return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DeviceCard(
                              device: device,
                              onTap: () =>
                                  _navigateToControl(context, ref, device),
                              onDelete: () {
                                ref
                                    .read(deviceListProvider.notifier)
                                    .removeDevice(device.id);
                              },
                            ),
                          )
                          .animate()
                          .fadeIn(delay: (index * 100).ms)
                          .slideX(begin: 0.1);
                    }, childCount: devices.length),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          BouncyButton(
                onTap: () => _navigateToDiscovery(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.8),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: FluxTheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.addDevice,
                            style: const TextStyle(
                              color: FluxTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 600.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutBack, duration: 800.ms),
    );
  }
}
