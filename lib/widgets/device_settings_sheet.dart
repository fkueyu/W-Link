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
import 'smart_slider.dart';

/// 设备设置面板
class DeviceSettingsSheet extends ConsumerStatefulWidget {
  final WledApiService api;
  final WledState state;

  const DeviceSettingsSheet({
    super.key,
    required this.api,
    required this.state,
  });

  @override
  ConsumerState<DeviceSettingsSheet> createState() =>
      _DeviceSettingsSheetState();
}

class _DeviceSettingsSheetState extends ConsumerState<DeviceSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final infoAsync = ref.watch(deviceInfoProvider);
    final providerState = ref.watch(deviceStateProvider);
    final state = providerState.valueOrNull ?? widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Nightlight Group
                          _buildGroup(
                            (l10n is ZhStrings) ? '定时关机' : l10n.nightlight,
                            [
                              _buildToggle(
                                Icons.nightlight_round_rounded,
                                (l10n is ZhStrings) ? '定时关机' : l10n.nightlight,
                                Colors.amber,
                                state.nl.on,
                                (v) {
                                  HapticFeedback.selectionClick();
                                  widget.api.setNightlight(on: v);
                                  ref
                                      .read(deviceStateProvider.notifier)
                                      .refresh();
                                },
                              ),
                              if (state.nl.on) ...[
                                _buildSlider(
                                  l10n.durationMinutes,
                                  state.nl.dur.toDouble(),
                                  1,
                                  255,
                                  (v) => widget.api.setNightlight(
                                    duration: v.round(),
                                  ),
                                  suffix: 'm',
                                ),
                                _buildSlider(
                                  l10n.targetBrightness,
                                  state.nl.tbri.toDouble(),
                                  0,
                                  255,
                                  (v) => widget.api.setNightlight(
                                    targetBrightness: v.round(),
                                  ),
                                ),
                                _buildModePicker(state, isDark, l10n),
                              ],
                            ],
                            isDark,
                          ),

                          const SizedBox(height: 24),

                          // 2. Sync Group
                          _buildGroup(l10n.sync, [
                            _buildToggle(
                              Icons.cloud_upload_rounded,
                              l10n.syncSend,
                              Colors.blueAccent,
                              state.udpn.send,
                              (v) {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(deviceStateProvider.notifier)
                                    .optimisticUpdate(
                                      (s) => s.copyWith(
                                        udpn: s.udpn.copyWith(send: v),
                                      ),
                                      () => widget.api.setSync(send: v),
                                    );
                              },
                            ),
                            _buildToggle(
                              Icons.cloud_download_rounded,
                              l10n.syncReceive,
                              Colors.greenAccent,
                              state.udpn.receive,
                              (v) {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(deviceStateProvider.notifier)
                                    .optimisticUpdate(
                                      (s) => s.copyWith(
                                        udpn: s.udpn.copyWith(receive: v),
                                      ),
                                      () => widget.api.setSync(receive: v),
                                    );
                              },
                              isLast: true,
                            ),
                          ], isDark),

                          const SizedBox(height: 24),

                          // 3. Transition Group
                          _buildGroup(l10n.transitionTime, [
                            _buildSlider(
                              l10n.animationSwitch,
                              state.transition.toDouble(),
                              0,
                              255,
                              (v) {
                                ref
                                    .read(deviceStateProvider.notifier)
                                    .optimisticUpdate(
                                      (s) => s.copyWith(transition: v.round()),
                                      () => widget.api.setTransition(v.round()),
                                    );
                              },
                              formatter: (v) =>
                                  '${(v * 0.1).toStringAsFixed(1)}s',
                              isLast: true,
                            ),
                          ], isDark),

                          const SizedBox(height: 24),

                          // 4. Device Info
                          _buildGroup(l10n.deviceInfo, [
                            infoAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (e, _) => Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Failed to load: $e'),
                              ),
                              data: (info) => info == null
                                  ? const SizedBox()
                                  : Column(
                                      children: [
                                        _buildInfo(
                                          l10n.version,
                                          info.ver,
                                          isDark,
                                        ),
                                        _buildInfo(
                                          l10n.ledCount,
                                          '${info.leds.count}',
                                          isDark,
                                        ),
                                        _buildInfo(
                                          l10n.platform,
                                          info.arch,
                                          isDark,
                                        ),
                                        _buildInfo('MAC', info.mac, isDark),
                                        _buildInfo(
                                          l10n.signalStrength,
                                          '${info.wifi?.signal ?? 0}%',
                                          isDark,
                                          isLast: true,
                                        ),
                                      ],
                                    ),
                            ),
                          ], isDark),

                          const SizedBox(height: 32),

                          // Reboot
                          BouncyButton(
                            onTap: () =>
                                _showRebootConfirm(context, l10n, isDark),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.restart_alt_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.reboot,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle(
    IconData icon,
    String label,
    Color color,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          trailing: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: FluxTheme.primary,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChangeEnd, {
    String? suffix,
    String Function(double)? formatter,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: SmartSlider(
            label: label,
            value: value,
            min: min,
            max: max,
            valueSuffix: suffix,
            valueFormatter: formatter,
            activeColor: FluxTheme.primary,
            onChangeEnd: onChangeEnd,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  Widget _buildModePicker(WledState state, bool isDark, AppStrings l10n) {
    final modes = [
      (0, 'Instant'),
      (1, l10n.modeFade),
      (2, l10n.modeColorFade),
      (3, l10n.modeSunrise),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: modes.map((m) {
          final isSelected = state.nl.mode == m.$1;
          return BouncyButton(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.api.setNightlight(mode: m.$1);
              ref.read(deviceStateProvider.notifier).refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? FluxTheme.primary
                    : (isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                m.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfo(
    String label,
    String value,
    bool isDark, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
      ],
    );
  }

  void _showRebootConfirm(BuildContext context, AppStrings l10n, bool isDark) {
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
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restart_alt_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.reboot,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.rebootConfirm,
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
                                  Navigator.pop(context);
                                  widget.api.reboot();
                                  AppToast.success(context, l10n.rebooting);
                                },
                                child: Text(l10n.reboot),
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
