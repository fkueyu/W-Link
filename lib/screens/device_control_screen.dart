import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/core.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import '../widgets/smart_slider.dart';
import '../widgets/device_settings_sheet.dart';
import '../core/wled_metadata_helper.dart';

import 'effects_list_screen.dart';
import 'palettes_list_screen.dart';
import 'presets_list_screen.dart';
import 'segments_list_screen.dart';
import 'schedule_screen.dart';

/// 设备控制中心 - 核心交互页面
class DeviceControlScreen extends ConsumerStatefulWidget {
  final WledDevice device;

  const DeviceControlScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceControlScreen> createState() =>
      _DeviceControlScreenState();
}

class _DeviceControlScreenState extends ConsumerState<DeviceControlScreen> {
  double? _localBrightness;

  @override
  void initState() {
    super.initState();
    // 确保进入页面时，当前全局设备 ID 已正确设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentDeviceIdProvider.notifier).state = widget.device.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 监听实时设备对象以获取最新名称
    final currentDevice = ref.watch(currentDeviceProvider) ?? widget.device;

    return Scaffold(
      body: AnimatedBackground(
        child: Stack(
          children: [
            // Safe Area Content
            SafeArea(
              child: stateAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: FluxTheme.primary),
                ),
                error: (e, _) => _buildErrorState(e, l10n),
                data: (state) => _buildMainContent(
                  context,
                  currentDevice,
                  state,
                  api,
                  l10n,
                  isDark,
                ),
              ),
            ),

            // Top Glassy Navigation Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 64 + MediaQuery.of(context).padding.top,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF000000).withValues(
                              alpha: 0.4,
                            ) // Deeper glass
                          : Colors.white.withValues(alpha: 0.2),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BouncyButton(
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color: FluxTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.devices,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: FluxTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        BouncyButton(
                          onTap: () => _showSettingsSheet(
                            context,
                            stateAsync.valueOrNull,
                            api,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: FluxTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: FluxTheme.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, AppStrings l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.connectionFailed,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Hero(
            tag: 'ip_${widget.device.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                widget.device.ip,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          BouncyButton(
            onTap: () => ref.read(deviceStateProvider.notifier).refresh(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: FluxTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.retry,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildMainContent(
    BuildContext context,
    WledDevice currentDevice,
    WledState state,
    WledApiService? api,
    AppStrings l10n,
    bool isDark,
  ) {
    final primaryColor = state.primaryColor != null
        ? ColorExtension.fromRgbList(state.primaryColor!)
        : FluxTheme.primary;
    final isOn = state.on;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ), // Space for glass bar
        // 1. Unified Control Hero
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildControlHero(
              context,
              currentDevice,
              state,
              api,
              primaryColor,
              isOn,
              isDark,
              l10n,
            ),
          ),
        ),

        // 2. Quick Actions Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              l10n.settings.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black38,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildQuickActionsGrid(state, api, l10n, isDark),
        ),

        // 3. Effect Parameters Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            child: _buildContextualControls(state, api, l10n, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildControlHero(
    BuildContext context,
    WledDevice device,
    WledState state,
    WledApiService? api,
    Color color,
    bool isOn,
    bool isDark,
    AppStrings l10n,
  ) {
    final brightness = _localBrightness ?? state.bri.toDouble();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (isOn)
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
              blurRadius: 40,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: FluxTheme.glassDecoration(
              context,
              radius: 40,
              hasShadow: true,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: BouncyButton(
                        onTap: () =>
                            _showRenameDialog(context, device, l10n, isDark),
                        child: Hero(
                          tag: 'name_${device.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      letterSpacing: -0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildPowerButton(isOn, color, api, isDark),
                  ],
                ),
                const SizedBox(height: 24),
                _buildBrightnessSector(
                  brightness,
                  isOn,
                  color,
                  api,
                  isDark,
                  l10n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WledDevice device,
    AppStrings l10n,
    bool isDark,
  ) {
    final controller = TextEditingController(text: device.name);
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rename,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (l10n is ZhStrings)
                      ? '为您的设备设置一个易于识别的备注'
                      : 'Set a recognizable name for your device',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: l10n.device,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          l10n.cancel,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BouncyButton(
                        onTap: () {
                          final newName = controller.text.trim();
                          String finalName;

                          if (newName.isEmpty) {
                            // 1. 优先尝试从实时状态中获取设备当前的真实名字
                            final state = ref
                                .read(deviceStateProvider)
                                .valueOrNull;
                            if (state != null && state.info.name.isNotEmpty) {
                              finalName = state.info.name;
                            } else {
                              // 2. 备选方案：使用添加时的初始名字
                              finalName = device.originalName;
                            }
                          } else {
                            finalName = newName;
                          }

                          ref
                              .read(deviceListProvider.notifier)
                              .updateDeviceName(device.id, finalName);
                          Navigator.pop(ctx);
                          AppToast.success(
                            context,
                            (l10n is ZhStrings) ? '名称已更新' : 'Name updated',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: FluxTheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              l10n.save,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
      ).animate().scale(begin: const Offset(0.9, 0.9)).fadeIn(),
    );
  }

  Widget _buildPowerButton(
    bool isOn,
    Color color,
    WledApiService? api,
    bool isDark,
  ) {
    return BouncyButton(
      onTap: () {
        HapticFeedback.heavyImpact();
        ref
            .read(deviceStateProvider.notifier)
            .optimisticUpdate(
              (s) => s.copyWith(on: !isOn),
              () => api!.setOn(!isOn),
            );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOn
              ? (isDark
                    ? Color.lerp(
                        color,
                        Colors.white,
                        0.15,
                      )!.withValues(alpha: 0.8)
                    : color)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
          shape: BoxShape.circle,
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.3 : 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            if (isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Icon(
          Icons.power_settings_new_rounded,
          color: isOn
              ? Colors.white
              : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBrightnessSector(
    double value,
    bool isOn,
    Color color,
    WledApiService? api,
    bool isDark,
    AppStrings l10n,
  ) {
    final percent = (value / 255 * 100).round();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 进度填充层
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (value / 255).clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isOn
                      ? color.withValues(alpha: isDark ? 0.4 : 0.3)
                      : (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: isOn
                        ? [
                            color.withValues(alpha: isDark ? 0.3 : 0.2),
                            color.withValues(alpha: isDark ? 0.8 : 0.7),
                          ]
                        : [
                            isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                            isDark ? Colors.white24 : Colors.black26,
                          ],
                  ),
                ),
              ),
            ),
          ),
          // 交互层 (Slider)
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 48,
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackShape: const _FullWidthTrackShape(),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              onChanged: (v) => setState(() => _localBrightness = v),
              onChangeEnd: (v) {
                setState(() => _localBrightness = null);
                final bri = v.round();
                ref
                    .read(deviceStateProvider.notifier)
                    .optimisticUpdate(
                      (s) => s.copyWith(on: bri > 0, bri: bri),
                      () => api!.setState({'on': bri > 0, 'bri': bri}),
                    );
              },
            ),
          ),
          // 内容层 (Icon + Percentage)
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.black38,
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(
    WledState state,
    WledApiService? api,
    AppStrings l10n,
    bool isDark,
  ) {
    final effectsAsync = ref.watch(effectsProvider);
    final palettesAsync = ref.watch(palettesProvider);
    final presetsAsync = ref.watch(presetsProvider);

    String fxLabel = '...';
    if (effectsAsync.hasValue) {
      final fx = state.seg.isNotEmpty ? state.seg.first.fx : 0;
      if (fx < effectsAsync.value!.length) {
        fxLabel = l10n is ZhStrings
            ? getEffectChineseName(effectsAsync.value![fx])
            : effectsAsync.value![fx];
      }
    }

    String palLabel = '...';
    if (palettesAsync.hasValue) {
      final pal = state.seg.isNotEmpty ? state.seg.first.pal : 0;
      if (pal < palettesAsync.value!.length) {
        palLabel = l10n is ZhStrings
            ? getPaletteChineseName(palettesAsync.value![pal])
            : palettesAsync.value![pal];
      }
    }

    return SliverGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children:
          [
                _buildActionTile(
                  l10n.effect,
                  fxLabel,
                  Icons.auto_awesome_rounded,
                  Colors.purpleAccent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EffectsListScreen(),
                    ),
                  ),
                  isDark,
                ),
                _buildActionTile(
                  l10n.palette,
                  palLabel,
                  Icons.palette_rounded,
                  Colors.orangeAccent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PalettesListScreen(),
                    ),
                  ),
                  isDark,
                ),
                _buildActionTile(
                  l10n.presets,
                  state.ps > 0
                      ? (presetsAsync.valueOrNull?.firstWhere(
                              (p) {
                                if (p.id == state.ps) {
                                  return true;
                                }
                                return false;
                              },
                              orElse: () => WledPreset(
                                id: state.ps,
                                name: 'Preset ${state.ps}',
                              ),
                            ).name ??
                            'Preset ${state.ps}')
                      : l10n.notSelected,
                  Icons.bookmark_rounded,
                  Colors.tealAccent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PresetsListScreen(),
                    ),
                  ),
                  isDark,
                ),
                _buildActionTile(
                  l10n.segments,
                  '${state.seg.length} ${l10n.segment}',
                  Icons.view_column_rounded,
                  Colors.indigoAccent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SegmentsListScreen(),
                    ),
                  ),
                  isDark,
                ),
                _buildActionTile(
                  l10n.color,
                  null,
                  Icons.color_lens_rounded,
                  FluxTheme.primary,
                  () => _showColorPicker(
                    context,
                    state.primaryColor != null
                        ? ColorExtension.fromRgbList(state.primaryColor!)
                        : Colors.white,
                    api,
                  ),
                  isDark,
                  subWidget: Row(
                    children: [
                      Container(
                        width: 40, // 固定宽度，使其与上方标题长度相近
                        height: 5,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: state.primaryColor != null
                              ? ColorExtension.fromRgbList(
                                  state.primaryColor!,
                                ).withValues(alpha: 0.7) // 降低不透明度等效减少感知饱和度
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            if (state.primaryColor != null)
                              BoxShadow(
                                color: ColorExtension.fromRgbList(
                                  state.primaryColor!,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                spreadRadius: 0,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionTile(
                  l10n.schedule,
                  state.nl.on ? l10n.timerActive : l10n.timerInactive,
                  Icons.timer_rounded,
                  state.nl.on ? Colors.greenAccent : Colors.grey,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                  ),
                  isDark,
                ),
              ]
              .animate(interval: 50.ms)
              .fadeIn()
              .scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildActionTile(
    String title,
    String? sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark, {
    Widget? subWidget,
  }) {
    return BouncyButton(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subWidget != null)
                    subWidget
                  else if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualControls(
    WledState state,
    WledApiService? api,
    AppStrings l10n,
    bool isDark,
  ) {
    final metadataAsync = ref.watch(effectMetadataProvider);
    final metadataList = metadataAsync.valueOrNull ?? [];
    final currentFx = state.seg.isNotEmpty ? state.seg.first.fx : 0;

    String metadata = (currentFx >= 0 && currentFx < metadataList.length)
        ? metadataList[currentFx]
        : '';
    List<String> labels = WledMetadataHelper.parseParameters(
      metadata,
      localizedDefaults: [
        'Speed',
        'Intensity',
        'Custom 1',
        'Custom 2',
        'Custom 3',
      ],
    );

    // Map segments values to sliders
    final configs = [
      (state.seg.first.sx.toDouble(), (v) => api?.setEffectSpeed(v.round())),
      (
        state.seg.first.ix.toDouble(),
        (v) => api?.setEffectIntensity(v.round()),
      ),
      (
        state.seg.first.c1.toDouble(),
        (v) => api?.setEffectCustom(1, v.round()),
      ),
      (
        state.seg.first.c2.toDouble(),
        (v) => api?.setEffectCustom(2, v.round()),
      ),
      (
        state.seg.first.c3.toDouble(),
        (v) => api?.setEffectCustom(3, v.round()),
      ),
    ];

    bool hasVisible = labels.any((l) => l.isNotEmpty);
    if (!hasVisible) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.effectParameters.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: List.generate(labels.length, (i) {
              if (labels[i].isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(
                  top: i > 0 && labels.getRange(0, i).any((l) => l.isNotEmpty)
                      ? 24
                      : 0,
                ),
                child: SmartSlider(
                  label: l10n is ZhStrings
                      ? getParameterTranslation(labels[i])
                      : labels[i],
                  value: configs[i].$1,
                  min: 0,
                  max: 255,
                  activeColor: FluxTheme.primary,
                  onChangeEnd: (v) {
                    HapticFeedback.selectionClick();
                    configs[i].$2(v);
                    ref.read(deviceStateProvider.notifier).refresh();
                  },
                ),
              );
            }),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  void _showColorPicker(
    BuildContext context,
    Color current,
    WledApiService? api,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorPickerSheet(
        initialColor: current,
        onColorChanged: (color) {
          api?.setColor([
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
          ]);
          ref.read(deviceStateProvider.notifier).refresh();
        },
      ),
    );
  }

  void _showSettingsSheet(
    BuildContext context,
    WledState? state,
    WledApiService? api,
  ) {
    if (state == null || api == null) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceSettingsSheet(api: api, state: state),
    );
  }
}

class _FullWidthTrackShape extends SliderTrackShape {
  const _FullWidthTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      parentBox.size.width,
      parentBox.size.height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue;
    final double visualWidth =
        trackRect.width * (thumbCenter.dx / trackRect.width);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          trackRect.left,
          trackRect.top,
          visualWidth.clamp(0.0, trackRect.width),
          trackRect.height,
        ),
        Radius.circular(trackRect.height / 2),
      ),
      activePaint,
    );
  }
}
