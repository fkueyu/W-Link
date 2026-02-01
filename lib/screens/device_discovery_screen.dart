import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

/// 设备发现页面
class DeviceDiscoveryScreen extends ConsumerStatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  ConsumerState<DeviceDiscoveryScreen> createState() =>
      _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends ConsumerState<DeviceDiscoveryScreen> {
  bool _isScanning = false;
  final _mdnsService = MdnsDiscoveryService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMdnsScan());
  }

  @override
  void dispose() {
    _mdnsService.dispose();
    super.dispose();
  }

  Future<void> _startMdnsScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    ref.read(discoveredDevicesProvider.notifier).clear();
    try {
      await for (final device in _mdnsService.scanDevices()) {
        if (!mounted) break;
        ref.read(discoveredDevicesProvider.notifier).addDevice(device);
      }
    } catch (e) {
      debugPrint('[DeviceDiscovery] Scan error: $e');
    }
    if (mounted) setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // iOS Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    children: [
                      BouncyButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        l10n.foundDevices,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const Spacer(),
                      BouncyButton(
                        onTap: _startMdnsScan,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FluxTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: FluxTheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 网络状态提示
              if (!ref.watch(isWifiConnectedProvider))
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
                          const Expanded(
                            child: Text(
                              '您未连接到 Wi-Fi。扫描功能仅可在连接局域网时发现 WLED 设备。',
                              style: TextStyle(
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

              // Scan Status Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: FluxTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isScanning
                              ? const Center(
                                  child: RadarRipple(
                                    color: FluxTheme.primary,
                                    size: 36,
                                  ),
                                )
                              : const Icon(
                                  Icons.wifi_tethering_rounded,
                                  color: FluxTheme.primary,
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning
                                    ? l10n.scanningNetwork
                                    : l10n.scanComplete,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.foundCount(discoveredDevices.length),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // List Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                  child: Text(
                    l10n.availableDevices.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // Devices List
              if (discoveredDevices.isEmpty && !_isScanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color: FluxTheme.primary.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.noDevicesFound,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.checkNetwork,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final device = discoveredDevices[index];
                      final isAdded = devices.any((d) => d.id == device.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child:
                            DiscoveredDeviceCard(
                                  device: device,
                                  isAdded: isAdded,
                                  onAdd: () {
                                    HapticFeedback.mediumImpact();
                                    ref
                                        .read(deviceListProvider.notifier)
                                        .addDevice(device);
                                    AppToast.success(
                                      context,
                                      '${l10n.deviceAdded} ${device.name}',
                                    );
                                  },
                                )
                                .animate()
                                .fadeIn(delay: (index * 50).ms)
                                .slideY(begin: 0.1),
                      );
                    }, childCount: discoveredDevices.length),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          BouncyButton(
                onTap: () => _showAddDeviceDialog(context, l10n, isDark),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.8),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_link_rounded,
                            color: FluxTheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.manualAdd,
                            style: const TextStyle(
                              color: FluxTheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 500.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutBack),
    );
  }

  void _showAddDeviceDialog(
    BuildContext context,
    AppStrings l10n,
    bool isDark,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child:
              Material(
                    type: MaterialType.transparency,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: FluxTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.dns_rounded,
                                    color: FluxTheme.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.manualAdd,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: l10n.ipAddressHint,
                                    prefixIcon: const Icon(Icons.link_rounded),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          l10n.cancel,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: FluxTheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: () async {
                                          final ip = controller.text.trim();
                                          if (ip.isEmpty) return;
                                          Navigator.pop(context);
                                          final device =
                                              await MdnsDiscoveryService.verifyDevice(
                                                ip,
                                              );
                                          if (!context.mounted) return;
                                          if (device != null) {
                                            ref
                                                .read(
                                                  deviceListProvider.notifier,
                                                )
                                                .addDevice(device);
                                            AppToast.success(
                                              context,
                                              '${l10n.deviceAdded} ${device.name}',
                                            );
                                          } else {
                                            AppToast.error(
                                              context,
                                              l10n.connectionFailed,
                                            );
                                          }
                                        },
                                        child: Text(
                                          l10n.addDevice,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(),
        ),
      ),
    );
  }
}
