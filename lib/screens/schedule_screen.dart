import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import '../widgets/smart_slider.dart';

/// 定时任务页面
/// 基于 WLED Nightlight API 实现
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(deviceStateProvider);
    final api = ref.watch(wledApiProvider);
    final l10n = ref.watch(l10nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // iOS Style Header
              Padding(
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
                        child: const Icon(Icons.chevron_left_rounded, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      l10n.schedule,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: stateAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (state) {
                    final nl = state.nl;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Activate Toggle
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: nl.on
                                      ? Colors.amber.withValues(alpha: 0.1)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              )),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.nightlight_round_rounded,
                                  color: nl.on ? Colors.amber : Colors.grey,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.timerActive,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      nl.on
                                          ? l10n.timerStatusScheduled
                                          : l10n.timerStatusNotActive,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: nl.on,
                                activeTrackColor: FluxTheme.primary,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  api?.setNightlight(on: val);
                                  ref
                                      .read(deviceStateProvider.notifier)
                                      .refresh();
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Parameters if active
                        if (nl.on) ...[
                          _buildSectionTitle(l10n.settings, isDark),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                SmartSlider(
                                  label: l10n.durationMinutes,
                                  value: nl.dur.toDouble(),
                                  min: 1,
                                  max: 255,
                                  valueSuffix: 'm',
                                  activeColor: FluxTheme.primary,
                                  onChangeEnd: (v) =>
                                      api?.setNightlight(duration: v.round()),
                                ),
                                const SizedBox(height: 24),
                                SmartSlider(
                                  label: l10n.targetBrightness,
                                  value: nl.tbri.toDouble(),
                                  min: 0,
                                  max: 255,
                                  activeColor: FluxTheme.primary,
                                  onChangeEnd: (v) => api?.setNightlight(
                                    targetBrightness: v.round(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          _buildSectionTitle('运行模式', isDark),
                          const SizedBox(height: 12),
                          _buildModeGrid(nl.mode, api, isDark, l10n),
                        ],

                        const SizedBox(height: 40),
                        _buildTipCard(isDark, l10n),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModeGrid(
    int currentMode,
    WledApiService? api,
    bool isDark,
    AppStrings l10n,
  ) {
    final modes = [
      (0, '即时', Icons.bolt_rounded, l10n.timerModeInstantDesc),
      (1, l10n.modeFade, Icons.blur_on_rounded, l10n.timerModeFadeDesc),
      (
        2,
        l10n.modeColorFade,
        Icons.color_lens_rounded,
        l10n.timerModeColorFadeDesc,
      ),
      (3, l10n.modeSunrise, Icons.wb_sunny_rounded, l10n.timerModeSunriseDesc),
    ];

    return Column(
      children: modes.map((m) {
        final isSelected = currentMode == m.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BouncyButton(
            onTap: () {
              HapticFeedback.selectionClick();
              api?.setNightlight(mode: m.$1);
              ref.read(deviceStateProvider.notifier).refresh();
            },
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FluxTheme.primary.withValues(alpha: 0.15)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      m.$3,
                      color: isSelected ? FluxTheme.primary : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isSelected ? FluxTheme.primary : null,
                          ),
                        ),
                        Text(
                          m.$4,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: FluxTheme.primary,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTipCard(bool isDark, AppStrings l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluxTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FluxTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: FluxTheme.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.scheduleTipTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: FluxTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.scheduleTipContent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: FluxTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
