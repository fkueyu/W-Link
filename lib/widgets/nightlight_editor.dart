import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import '../models/models.dart';
import 'bouncy_button.dart';
import 'glass_card.dart';
import 'smart_slider.dart';

class NightlightEditor extends StatelessWidget {
  const NightlightEditor({
    super.key,
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final WledNightlight value;
  final AppStrings strings;
  final ValueChanged<WledNightlight> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: value.on
                      ? Colors.amber.withValues(alpha: 0.1)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nightlight_round_rounded,
                  color: value.on ? Colors.amber : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.nightlight,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      value.on
                          ? strings.timerStatusScheduled
                          : strings.timerStatusNotActive,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Semantics(
                label: strings.nightlight,
                child: Switch.adaptive(
                  value: value.on,
                  activeTrackColor: FluxTheme.primary,
                  onChanged: (enabled) {
                    HapticFeedback.selectionClick();
                    onChanged(value.copyWith(on: enabled));
                  },
                ),
              ),
            ],
          ),
        ),
        if (value.on) ...[
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SmartSlider(
                  label: strings.durationMinutes,
                  value: value.dur.toDouble(),
                  min: 1,
                  max: 255,
                  valueSuffix: 'm',
                  activeColor: FluxTheme.primary,
                  onChangeEnd: (duration) =>
                      onChanged(value.copyWith(dur: duration.round())),
                ),
                const SizedBox(height: 24),
                SmartSlider(
                  label: strings.targetBrightness,
                  value: value.tbri.toDouble(),
                  min: 0,
                  max: 255,
                  activeColor: FluxTheme.primary,
                  onChangeEnd: (brightness) =>
                      onChanged(value.copyWith(tbri: brightness.round())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              strings.timerMode.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ..._modes(strings).map(
            (mode) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModeCard(
                mode: mode,
                selected: value.mode == mode.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(value.copyWith(mode: mode.id));
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<_NightlightMode> _modes(AppStrings strings) => [
    _NightlightMode(
      0,
      strings.timerModeInstant,
      strings.timerModeInstantDesc,
      Icons.bolt_rounded,
    ),
    _NightlightMode(
      1,
      strings.modeFade,
      strings.timerModeFadeDesc,
      Icons.blur_on_rounded,
    ),
    _NightlightMode(
      2,
      strings.modeColorFade,
      strings.timerModeColorFadeDesc,
      Icons.color_lens_rounded,
    ),
    _NightlightMode(
      3,
      strings.modeSunrise,
      strings.timerModeSunriseDesc,
      Icons.wb_sunny_rounded,
    ),
  ];
}

class _NightlightMode {
  const _NightlightMode(this.id, this.name, this.description, this.icon);

  final int id;
  final String name;
  final String description;
  final IconData icon;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _NightlightMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BouncyButton(
      onTap: onTap,
      semanticLabel: mode.name,
      selected: selected,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? FluxTheme.primary.withValues(alpha: 0.15)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                mode.icon,
                color: selected ? FluxTheme.primary : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: selected ? FluxTheme.primary : null,
                    ),
                  ),
                  Text(
                    mode.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: FluxTheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class NightlightSummaryCard extends StatelessWidget {
  const NightlightSummaryCard({
    super.key,
    required this.value,
    required this.strings,
    required this.onTap,
  });

  final WledNightlight value;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = value.on ? Colors.amber : Colors.grey;
    return BouncyButton(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.nightlight_round_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.nightlight,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.on ? strings.timerActive : strings.timerInactive,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
