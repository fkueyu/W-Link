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
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                data: (state) =>
                    _buildMainContent(context, state, api, l10n, isDark),
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
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.2),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
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
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1.2,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.7),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.8),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.device.toUpperCase(),
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Hero(
                            tag: 'name_${widget.device.id}',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                widget.device.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPowerButton(isOn, color, api, isDark),
                  ],
                ),
                const SizedBox(height: 32),
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
    ).animate().fadeIn().slideY(begin: 0.1, duration: 400.ms);
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOn
              ? color
              : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.05)),
          shape: BoxShape.circle,
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Icon(
          Icons.power_settings_new_rounded,
          color: isOn
              ? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
              : (isDark ? Colors.white54 : Colors.black54),
          size: 32,
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.light_mode_rounded,
                  size: 16,
                  color: isOn ? color : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.brightness.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Text(
              '${(value / 255 * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isOn ? color : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SmartSlider(
          value: value,
          min: 0,
          max: 255,
          activeColor: isOn ? color : Colors.grey,
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
      ],
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
      childAspectRatio: 1.8,
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
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subWidget != null)
                    subWidget
                  else if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11,
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
